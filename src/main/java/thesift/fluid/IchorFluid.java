package thesift.fluid;

import java.util.Optional;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.FluidTags;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.InsideBlockEffectType;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.LiquidBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.gamerules.GameRules;
import net.minecraft.world.level.material.FlowingFluid;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModBlocks;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;
import thesift.registry.ModSounds;

/**
 * Ichor, the Sift's water (D-024, the owner's playtest): turquoise with a soap bubble's sheen, and
 * swimmable as water is. It is in {@code #minecraft:water}, so swimming, currents, breath, boats and
 * putting out fire are vanilla's own, and it spreads and refills like water. Owner playtest 2 (D-026,
 * "acts too much like water"): it is thicker, flowing at 8 ticks a step against water's 5, and
 * buoyant, so whatever is in it drifts up to the surface unless a player holds sneak to dive. It is
 * its own fluid so the tide basins, the Blub's bathing and the bucket stay the Sift's, and a soul wisp
 * now and then rises from still ichor, the trace of canon's soul-draining liquid.
 */
public abstract class IchorFluid extends FlowingFluid {
	@Override
	public Fluid getFlowing() {
		return ModFluids.FLOWING_ICHOR;
	}

	@Override
	public Fluid getSource() {
		return ModFluids.ICHOR;
	}

	@Override
	public Item getBucket() {
		return ModItems.ICHOR_BUCKET;
	}

	/** Upward push per tick while in ichor, and the fastest it lifts (blocks per tick). */
	private static final double BUOYANCY = 0.025;
	private static final double MAX_RISE = 0.18;

	@Override
	protected void entityInside(Level level, BlockPos pos, Entity entity, InsideBlockEffectApplier effectApplier) {
		effectApplier.apply(InsideBlockEffectType.EXTINGUISH);
		// Buoyancy, once a tick: only from the block at the entity's feet (an entity touches several).
		// Runs wherever the entity moves (the server, or the client for its own player).
		if (pos.equals(entity.blockPosition()) && !entity.isShiftKeyDown() && !entity.isNoGravity()) {
			Vec3 motion = entity.getDeltaMovement();
			if (motion.y < MAX_RISE) {
				entity.setDeltaMovement(motion.x, Math.min(MAX_RISE, motion.y + BUOYANCY), motion.z);
			}
		}
	}

	@Override
	public void animateTick(Level level, BlockPos pos, FluidState fluidState, RandomSource random) {
		if (!fluidState.isSource() && !fluidState.getValue(FALLING)) {
			if (random.nextInt(64) == 0) {
				level.playLocalSound(pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, ModSounds.ICHOR_AMBIENT, SoundSource.AMBIENT,
						random.nextFloat() * 0.25F + 0.5F, random.nextFloat() * 0.4F + 0.8F, false);
			}
			return;
		}
		if (random.nextInt(10) == 0) {
			level.addParticle(ParticleTypes.UNDERWATER, pos.getX() + random.nextDouble(), pos.getY() + random.nextDouble(),
					pos.getZ() + random.nextDouble(), 0.0, 0.0, 0.0);
		}
		// A soul wisp now and then from open, still ichor.
		if (fluidState.isSource() && random.nextInt(400) == 0 && level.getBlockState(pos.above()).isAir()) {
			level.addParticle(ParticleTypes.SOUL, pos.getX() + random.nextDouble(), pos.getY() + 1.0, pos.getZ() + random.nextDouble(),
					0.0, 0.03, 0.0);
		}
	}

	@Override
	public @Nullable ParticleOptions getDripParticle() {
		return ParticleTypes.DRIPPING_WATER;
	}

	@Override
	protected boolean canConvertToSource(ServerLevel level) {
		return level.getGameRules().get(GameRules.WATER_SOURCE_CONVERSION);
	}

	@Override
	protected void beforeDestroyingBlock(LevelAccessor level, BlockPos pos, BlockState state) {
		BlockEntity blockEntity = state.hasBlockEntity() ? level.getBlockEntity(pos) : null;
		Block.dropResources(state, level, pos, blockEntity);
	}

	@Override
	public int getSlopeFindDistance(LevelReader level) {
		return 4;
	}

	@Override
	public int getDropOff(LevelReader level) {
		return 1;
	}

	@Override
	public int getTickDelay(LevelReader level) {
		return 8; // thicker than water's 5 (D-026)
	}

	@Override
	public BlockState createLegacyBlock(FluidState fluidState) {
		return ModBlocks.ICHOR.defaultBlockState().setValue(LiquidBlock.LEVEL, getLegacyLevel(fluidState));
	}

	@Override
	public boolean isSame(Fluid other) {
		return other == ModFluids.ICHOR || other == ModFluids.FLOWING_ICHOR;
	}

	@Override
	public boolean canBeReplacedWith(FluidState state, BlockGetter level, BlockPos pos, Fluid other, Direction direction) {
		return direction == Direction.DOWN && !other.is(FluidTags.WATER);
	}

	@Override
	protected float getExplosionResistance() {
		return 100.0F;
	}

	@Override
	public Optional<SoundEvent> getPickupSound() {
		return Optional.of(ModSounds.BUCKET_FILL_ICHOR);
	}

	public static class Flowing extends IchorFluid {
		@Override
		protected void createFluidStateDefinition(StateDefinition.Builder<Fluid, FluidState> builder) {
			super.createFluidStateDefinition(builder);
			builder.add(LEVEL);
		}

		@Override
		public int getAmount(FluidState fluidState) {
			return fluidState.getValue(LEVEL);
		}

		@Override
		public boolean isSource(FluidState fluidState) {
			return false;
		}
	}

	public static class Source extends IchorFluid {
		@Override
		public int getAmount(FluidState fluidState) {
			return 8;
		}

		@Override
		public boolean isSource(FluidState fluidState) {
			return true;
		}
	}
}
