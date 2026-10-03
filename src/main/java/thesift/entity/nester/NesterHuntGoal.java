package thesift.entity.nester;

import java.util.Comparator;
import java.util.EnumSet;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.Mth;
import net.minecraft.world.Difficulty;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.entity.hunt.Hunt;
import thesift.registry.ModSounds;

/**
 * The listener's states and the duel, one goal with one state machine (mob_nester.md, AI): the tell,
 * the gallop to the sound's spot, the search round it, then the hunt: approach, lunge (windup, leap,
 * recovery) or a standing bite up close, and the circle with its guard up. Lumen is kept out of every
 * destination (system_hunt.md §6).
 */
final class NesterHuntGoal extends Goal {
	static final int TELL = 20;
	static final int SEARCH = 60;
	static final int GALLOP_LIMIT = 200;
	static final int WINDUP = 8;
	static final int LEAP_MAX = 12;
	static final int BITE_WINDUP = 6;
	static final int RECOVERY = 12;
	static final int CIRCLE = 30;
	static final int STAGGER = 30;
	static final int DODGE = 4;
	static final int UNSEEN_LIMIT = 100;
	static final double LUNGE_REACH = 4.0;
	static final double DROP_DISTANCE = 24.0;

	private final Nester nester;
	private @Nullable BlockPos aimedSound;
	private @Nullable Vec3 dest;
	private boolean atRim;
	private @Nullable Vec3 aim;
	private boolean bitten;
	private int unseen;
	private int repath;
	private int circleTicks;
	private int bumpCheck;
	private float strafeDir = 1.0F;

