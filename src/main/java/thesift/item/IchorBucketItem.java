package thesift.item;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.BucketItem;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.phys.BlockHitResult;

import thesift.registry.ModAttributes;

/**
 * Ichor evaporates outside the Sift (rules.md): emptying the bucket where {@code sift_life} is
 * false leaves only soul smoke, like water emptied in the Nether.
 */
public class IchorBucketItem extends BucketItem {
	public IchorBucketItem(Fluid content, Properties properties) {
		super(content, properties);
	}

	public static boolean evaporatesAt(Level level, BlockPos pos) {
		return !level.environmentAttributes().getValue(ModAttributes.SIFT_LIFE, pos);
	}

	@Override
	public boolean emptyContents(@Nullable LivingEntity user, Level level, BlockPos pos, @Nullable BlockHitResult hitResult) {
		if (!evaporatesAt(level, pos)) {
			return super.emptyContents(user, level, pos, hitResult);
		}
		if (!level.getBlockState(pos).isAir() && !level.getBlockState(pos).canBeReplaced()) {
			return hitResult != null && this.emptyContents(user, level, hitResult.getBlockPos().relative(hitResult.getDirection()), null);
		}
		level.playSound(user, pos, SoundEvents.FIRE_EXTINGUISH, SoundSource.BLOCKS, 0.5F, 1.6F + level.getRandom().nextFloat() * 0.4F);
		if (level instanceof ServerLevel serverLevel) {
			serverLevel.sendParticles(ParticleTypes.SOUL, pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 8, 0.4, 0.4, 0.4, 0.02);
			serverLevel.sendParticles(ParticleTypes.LARGE_SMOKE, pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 6, 0.4, 0.4, 0.4, 0.0);
		}
		return true;
	}

	@Override
	protected void playEmptySound(@Nullable LivingEntity user, LevelAccessor level, BlockPos pos) {
		level.playSound(user, pos, SoundEvents.BUCKET_EMPTY_LAVA, SoundSource.BLOCKS, 1.0F, 0.8F);
	}
}
