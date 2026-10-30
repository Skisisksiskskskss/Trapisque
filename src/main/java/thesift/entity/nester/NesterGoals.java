package thesift.entity.nester;

import java.util.EnumSet;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.ai.util.DefaultRandomPos;
import net.minecraft.world.phys.Vec3;

import thesift.entity.hunt.Hunt;
import thesift.registry.ModSounds;

/** The Nester's goals besides the hunt (mob_nester.md, AI; system_hunt.md §4, §6). */
final class NesterGoals {
	private NesterGoals() {
	}

	/** EMERGE (40 ticks): a natural spawn rises out of the soil, heard 32 blocks out; it doesn't listen meanwhile. */
	static final class Emerge extends Goal {
		private final Nester nester;

		Emerge(Nester nester) {
			this.nester = nester;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK, Goal.Flag.JUMP));
		}

		@Override
		public boolean canUse() {
			return this.nester.state() == NesterState.EMERGE;
		}

		@Override
		public void start() {
			this.nester.getNavigation().stop();
			this.nester.level().playSound(null, this.nester.blockPosition(), ModSounds.NESTER_EMERGE, SoundSource.HOSTILE, 2.0F, 1.0F);
		}

		@Override
		public void tick() {
			this.nester.getNavigation().stop();
			if (this.nester.stateTicks >= Nester.EMERGE_TICKS) {
				this.nester.setState(NesterState.ROAM);
			}
		}
	}

	/**
	 * RETREAT (system §4): in falling Flow, at its moment, it goes to soil (underfoot, or the nearest
	 * within 16 across and 6 up or down, outside lumen) and digs for 60 ticks, then it's gone: no drops,
	 * no XP. A Nester fighting a target within 16 keeps fighting (the Thrive sweep caps it); hurt
	 * mid-dig, it keeps digging. With no soil near, it walks 8 blocks on and looks again.
	 */
	static final class Retreat extends Goal {
		private final Nester nester;
		private @Nullable BlockPos soil;
		private int walkTicks;
		private int check;

		Retreat(Nester nester) {
			this.nester = nester;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK, Goal.Flag.JUMP));
		}

		private boolean fighting() {
			LivingEntity target = this.nester.getTarget();
			return target != null && target.isAlive() && this.nester.distanceToSqr(target) < 16.0 * 16.0;
		}

		@Override
		public boolean canUse() {
			NesterState state = this.nester.state();
			if (state == NesterState.EMERGE || state == NesterState.DIG || --this.check > 0) {
				return false;
			}
			this.check = reducedTickDelay(20); // canUse runs every other tick: about once a second
			return this.nester.dawn() && !this.fighting();
		}

		@Override
		public boolean canContinueToUse() {
			return this.nester.state() == NesterState.DIG || this.nester.dawn() && !this.fighting();
		}

		@Override
		public void start() {
			this.nester.setTarget(null);
			this.nester.soundPos = null;
			this.nester.setState(NesterState.ROAM);
			this.soil = Hunt.findSoil((ServerLevel) this.nester.level(), this.nester.blockPosition());
			this.walkTicks = 0;
		}

		@Override
		public void tick() {
			if (this.nester.state() == NesterState.DIG) {
				this.nester.getNavigation().stop();
				if (this.nester.stateTicks >= Nester.DIG_TICKS) {
					this.nester.burrowedAway();
				}
				return;
			}
			this.walkTicks++;
			if (this.soil == null) {
				if (this.walkTicks % 100 == 0) {
					this.soil = Hunt.findSoil((ServerLevel) this.nester.level(), this.nester.blockPosition());
				}
				if (this.nester.getNavigation().isDone()) {
					Vec3 on = DefaultRandomPos.getPos(this.nester, 8, 3);
					if (on != null) {
						this.nester.getNavigation().moveTo(on.x, on.y, on.z, 1.0);
					}
				}
				return;
			}
			BlockPos under = this.nester.blockPosition().below();
			if (Hunt.isSoil(this.nester.level().getBlockState(under)) && under.distSqr(this.soil) <= 4.0 || this.walkTicks > 200
					&& Hunt.isSoil(this.nester.level().getBlockState(under))) {
				this.nester.getNavigation().stop();
				this.nester.setState(NesterState.DIG);
				this.nester.level().playSound(null, this.nester.blockPosition(), ModSounds.NESTER_BURROW, SoundSource.HOSTILE, 1.0F, 1.0F);
				return;
			}
			if (this.walkTicks > 200) {
				this.soil = Hunt.findSoil((ServerLevel) this.nester.level(), this.nester.blockPosition());
				this.walkTicks = 0;
			} else if (this.walkTicks % 20 == 1 || this.nester.getNavigation().isDone()) {
				this.nester.getNavigation().moveTo(this.soil.getX() + 0.5, this.soil.getY() + 1.0, this.soil.getZ() + 0.5, 1.0);
			}
		}
	}

	/** Lumen placed beside it, or a path that strays in (§6.3): checked every 5 ticks, it walks back out to the rim. */
	static final class LeaveLumen extends Goal {
		private final Nester nester;
		private @Nullable Vec3 out;
		private int ticks;
		private int check;

		LeaveLumen(Nester nester) {
			this.nester = nester;
			this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.JUMP));
		}

		@Override
		public boolean canUse() {
			NesterState state = this.nester.state();
			if (state == NesterState.EMERGE || state == NesterState.DIG || --this.check > 0) {
				return false;
			}
			this.check = reducedTickDelay(5); // about every 5 ticks (§6.3)
			return Hunt.lumenWithin((ServerLevel) this.nester.level(), this.nester.position(), Hunt.REPEL + 0.5) != null;
		}

		@Override
		public boolean canContinueToUse() {
			return this.out != null && this.ticks < 100 && this.nester.state() != NesterState.DIG
					&& Hunt.lumenWithin((ServerLevel) this.nester.level(), this.nester.position(), Hunt.REPEL + 0.5) != null;
		}

		@Override
		public void start() {
			this.ticks = 0;
			this.nester.setTarget(null);
			this.nester.soundPos = null;
			if (this.nester.state() != NesterState.ROAM) {
				this.nester.setState(NesterState.ROAM);
			}
			this.out = Hunt.keepOut((ServerLevel) this.nester.level(), this.nester.position(), this.nester.position());
			if (this.out != null) {
				this.nester.getNavigation().moveTo(this.out.x, this.out.y, this.out.z, 1.0);
			}
		}

		@Override
		public void tick() {
			this.ticks++;
			if (this.out != null && this.nester.getNavigation().isDone()) {
				this.nester.getNavigation().moveTo(this.out.x, this.out.y, this.out.z, 1.0);
			}
		}

		@Override
		public void stop() {
			this.out = null;
		}
	}

	/** Roaming: a slow wander; a wander target inside lumen is picked again (up to three tries), so idle Nesters don't gather at a lantern. */
	static final class Roam extends WaterAvoidingRandomStrollGoal {
		private final Nester nester;

		Roam(Nester nester) {
			super(nester, Nester.ROAM);
			this.nester = nester;
		}

		@Override
		public boolean canUse() {
			return this.nester.state() == NesterState.ROAM && super.canUse();
		}

		@Override
		public boolean canContinueToUse() {
			return this.nester.state() == NesterState.ROAM && super.canContinueToUse();
		}

		@Override
		protected @Nullable Vec3 getPosition() {
			for (int i = 0; i < 3; i++) {
				Vec3 pos = super.getPosition();
				if (pos == null || !Hunt.inLumen((ServerLevel) this.nester.level(), pos)) {
					return pos;
				}
			}
			return null;
		}
	}
}