	NesterHuntGoal(Nester nester) {
		this.nester = nester;
		this.setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK, Goal.Flag.JUMP));
	}

	private ServerLevel level() {
		return (ServerLevel) this.nester.level();
	}

	private boolean hunting(NesterState state) {
		return state != NesterState.ROAM && state != NesterState.EMERGE && state != NesterState.DIG;
	}

	/** The target it keeps (§3): prey, close enough, seen lately, and outside lumen. */
	private @Nullable LivingEntity target() {
		LivingEntity target = this.nester.getTarget();
		if (target == null || !Nester.isPrey(target) || target.level() != this.nester.level()
				|| this.nester.distanceToSqr(target) > DROP_DISTANCE * DROP_DISTANCE || this.unseen > UNSEEN_LIMIT
				|| Hunt.inLumen(this.level(), target.position())) {
			return null;
		}
		return target;
	}

	@Override
	public boolean canUse() {
		NesterState state = this.nester.state();
		if (!this.hunting(state)) {
			if (state == NesterState.ROAM && --this.bumpCheck <= 0) {
				this.bumpCheck = reducedTickDelay(5);
				// The bump: a player within 2 blocks of a roaming listener.
				Player player = this.nester.level().getNearestPlayer(this.nester, 2.0);
				if (player != null && Nester.isPrey(player) && !Hunt.inLumen(this.level(), player.position())) {
					this.nester.setTarget(player);
					this.nester.setState(NesterState.GALLOP);
					return true;
				}
			}
			return false;
		}
		return this.nester.soundPos != null || this.target() != null;
	}

	@Override
	public boolean canContinueToUse() {
		return this.hunting(this.nester.state()) && (this.nester.soundPos != null || this.target() != null);
	}

	@Override
	public boolean requiresUpdateEveryTick() {
		return true;
	}

	@Override
	public void start() {
		this.dest = null;
		this.aimedSound = null;
		this.unseen = 0;
		this.repath = 0;
	}

	@Override
	public void stop() {
		this.nester.getNavigation().stop();
		this.nester.soundPos = null;
		this.nester.setTarget(null);
		if (this.hunting(this.nester.state())) {
			this.nester.setState(NesterState.ROAM);
		}
	}

	@Override
	public void tick() {
		LivingEntity target = this.target();
		if (this.nester.getTarget() != null && target == null) {
			this.nester.setTarget(null); // dropped: dead, gone, far, unseen, or inside lumen
			if (this.nester.soundPos == null) {
				this.nester.setState(NesterState.ROAM);
				return;
			}
		}
		if (target != null) {
			this.unseen = this.nester.getSensing().hasLineOfSight(target) ? 0 : this.unseen + 1;
		}
		int t = this.nester.stateTicks;
		switch (this.nester.state()) {
			case TELL -> {
				this.nester.getNavigation().stop();
				this.lookAt(this.nester.soundPos);
				if (t >= TELL) {
					this.nester.setState(NesterState.GALLOP);
				}
			}
			case GALLOP -> {
				if (target != null) {
					this.approach(target);
				} else {
					this.gallopToSound();
				}
			}
			case SEARCH -> this.search();
			case WINDUP -> {
				this.nester.getNavigation().stop();
				if (this.aim != null) {
					this.nester.getLookControl().setLookAt(this.aim.x, this.aim.y + 0.5, this.aim.z);
				}
				if (t >= WINDUP) {
					this.leap();
				}
			}
			case LEAP -> {
				if (!this.bitten && target != null && this.nester.isWithinMeleeAttackRange(target)) {
					this.bite(target);
				}
				if (t > 2 && this.nester.onGround() || t >= LEAP_MAX) {
					this.nester.setState(NesterState.RECOVERY);
				}
			}
			case BITE -> {
				if (target == null) {
					this.nester.setState(NesterState.RECOVERY);
					return;
				}
				this.nester.getLookControl().setLookAt(target, 30.0F, 30.0F);
				if (t < BITE_WINDUP) {
					this.nester.getNavigation().moveTo(target, 0.7); // it steps in
				} else if (t == BITE_WINDUP) {
					this.nester.getNavigation().stop();
					if (this.nester.isWithinMeleeAttackRange(target)) {
						this.bite(target);
					}
				} else if (t >= BITE_WINDUP + 2) {
					this.nester.setState(NesterState.RECOVERY);
				}
			}
			case RECOVERY -> {
				this.nester.getNavigation().stop();
				if (t >= RECOVERY) {
					this.beginCircle();
				}
			}
			case STAGGER -> {
				this.nester.getNavigation().stop();
				if (t >= STAGGER) {
					this.beginCircle();
				}
			}
			case CIRCLE, GUARD -> {
				if (target == null) {
					this.nester.setState(NesterState.ROAM);
					return;
				}
				this.circle(target);
			}
			case DODGE -> {
				if (t >= DODGE) {
					this.nester.setState(NesterState.CIRCLE); // the guard is down until the next circle
				}
			}
			default -> {
			}
		}
	}

	private void lookAt(@Nullable BlockPos pos) {
		if (pos != null) {
			this.nester.getLookControl().setLookAt(pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5);
		}
	}

	/** To the sound's spot, kept out of lumen (to the rim instead); a gallop that can't arrive in 200 ticks searches where it is. */
	private void gallopToSound() {
		BlockPos sound = this.nester.soundPos;
		if (sound == null) {
			this.nester.setState(NesterState.ROAM);
			return;
		}
		if (!sound.equals(this.aimedSound) || this.dest == null) {
			this.aimedSound = sound;
			Vec3 spot = Vec3.atBottomCenterOf(sound);
			this.dest = Hunt.keepOut(this.level(), spot, this.nester.position());
			if (this.dest == null) {
				this.nester.soundPos = null; // nowhere outside the light: it gives up
				this.nester.setState(NesterState.ROAM);
				return;
			}
			this.atRim = !this.dest.equals(spot);
			this.repath = 0;
		}
		if (--this.repath <= 0 || this.nester.getNavigation().isDone()) {
			this.repath = 10;
			this.nester.getNavigation().moveTo(this.dest.x, this.dest.y, this.dest.z, Nester.GALLOP);
		}
		this.thud();
		if (this.nester.position().distanceToSqr(this.dest) < 2.5 || this.nester.stateTicks >= GALLOP_LIMIT) {
			this.nester.getNavigation().stop();
			this.nester.setState(NesterState.SEARCH);
		}
	}

	private void thud() {
		if (this.nester.stateTicks % 6 == 0 && this.nester.getDeltaMovement().horizontalDistanceSqr() > 0.004) {
			this.nester.gallopStep();
		}
	}

	/**
	 * Sniffing round the spot (§3): it attacks the nearest prey within 6 of the spot that it can see; a
	 * sneaking one only within 2 of itself. At lumen's rim it paces, turned to the sound, and finds nothing.
	 */
	private void search() {
		BlockPos sound = this.nester.soundPos;
		if (sound == null || this.nester.stateTicks >= SEARCH) {
			this.nester.soundPos = null;
			this.nester.setState(NesterState.ROAM);
			return;
		}
		if (this.nester.stateTicks % 15 == 0) {
			this.nester.playSound(ModSounds.NESTER_SNIFF, 0.8F, this.nester.getVoicePitch());
		}
		if (this.atRim) {
			this.lookAt(sound);
			this.nester.getMoveControl().strafe(0.0F, 0.4F * this.strafeDir);
			if (this.nester.horizontalCollision || this.nester.stateTicks % 20 == 0) {
				this.strafeDir = -this.strafeDir;
			}
			return;
		}
		double sweep = Mth.sin(this.nester.stateTicks * 0.25F) * 3.0;
		this.nester.getLookControl().setLookAt(sound.getX() + 0.5 + sweep, sound.getY(), sound.getZ() + 0.5 - sweep);
		Vec3 spot = Vec3.atCenterOf(sound);
		LivingEntity found = this.nester.level().getEntitiesOfClass(LivingEntity.class, new AABB(sound).inflate(6.0),
				e -> Nester.isPrey(e) && e.distanceToSqr(spot) <= 36.0 && this.nester.hasLineOfSight(e)
						&& (!e.isSteppingCarefully() || e.distanceToSqr(this.nester) <= 4.0) && !Hunt.inLumen(this.level(), e.position()))
				.stream().min(Comparator.comparingDouble(e -> e.distanceToSqr(this.nester))).orElse(null);
		if (found != null) {
			this.nester.soundPos = null;
			this.nester.setTarget(found);
			this.unseen = 0;
			this.nester.setState(NesterState.GALLOP);
		}
	}

	/** Closing in: a standing bite in melee reach, a lunge from just beyond it out to 4 blocks. */
	private void approach(LivingEntity target) {
		this.nester.getLookControl().setLookAt(target, 30.0F, 30.0F);
		if (this.nester.isWithinMeleeAttackRange(target)) {
			this.nester.setState(NesterState.BITE);
			this.nester.playSound(ModSounds.NESTER_HISS, 0.8F, this.nester.getVoicePitch() * 1.1F);
			return;
		}
		double dist = this.nester.distanceTo(target);
		if (dist <= LUNGE_REACH && this.nester.onGround() && this.nester.getSensing().hasLineOfSight(target)) {
			this.aim = target.position(); // locked as the windup starts: sidestep in these 8 ticks
			this.nester.getNavigation().stop();
			this.nester.setState(NesterState.WINDUP);
			this.nester.playSound(ModSounds.NESTER_HISS, 1.0F, this.nester.getVoicePitch());
			return;
		}
		if (--this.repath <= 0) {
			// As vanilla's MeleeAttackGoal repaths: every 4-10 ticks, longer when far.
			this.repath = 4 + this.nester.getRandom().nextInt(7) + (dist > 16 ? 5 : 0);
			if (!this.nester.getNavigation().moveTo(target, Nester.GALLOP)) {
				this.repath += 15;
			}
		}
		this.thud();
	}

	private void leap() {
		Vec3 aim = this.aim != null ? this.aim : this.nester.position();
		Vec3 d = new Vec3(aim.x - this.nester.getX(), 0, aim.z - this.nester.getZ());
		double dist = d.length();
		// Scaled to the locked distance (up to 0.6 a tick), so a short lunge doesn't overshoot.
		double h = Mth.clamp(dist * 0.16, 0.15, 0.6);
		Vec3 v = dist > 1.0E-3 ? d.scale(h / dist) : Vec3.ZERO;
		this.nester.setDeltaMovement(v.x, 0.35, v.z);
		this.nester.needsSync = true;
		this.bitten = false;
		this.nester.setState(NesterState.LEAP);
	}

	private void bite(LivingEntity target) {
		this.bitten = true;
		this.nester.doHurtTarget(this.level(), target);
		this.nester.playSound(ModSounds.NESTER_BITE, 1.0F, this.nester.getVoicePitch());
	}

	private void beginCircle() {
		this.circleTicks = 0;
		this.nester.dodgesLeft = this.nester.level().getDifficulty() == Difficulty.HARD ? 2 : 1;
		this.nester.setState(NesterState.GUARD);
		this.nester.playSound(ModSounds.NESTER_GUARD, 1.0F, this.nester.getVoicePitch());
	}

	/** The circle (§3, "circles on cooldown"): a strafe at about 4 blocks, facing its target, guard up. */
	private void circle(LivingEntity target) {
		this.circleTicks++;
		this.nester.getNavigation().stop();
		this.nester.getLookControl().setLookAt(target, 30.0F, 30.0F);
		this.nester.setYRot(Mth.approachDegrees(this.nester.getYRot(), this.nester.yHeadRot, 30.0F));
		double dist = this.nester.distanceTo(target);
		float forward = dist > 4.5 ? 0.5F : dist < 3.5 ? -0.5F : 0.0F;
		this.nester.getMoveControl().strafe(forward, 0.7F * this.strafeDir);
		if (this.nester.horizontalCollision) {
			this.strafeDir = -this.strafeDir;
		}
		if (this.nester.state() == NesterState.GUARD && this.circleTicks % 10 == 0) {
			this.nester.playSound(ModSounds.NESTER_GUARD, 0.6F, this.nester.getVoicePitch());
		}
		if (this.nester.isWithinMeleeAttackRange(target)) {
			this.nester.setState(NesterState.BITE); // pressing in ends the circle with a standing bite
		} else if (this.circleTicks >= CIRCLE) {
			this.nester.setState(NesterState.GALLOP);
		}
	}
}
