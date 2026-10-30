package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.HalfTransparentBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;

/**
 * Bounce jelly (owner playtest 6; canon's Carapace has "bouncy slimes used to access higher areas"): a
 * wobbling blue jelly at the foot of the Carapace's pillars that throws whoever steps on it about ten
 * blocks up, so the pillars' tops can be reached. Sneak to stand on it; landing on it hurts no more
 * than landing on slime.
 */
public class BounceJellyBlock extends HalfTransparentBlock {
	/** Upward speed it gives: about ten blocks of height under vanilla's gravity and drag. */
	public static final double LAUNCH = 1.35;

	public BounceJellyBlock(Properties properties) {
		super(properties);
	}

	@Override
	public void fallOn(Level level, BlockState state, BlockPos pos, Entity entity, double fallDistance) {
		if (entity.isSuppressingBounce()) {
			super.fallOn(level, state, pos, entity, fallDistance);
		} else {
			entity.causeFallDamage(fallDistance, 0.0F, level.damageSources().fall());
		}
	}

	@Override
	public void stepOn(Level level, BlockPos pos, BlockState state, Entity entity) {
		Vec3 motion = entity.getDeltaMovement();
		if (entity instanceof LivingEntity && !entity.isSteppingCarefully() && motion.y < LAUNCH / 2) {
			entity.setDeltaMovement(motion.x, LAUNCH, motion.z);
			entity.resetFallDistance();
			level.playSound(entity, pos, SoundEvents.SLIME_JUMP, SoundSource.BLOCKS, 1.0F, 1.3F);
		}
		super.stepOn(level, pos, state, entity);
	}
}
