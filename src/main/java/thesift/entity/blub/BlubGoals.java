package thesift.entity.blub;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.behavior.BehaviorUtils;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.ai.util.DefaultRandomPos;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.phys.Vec3;

import thesift.block.TideFloraBlock;
import thesift.block.entity.TideVentBlockEntity;
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;
import thesift.registry.ModSounds;
import thesift.registry.ModTags;
import thesift.world.Tide;
import thesift.world.TideBasin;

/** The Blub's own goals (mob_blub.md, Behavior), in the order Blub registers them. */
final class BlubGoals {
	private BlubGoals() {
	}

	private static boolean free(Blub blub) {
		return !blub.isOrderedToSit() && !blub.isPassenger();
	}

	private static void walkTo(Blub blub, BlockPos pos, double speed) {
		blub.getNavigation().moveTo(pos.getX() + 0.5, pos.getY(), pos.getZ() + 0.5, speed);
	}

	/** True if a blub can stand at {@code feet}: a sturdy floor and two open cells (ichor counts as open). */
	static boolean standable(Level level, BlockPos feet) {
		return level.getBlockState(feet.below()).isFaceSturdy(level, feet.below(), Direction.UP)
				&& level.getBlockState(feet).getCollisionShape(level, feet).isEmpty()
				&& level.getBlockState(feet.above()).getCollisionShape(level, feet.above()).isEmpty();
	}

	// ------------------------------------------------------------------ SHELTER

	/**
	 * Endure (or night outside the Sift): untamed blubs walk to a roof within 12 blocks (songwood
	 * leaves first, then any leaves, then anything overhead) and curl until the Tide changes; with no
	 * roof in reach they curl where they stand. A befriended blub curls only when its owner has stood
	 * still for 5 s, under a roof within 6 blocks of the owner or at the owner's feet.
	 */
	static final class Shelter extends Goal {
		static final int OWNER_STILL_TICKS = 100;
		private final Blub blub;
		private int delay;
		private @Nullable BlockPos target;
		private int walkTicks;

		Shelter(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP));
		}

		private boolean wanted() {
			if (!free(this.blub) || this.blub.isRestless() || !this.blub.isShelterTime()) {
				return false;
			}
			if (this.blub.isTame()) {
				LivingEntity owner = this.blub.getOwner();
				return owner != null && owner.level() == this.blub.level() && this.blub.ownerStillTicks() >= OWNER_STILL_TICKS;
			}
			return true;
		}

		@Override
		public boolean canUse() {
			if (!this.wanted()) {
				this.delay = 0;
				return false;
			}
			// Every blub reacts to the same Tide change: each waits a random 0–5 s before searching.
			if (this.delay == 0) {
				this.delay = reducedTickDelay(1 + this.blub.getRandom().nextInt(100)); // canUse runs every other tick
			}
			return --this.delay <= 0;
		}

		@Override
		public boolean canContinueToUse() {
			return this.wanted();
		}

		@Override
		public void start() {
			LivingEntity owner = this.blub.isTame() ? this.blub.getOwner() : null;
			BlockPos centre = owner != null ? owner.blockPosition() : this.blub.blockPosition();
			this.target = findRoof(this.blub, centre, owner != null ? 6 : 12);
			if (this.target == null && owner != null) {
				this.target = owner.blockPosition();
			}
			this.walkTicks = 0;
			if (this.target != null) {
				walkTo(this.blub, this.target, 1.1);
			} else {
				this.blub.setCurled(true);
			}
		}

		@Override
		public void tick() {
			if (this.blub.isCurled()) {
				this.blub.getNavigation().stop();
				return;
			}
			this.walkTicks++;
			boolean there = this.target == null || this.blub.blockPosition().distManhattan(this.target) <= 1;
			if (there || this.blub.getNavigation().isDone() || this.walkTicks > reducedTickDelay(400)) {
				this.blub.getNavigation().stop();
				this.blub.setCurled(true); // under the roof, at the owner's feet, or as close as it got
			}
		}

		@Override
		public void stop() {
			this.blub.setCurled(false);
			this.target = null;
			this.delay = 0;
		}

		/**
		 * A roof near {@code centre}: a standable spot whose column has something overhead. Reads
		 * heightmap columns (a roof is a MOTION_BLOCKING height above the spot), never scans blocks.
		 */
		static @Nullable BlockPos findRoof(Blub blub, BlockPos centre, int radius) {
			Level level = blub.level();
			BlockPos best = null;
			int bestScore = Integer.MAX_VALUE;
			for (int i = 0; i < 40; i++) {
				int x = centre.getX() + (i == 0 ? 0 : blub.getRandom().nextInt(2 * radius + 1) - radius);
				int z = centre.getZ() + (i == 0 ? 0 : blub.getRandom().nextInt(2 * radius + 1) - radius);
				if (!level.isLoaded(new BlockPos(x, centre.getY(), z))) {
					continue;
				}
				int top = level.getHeight(Heightmap.Types.MOTION_BLOCKING, x, z);
				for (int dy = -2; dy <= 2; dy++) {
					BlockPos feet = new BlockPos(x, centre.getY() + dy, z);
					if (top <= feet.getY() + 2 || !standable(level, feet)) {
						continue;
					}
					BlockState roof = level.getBlockState(new BlockPos(x, top - 1, z));
					int kind = roof.is(ModBlocks.SONGWOOD_LEAVES) ? 0 : roof.is(BlockTags.LEAVES) ? 1 : 2;
					int score = kind * 1000 + feet.distManhattan(blub.blockPosition());
					if (score < bestScore) {
						bestScore = score;
						best = feet;
					}
					break;
				}
			}
			return best;
		}
	}

	// ------------------------------------------------------------------ WATERLINE

	/**
	 * Flow: walk to the nearest basin's current waterline and potter along it as it moves, dipping into
	 * the edge now and then (the top layer is one block deep over each ring).
	 */
	static final class Waterline extends Goal {
		private final Blub blub;
		private @Nullable TideVentBlockEntity vent;
		private int nextMove;

		Waterline(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE));
		}

		private boolean flow() {
			Tide tide = this.blub.tide();
			return tide != null && tide.isFlow() && free(this.blub);
		}

		@Override
		public boolean canUse() {
			if (!this.flow() || this.blub.getRandom().nextInt(40) != 0) {
				return false;
			}
			this.vent = findVent(this.blub, 16);
			return this.vent != null;
		}

		@Override
		public boolean canContinueToUse() {
			return this.flow() && this.vent != null && !this.vent.isRemoved()
					&& this.blub.blockPosition().closerThan(this.vent.getBlockPos(), 20);
		}

		@Override
		public void start() {
			this.nextMove = 0;
		}

		@Override
		public void tick() {
			if (--this.nextMove > 0) {
				return;
			}
			this.nextMove = reducedTickDelay(60 + this.blub.getRandom().nextInt(60));
			BlockPos cell = waterlineCell(this.vent, this.blub.getRandom().nextInt(4) == 0);
			if (cell != null) {
				walkTo(this.blub, cell, 1.0);
			}
		}

		@Override
		public void stop() {
			this.vent = null;
		}

		/** Tide vents in the blub's own and neighbouring chunks (already loaded), never a block scan. */
		static @Nullable TideVentBlockEntity findVent(Blub blub, int range) {
			Level level = blub.level();
			int cx = blub.blockPosition().getX() >> 4;
			int cz = blub.blockPosition().getZ() >> 4;
			TideVentBlockEntity best = null;
			double bestDist = range * range;
			for (int dx = -1; dx <= 1; dx++) {
				for (int dz = -1; dz <= 1; dz++) {
					LevelChunk chunk = level.getChunkSource().getChunkNow(cx + dx, cz + dz);
					if (chunk == null) {
						continue;
					}
					for (BlockEntity be : chunk.getBlockEntities().values()) {
						if (be instanceof TideVentBlockEntity vent && vent.basin().inner() > 0) {
							double d = vent.getBlockPos().distToCenterSqr(blub.position());
							if (d < bestDist) {
								bestDist = d;
								best = vent;
							}
						}
					}
				}
			}
			return best;
		}

		/** A cell on the dry ring at the waterline, or (dip) one in the one-block-deep top layer. */
		static @Nullable BlockPos waterlineCell(TideVentBlockEntity vent, boolean dip) {
			TideBasin basin = vent.basin();
			int layers = vent.layers() >= 0 ? vent.layers() : 0;
			int ring = dip && layers > 0 ? layers - 1 : Math.min(layers, TideBasin.RINGS);
			List<BlockPos> cells = new ArrayList<>();
			for (int dx = -basin.half(); dx <= basin.half(); dx++) {
				for (int dz = -basin.half(); dz <= basin.half(); dz++) {
					if (basin.inFootprint(dx, dz) && basin.ring(dx, dz) == ring) {
						cells.add(basin.vent().offset(dx, basin.floorY(dx, dz) + 1 - basin.vent().getY(), dz));
					}
				}
			}
			return cells.isEmpty() ? null : cells.get(vent.getLevel() != null ? vent.getLevel().getRandom().nextInt(cells.size()) : 0);
		}
	}

	// ------------------------------------------------------------------ STACK

	/**
	 * Listening blubs within 3 blocks climb onto one another, up to {@link #MAX_HEIGHT} tall, and sway.
	 * The goal holds MOVE for the bottom blub, which stands still. Toppling is ticked by the bottom
	 * blub ({@link #tickTower}).
	 */
	static final class Stack extends Goal {
		static final int MAX_HEIGHT = 5;
		private final Blub blub;
		private @Nullable Blub tower;
		private int nextSearch;
		private int climbTicks;

		Stack(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP));
		}

		static boolean mayStack(Blub blub) {
			Tide tide = blub.tide();
			return blub.isListening() && !blub.isOrderedToSit() && (tide == null || tide == Tide.THRIVE)
					&& !blub.ownerWalkingAway() && !blub.isInWater();
		}

		@Override
		public boolean canUse() {
			if (this.blub.isVehicle() && !this.blub.isPassenger()) {
				return true; // the bottom of a tower holds still
			}
			if (this.blub.isPassenger() || !mayStack(this.blub) || --this.nextSearch > 0) {
				return false;
			}
			this.nextSearch = 20 + this.blub.getRandom().nextInt(20);
			this.tower = findTower(this.blub);
			return this.tower != null;
		}

		@Override
		public boolean canContinueToUse() {
			if (this.blub.isVehicle() && !this.blub.isPassenger()) {
				return true;
			}
			return this.tower != null && this.tower.isAlive() && !this.blub.isPassenger() && mayStack(this.blub)
					&& this.climbTicks < 200 && canClimb(this.blub, this.tower);
		}

		@Override
		public void start() {
			this.climbTicks = 0;
		}

		@Override
		public boolean requiresUpdateEveryTick() {
			return true;
		}

		@Override
		public void tick() {
			if (this.blub.isVehicle()) {
				this.blub.getNavigation().stop(); // stand and sway
				return;
			}
			// tick() also runs on the off-ticks without canContinueToUse(): a blub that just climbed
			// must not look for the top again (it is the top now, and would mount itself).
			if (this.tower == null || this.blub.isPassenger()) {
				return;
			}
			this.climbTicks++;
			Entity top = topOf(this.tower);
			double dx = top.getX() - this.blub.getX();
			double dz = top.getZ() - this.blub.getZ();
			if (dx * dx + dz * dz < 1.2 * 1.2 && this.blub.onGround()) {
				this.blub.getNavigation().stop();
				if (top != this.blub && canClimb(this.blub, this.tower) && this.blub.startRiding(top)) {
					this.blub.playSound(ModSounds.BLUB_HOP, 0.6F, this.blub.getVoicePitch());
				}
			} else if (this.climbTicks % 10 == 1) {
				this.blub.getNavigation().moveTo(top, 1.0);
			}
		}

		@Override
		public void stop() {
			this.tower = null;
		}

		static Entity topOf(Entity root) {
			Entity e = root;
			while (!e.getPassengers().isEmpty()) {
				e = e.getPassengers().get(0);
			}
			return e;
		}

		static int height(Entity root) {
			int h = 1;
			Entity e = root;
			while (!e.getPassengers().isEmpty()) {
				e = e.getPassengers().get(0);
				h++;
			}
			return h;
		}

		/** The nearest tower (or lone blub) within 3 blocks that this blub can climb onto. */
		static @Nullable Blub findTower(Blub blub) {
			Blub best = null;
			double bestDist = Double.MAX_VALUE;
			for (Blub other : blub.level().getEntitiesOfClass(Blub.class, blub.getBoundingBox().inflate(3.0), b -> b != blub && !b.isPassenger())) {
				if (other.isListening() && !other.isOrderedToSit() && canClimb(blub, other)) {
					double d = other.distanceToSqr(blub);
					if (d < bestDist) {
						bestDist = d;
						best = other;
					}
				}
			}
			return best;
		}

		/** Room on top: the tower is under five and the space above its top is clear. */
		static boolean canClimb(Blub blub, Blub root) {
			if (root.getRootVehicle() != root || !root.onGround() || height(root) >= MAX_HEIGHT) {
				return false;
			}
			Entity top = topOf(root);
			Vec3 seat = top.position().add(0, top.getBbHeight(), 0);
			return blub.level().noCollision(blub, blub.getType().getDimensions().makeBoundingBox(seat));
		}

		/**
		 * Ticked for every blub; acts only for the bottom of a tower. It topples 15–40 s after the
		 * music stops, or at once if the bottom moves more than 0.5 block, the Tide changes, or a
		 * befriended rider's owner walks away (hurt: {@link Blub#hurtServer}).
		 */
		static void tickTower(Blub blub, ServerLevel level, long now) {
			if (!blub.isVehicle() || blub.isPassenger()) {
				blub.towerOrigin = null;
				return;
			}
			if (blub.towerOrigin == null) {
				blub.towerOrigin = blub.position();
				blub.towerTide = blub.tide();
				blub.toppleAt = -1;
			}
			boolean listening = false;
			boolean ownerGone = false;
			for (Entity e : tower(blub)) {
				if (e instanceof Blub b) {
					listening |= b.isListening();
					ownerGone |= b != blub && b.ownerWalkingAway();
				}
			}
			if (listening) {
				blub.toppleAt = -1;
			} else if (blub.toppleAt < 0) {
				blub.toppleAt = now + 300 + blub.getRandom().nextInt(501);
			}
			if (blub.toppleAt > 0 && blub.toppleAt - now == 60) {
				for (Entity e : tower(blub)) {
					if (e instanceof Blub b) {
						b.teeterSoon();
					}
				}
			}
			Vec3 moved = blub.position().subtract(blub.towerOrigin);
			boolean fall = (blub.toppleAt > 0 && now >= blub.toppleAt)
					|| moved.x * moved.x + moved.z * moved.z > 0.25
					|| blub.tide() != blub.towerTide
					|| ownerGone;
			if (fall) {
				topple(blub, level);
			}
		}

		static List<Entity> tower(Entity root) {
			List<Entity> out = new ArrayList<>();
			out.add(root);
			root.getIndirectPassengers().forEach(out::add);
			return out;
		}

		/** Everyone off: a bouncy tumble (falls are soft, safe fall distance 4). */
		static void topple(Entity root, ServerLevel level) {
			if (!(root instanceof Blub bottom) || !root.isVehicle()) {
				return;
			}
			List<Entity> all = tower(root);
			for (int i = all.size() - 1; i > 0; i--) {
				all.get(i).stopRiding();
			}
			for (Entity e : all) {
				if (e instanceof Blub b) {
					b.toppled();
					if (b != bottom) {
						b.setDeltaMovement((b.getRandom().nextDouble() - 0.5) * 0.5, 0.25, (b.getRandom().nextDouble() - 0.5) * 0.5);
					}
				}
			}
			level.playSound(null, bottom.getX(), bottom.getY(), bottom.getZ(), ModSounds.BLUB_TOPPLE, SoundSource.NEUTRAL, 1.0F, bottom.getVoicePitch());
			bottom.towerOrigin = null;
			bottom.toppleAt = -1;
		}
	}

	// ------------------------------------------------------------------ LISTEN + DANCE

	/** Face the music; untamed blubs drift toward it, and everyone hops to the beat once close. */
	static final class Listen extends Goal {
		private final Blub blub;
		private int beat;

		Listen(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK, Goal.Flag.JUMP));
		}

		@Override
		public boolean canUse() {
			return this.blub.musicSource() != null && free(this.blub);
		}

		@Override
		public boolean requiresUpdateEveryTick() {
			return true;
		}

		@Override
		public void start() {
			this.beat = this.blub.getRandom().nextInt(12);
		}

		@Override
		public void tick() {
			Vec3 source = this.blub.musicSource();
			if (source == null) {
				return;
			}
			this.blub.getLookControl().setLookAt(source.x, source.y, source.z);
			if (!this.blub.isTame() && this.blub.position().distanceToSqr(source) > 9.0) {
				if (this.blub.getNavigation().isDone() || ++this.beat % 20 == 0) {
					this.blub.getNavigation().moveTo(source.x, source.y, source.z, 0.9);
				}
				return;
			}
			this.blub.getNavigation().stop();
			if (this.blub.onGround() && ++this.beat % 12 == 0) {
				this.blub.getJumpControl().jump();
			}
		}

		@Override
		public void stop() {
			this.blub.getNavigation().stop();
		}
	}

	// ------------------------------------------------------------------ BATHE

	/**
	 * Thrive, now and then: sit in ichor one block deep over a solid floor for 10–30 s. Bounded like
	 * vanilla's MoveToBlockGoal: at most one search every 2–5 s, 24 random cells within 8.
	 */
	static final class Bathe extends Goal {
		private final Blub blub;
		private @Nullable BlockPos spot;
		private int cooldown;
		private int soakTicks;
		private int walkTicks;
		private boolean arrived;

		Bathe(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP));
		}

		private boolean thrive() {
			return this.blub.tide() == Tide.THRIVE && free(this.blub) && !this.blub.isListening();
		}

		@Override
		public boolean canUse() {
			if (!this.thrive() || --this.cooldown > 0) {
				return false;
			}
			this.cooldown = reducedTickDelay(40 + this.blub.getRandom().nextInt(61));
			if (this.blub.getRandom().nextInt(6) != 0) {
				return false;
			}
			this.spot = findSpot(this.blub);
			return this.spot != null;
		}

		@Override
		public boolean canContinueToUse() {
			return this.thrive() && this.spot != null && this.soakTicks > 0 && this.walkTicks < reducedTickDelay(300) && isBath(this.blub.level(), this.spot);
		}

		@Override
		public void start() {
			this.soakTicks = reducedTickDelay(200 + this.blub.getRandom().nextInt(401)); // tick() runs every other tick
			this.walkTicks = 0;
			this.arrived = false;
			walkTo(this.blub, this.spot, 1.0);
		}

		@Override
		public void tick() {
			if (this.blub.blockPosition().equals(this.spot)) {
				if (!this.arrived) {
					this.arrived = true;
					this.blub.playSound(ModSounds.BLUB_SPLASH, 0.8F, this.blub.getVoicePitch());
				}
				this.blub.getNavigation().stop();
				this.soakTicks--;
				if (this.blub.getRandom().nextInt(120) == 0) {
					this.blub.playSound(ModSounds.BLUB_SPLASH, 0.5F, this.blub.getVoicePitch());
				}
			} else if (++this.walkTicks % 20 == 0 || this.blub.getNavigation().isDone()) {
				walkTo(this.blub, this.spot, 1.0);
			}
		}

		@Override
		public void stop() {
			this.spot = null;
			this.blub.getNavigation().stop();
		}

		static boolean isBath(Level level, BlockPos pos) {
			return level.getFluidState(pos).is(ModTags.ICHOR) && level.getFluidState(pos.above()).isEmpty() && standable(level, pos);
		}

		static @Nullable BlockPos findSpot(Blub blub) {
			BlockPos origin = blub.blockPosition();
			for (int i = 0; i < 24; i++) {
				BlockPos p = origin.offset(blub.getRandom().nextInt(17) - 8, blub.getRandom().nextInt(5) - 2, blub.getRandom().nextInt(17) - 8);
				if (blub.level().isLoaded(p) && isBath(blub.level(), p)) {
					return p;
				}
			}
			return null;
		}
	}

	// ------------------------------------------------------------------ the pet (owner playtest 3, D-029)

	private static @Nullable LivingEntity owner(Blub blub) {
		LivingEntity owner = blub.isTame() ? blub.getOwner() : null;
		return owner != null && owner.isAlive() && owner.level() == blub.level() ? owner : null;
	}

	private static void hop(Blub blub) {
		if (blub.onGround()) {
			blub.getJumpControl().jump();
		}
	}

	/**
	 * GREET: an owner back after 30 s away (out of 24 blocks, or gone) is met: the blub hurries over,
	 * hops at their feet with a happy chirp and hearts, as a dog meets you at the door.
	 */
	static final class Greet extends Goal {
		private final Blub blub;
		private int ticks;
		private int hops;
		private boolean arrived;

		Greet(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP, Goal.Flag.LOOK));
		}

		@Override
		public boolean canUse() {
			return this.blub.greetDue() && free(this.blub) && owner(this.blub) != null;
		}

		@Override
		public boolean canContinueToUse() {
			return this.ticks > 0 && this.hops < 3 && free(this.blub) && owner(this.blub) != null;
		}

		@Override
		public void start() {
			this.blub.greeted();
			this.ticks = reducedTickDelay(240);
			this.hops = 0;
			this.arrived = false;
		}

		@Override
		public void tick() {
			LivingEntity owner = owner(this.blub);
			if (owner == null) {
				return;
			}
			this.ticks--;
			this.blub.getLookControl().setLookAt(owner, 30.0F, 30.0F);
			if (this.blub.distanceToSqr(owner) > 4.0) {
				if (this.ticks % 5 == 0 || this.blub.getNavigation().isDone()) {
					this.blub.getNavigation().moveTo(owner, 1.6);
				}
				return;
			}
			this.blub.getNavigation().stop();
			if (!this.arrived) {
				this.arrived = true;
				this.blub.playSound(ModSounds.BLUB_HAPPY, 1.0F, this.blub.getVoicePitch());
				this.blub.level().broadcastEntityEvent(this.blub, (byte) 7); // hearts, as vanilla taming
			}
			if (this.blub.onGround() && this.blub.getRandom().nextInt(3) == 0) {
				hop(this.blub);
				this.hops++;
			}
		}

		@Override
		public void stop() {
			this.blub.getNavigation().stop();
		}
	}

	/** BEG: a tidewrack frond in the owner's hand within 8 blocks: the blub watches it, head on one side, as a wolf begs. */
	static final class Beg extends Goal {
		private final Blub blub;

		Beg(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.LOOK));
		}

		private @Nullable LivingEntity begFrom() {
			LivingEntity owner = owner(this.blub);
			return owner != null && this.blub.distanceToSqr(owner) < 64.0 && owner.isHolding(ModItems.TIDEWRACK_FROND) ? owner : null;
		}

		@Override
		public boolean canUse() {
			return !this.blub.isCurled() && this.begFrom() != null;
		}

		@Override
		public boolean canContinueToUse() {
			return this.canUse();
		}

		@Override
		public void start() {
			this.blub.setInterested(true);
		}

		@Override
		public void tick() {
			LivingEntity owner = this.begFrom();
			if (owner != null) {
				this.blub.getLookControl().setLookAt(owner.getX(), owner.getEyeY(), owner.getZ(), 10.0F, this.blub.getMaxHeadXRot());
			}
		}

		@Override
		public void stop() {
			this.blub.setInterested(false);
		}
	}

	/**
	 * FORAGE: in Thrive a befriended blub now and then fetches a frond from ready tidewrack within 12
	 * blocks, picking it as you would (the plant's cycle stamp holds), carries it in its mouth and drops
	 * it at its owner's feet, as an allay brings what it finds. Every 2 to 4 minutes at most.
	 */
	static final class Forage extends Goal {
		static final int RANGE = 12;
		private final Blub blub;
		private @Nullable BlockPos plant;
		private int cooldown = reducedTickDelay(200);
		private int walkTicks;
		private boolean delivered;

		Forage(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP));
		}

		private boolean able() {
			LivingEntity owner = owner(this.blub);
			return free(this.blub) && !this.blub.isListening() && !this.blub.isBaby() && owner != null
					&& this.blub.distanceToSqr(owner) < 24.0 * 24.0;
		}

		private boolean carrying() {
			return !this.blub.getMainHandItem().isEmpty();
		}

		@Override
		public boolean canUse() {
			if (!this.able()) {
				return false;
			}
			if (this.carrying()) {
				return true; // a frond still in its mouth (a save, or an interrupted trip): deliver it
			}
			if (this.blub.tide() != Tide.THRIVE || --this.cooldown > 0) {
				return false;
			}
			this.cooldown = reducedTickDelay(400);
			this.plant = findReady(this.blub);
			return this.plant != null;
		}

		@Override
		public boolean canContinueToUse() {
			return !this.delivered && this.able() && this.walkTicks < reducedTickDelay(600)
					&& (this.carrying() || this.plant != null && isReady(this.blub.level(), this.plant));
		}

		@Override
		public void start() {
			this.walkTicks = 0;
			this.delivered = false;
		}

		@Override
		public void tick() {
			this.walkTicks++;
			LivingEntity owner = owner(this.blub);
			if (owner == null) {
				return;
			}
			if (this.carrying()) {
				if (this.blub.distanceToSqr(owner) > 3.0) {
					if (this.walkTicks % 10 == 0 || this.blub.getNavigation().isDone()) {
						this.blub.getNavigation().moveTo(owner, 1.3);
					}
					return;
				}
				// At the owner's feet: drop it toward them, chirp, hop.
				ItemStack frond = this.blub.getMainHandItem().copy();
				this.blub.setItemSlot(EquipmentSlot.MAINHAND, ItemStack.EMPTY);
				BehaviorUtils.throwItem(this.blub, frond, owner.position().add(0.0, 0.5, 0.0));
				this.blub.playSound(ModSounds.BLUB_HAPPY, 0.9F, this.blub.getVoicePitch());
				hop(this.blub);
				this.delivered = true;
				return;
			}
			if (this.plant == null) {
				return;
			}
			if (this.blub.distanceToSqr(Vec3.atBottomCenterOf(this.plant)) < 2.5) {
				BlockState state = this.blub.level().getBlockState(this.plant);
				if (this.blub.level() instanceof ServerLevel level && state.getBlock() instanceof TideFloraBlock flora && flora.isReady(state, level)) {
					List<ItemStack> picked = new ArrayList<>();
					flora.pick(level, this.plant, state, this.blub, picked::add);
					for (ItemStack stack : picked) {
						if (this.blub.getMainHandItem().isEmpty()) {
							this.blub.setItemSlot(EquipmentSlot.MAINHAND, stack);
							this.blub.setGuaranteedDrop(EquipmentSlot.MAINHAND);
						} else {
							BehaviorUtils.throwItem(this.blub, stack, owner.position()); // a second frond falls; the owner can take it
						}
					}
				}
				this.plant = null;
				this.blub.getNavigation().stop();
			} else if (this.walkTicks % 20 == 0 || this.blub.getNavigation().isDone()) {
				walkTo(this.blub, this.plant, 1.1);
			}
		}

		@Override
		public void stop() {
			this.blub.getNavigation().stop();
			this.plant = null;
			if (this.delivered) {
				this.cooldown = reducedTickDelay(2400 + this.blub.getRandom().nextInt(2400));
			}
		}

		static boolean isReady(Level level, BlockPos pos) {
			BlockState state = level.getBlockState(pos);
			return state.is(ModBlocks.TIDEWRACK) && ((TideFloraBlock) state.getBlock()).isReady(state, level);
		}

		/** The nearest ready tidewrack within RANGE blocks across and 3 up or down, or null. */
		static @Nullable BlockPos findReady(Blub blub) {
			BlockPos origin = blub.blockPosition();
			BlockPos best = null;
			double bestDist = Double.MAX_VALUE;
			for (BlockPos p : BlockPos.betweenClosed(origin.offset(-RANGE, -3, -RANGE), origin.offset(RANGE, 3, RANGE))) {
				if (blub.level().isLoaded(p) && isReady(blub.level(), p)) {
					double d = p.distSqr(origin);
					if (d < bestDist) {
						bestDist = d;
						best = p.immutable();
					}
				}
			}
			return best;
		}
	}

	/**
	 * PLAY: tag. Two befriended blubs of one owner, both idle in Thrive, now and then chase each other
	 * for 8 to 12 seconds with little hops; a catch is a chirp, and the other one is "it".
	 */
	static final class Play extends Goal {
		private final Blub blub;
		private int walkTicks;

		Play(Blub blub) {
			this.blub = blub;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP));
		}

		private static boolean idle(Blub blub) {
			return blub.isTame() && free(blub) && !blub.isListening() && !blub.isCurled() && blub.tide() == Tide.THRIVE
					&& blub.getMainHandItem().isEmpty();
		}

		@Override
		public boolean canUse() {
			if (this.blub.playTicks > 0) {
				return this.blub.playmate != null && idle(this.blub); // invited
			}
			if (!idle(this.blub) || this.blub.getRandom().nextInt(reducedTickDelay(1200)) != 0) {
				return false;
			}
			Blub mate = null;
			for (Blub other : this.blub.level().getEntitiesOfClass(Blub.class, this.blub.getBoundingBox().inflate(10.0))) {
				if (other != this.blub && other.playTicks == 0 && idle(other) && other.getOwnerReference() != null
						&& other.getOwnerReference().equals(this.blub.getOwnerReference())) {
					mate = other;
					break;
				}
			}
			if (mate == null) {
				return false;
			}
			int ticks = reducedTickDelay(160 + this.blub.getRandom().nextInt(81));
			this.blub.playmate = mate;
			mate.playmate = this.blub;
			this.blub.playTicks = ticks;
			mate.playTicks = ticks;
			this.blub.chasing = true;
			mate.chasing = false;
			this.blub.playSound(ModSounds.BLUB_HAPPY, 0.7F, this.blub.getVoicePitch() * 1.1F);
			return true;
		}

		@Override
		public boolean canContinueToUse() {
			Blub mate = this.blub.playmate;
			return this.blub.playTicks > 0 && mate != null && mate.isAlive() && mate.playmate == this.blub && free(this.blub)
					&& this.blub.distanceToSqr(mate) < 16.0 * 16.0;
		}

		@Override
		public void start() {
			this.walkTicks = 0;
		}

		@Override
		public void tick() {
			Blub mate = this.blub.playmate;
			if (mate == null) {
				return;
			}
			this.blub.playTicks--;
			this.walkTicks++;
			if (this.blub.chasing) {
				if (this.blub.distanceToSqr(mate) < 1.7) {
					// Tag: the other one is "it" now.
					this.blub.chasing = false;
					mate.chasing = true;
					this.blub.playSound(ModSounds.BLUB_HAPPY, 0.7F, this.blub.getVoicePitch() * 1.15F);
					hop(this.blub);
					hop(mate);
					this.walkTicks = 0;
				} else if (this.walkTicks % 5 == 0 || this.blub.getNavigation().isDone()) {
					this.blub.getNavigation().moveTo(mate, 1.5);
				}
			} else if (this.walkTicks % 15 == 0 || this.blub.getNavigation().isDone()) {
				Vec3 away = DefaultRandomPos.getPosAway(this.blub, 6, 3, mate.position());
				if (away != null) {
					this.blub.getNavigation().moveTo(away.x, away.y, away.z, 1.4);
				}
			}
			if (this.blub.getRandom().nextInt(8) == 0) {
				hop(this.blub);
			}
		}

		@Override
		public void stop() {
			Blub mate = this.blub.playmate;
			this.blub.playTicks = 0;
			this.blub.playmate = null;
			this.blub.chasing = false;
			if (mate != null && mate.playmate == this.blub) {
				mate.playTicks = 0;
			}
			this.blub.getNavigation().stop();
		}
	}
}
