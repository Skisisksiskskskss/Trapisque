package thesift.fluid;

import java.util.Map;
import java.util.Optional;
import java.util.WeakHashMap;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.Difficulty;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.LiquidBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.material.FlowingFluid;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModSounds;
import thesift.registry.ModBlocks;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;
import thesift.registry.ModTags;
import thesift.world.SoulPoints;

/**
 * Ichor (rules.md, D-013): a thick liquid you wade through. Vanilla gives swimming and currents
 * only to water and lava ({@code Entity.FLUIDS_WITH_CURRENT}), so ichor has neither; everything it
 * does to entities happens here in {@code entityInside}, with no Entity mixin. Outsiders are slowed,
 * set on fire and drained of XP. Fire Resistance stops the burning only. Entities in
 * {@code #thesift:ichor_adapted} are left alone. Numbers: BALANCE.md.
 */
public abstract class IchorFluid extends FlowingFluid {
	/** Per-tick multiplier on horizontal speed while wading; vertical is untouched so you can climb out. */
	public static final Vec3 WADE = new Vec3(0.5, 1.0, 0.5);
	public static final float BURN_SECONDS = 4.0F;
	/** Ticks between drained XP points: Peaceful/Easy, Normal, Hard. */
	public static final int DRAIN_INTERVAL_EASY = 20;
	public static final int DRAIN_INTERVAL_NORMAL = 10;
	public static final int DRAIN_INTERVAL_HARD = 5;

	/** entityInside runs once per touched ichor block; wading, burning and draining run once per tick. */
	private static final Map<Entity, Long> LAST_SOUL_TICK = new WeakHashMap<>();
	private static final Map<Entity, Long> SERVER_WADE_TICK = new WeakHashMap<>();
	private static final Map<Entity, Long> CLIENT_WADE_TICK = new WeakHashMap<>();

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

	public static boolean isAdapted(Entity entity) {
		return entity.is(ModTags.ICHOR_ADAPTED);
	}

	@Override
	protected void entityInside(Level level, BlockPos pos, Entity entity, InsideBlockEffectApplier effectApplier) {
		if (isAdapted(entity)) {
			return;
		}
		// Once per tick (entityInside runs once per touched ichor block), on both sides so a player's
		// own movement prediction agrees with the server.
		Map<Entity, Long> wadeTicks = level.isClientSide() ? CLIENT_WADE_TICK : SERVER_WADE_TICK;
		Long lastWade = wadeTicks.put(entity, level.getGameTime());
		if (lastWade == null || lastWade != level.getGameTime()) {
			wade(entity);
		}
		if (level instanceof ServerLevel serverLevel) {
			applySoulEffects(serverLevel, entity, serverLevel.getGameTime());
			// A slosh every half second while moving through it.
			if (entity.getDeltaMovement().horizontalDistanceSqr() > 1.0E-4 && (serverLevel.getGameTime() + entity.getId()) % 10 == 0 && !entity.isSilent()) {
				serverLevel.playSound(null, entity.getX(), entity.getY(), entity.getZ(), ModSounds.ICHOR_WADE, entity.getSoundSource(), 0.6F, 0.9F + serverLevel.getRandom().nextFloat() * 0.2F);
			}
		}
	}

	/**
	 * Thick going: horizontal speed is damped each tick, vertical speed is left alone so a jump still
	 * clears a one-block bank. (Not {@code makeStuckInBlock}: that zeroes all motion every tick, the
	 * cobweb rule, and caps a jump at under half a block.) Falls end softly, as in water.
	 */
	public static void wade(Entity entity) {
		Vec3 motion = entity.getDeltaMovement();
		entity.setDeltaMovement(motion.x * WADE.x, motion.y, motion.z * WADE.z);
		entity.resetFallDistance();
	}

	/** Burning and draining for an entity standing in ichor at {@code gameTime}: at most once per tick. */
	public static void applySoulEffects(ServerLevel level, Entity entity, long gameTime) {
		if (isAdapted(entity)) {
			return;
		}
		Long last = LAST_SOUL_TICK.put(entity, gameTime);
		if (last != null && last == gameTime) {
			return;
		}
		burn(level, entity);
		if (entity instanceof ServerPlayer player && !player.isCreative() && !player.isSpectator()) {
			drain(level, player, gameTime);
		}
	}

	private static void burn(ServerLevel level, Entity entity) {
		// Only the living burn: items (a death's drops) and other objects float through unharmed.
		if (entity instanceof LivingEntity living && !living.fireImmune() && !living.hasEffect(MobEffects.FIRE_RESISTANCE)) {
			living.igniteForSeconds(BURN_SECONDS);
		}
		if (level.getRandom().nextInt(4) == 0) {
			level.sendParticles(ParticleTypes.SOUL_FIRE_FLAME, entity.getX(), entity.getY() + 0.3, entity.getZ(), 1, entity.getBbWidth() / 2, 0.2, entity.getBbWidth() / 2, 0.01);
		}
	}

	public static int drainInterval(Difficulty difficulty) {
		return switch (difficulty) {
			case PEACEFUL, EASY -> DRAIN_INTERVAL_EASY;
			case NORMAL -> DRAIN_INTERVAL_NORMAL;
			case HARD -> DRAIN_INTERVAL_HARD;
		};
	}

	private static void drain(ServerLevel level, ServerPlayer player, long gameTime) {
		if (gameTime % drainInterval(level.getDifficulty()) != 0 || SoulPoints.take(player, 1) == 0) {
			return;
		}
		level.sendParticles(ParticleTypes.SCULK_SOUL, player.getX(), player.getY() + 1.0, player.getZ(), 1, 0.2, 0.3, 0.2, 0.02);
		if (level.getRandom().nextInt(4) == 0) {
			level.playSound(null, player.blockPosition(), SoundEvents.SOUL_ESCAPE.value(), SoundSource.PLAYERS, 0.6F, 0.8F + level.getRandom().nextFloat() * 0.4F);
		}
	}

	@Override
	public void animateTick(Level level, BlockPos pos, FluidState fluidState, RandomSource random) {
		BlockPos above = pos.above();
		if (!level.getBlockState(above).isAir() || level.getBlockState(above).isSolidRender()) {
			return;
		}
		if (random.nextInt(60) == 0) {
			level.addParticle(ParticleTypes.SOUL_FIRE_FLAME, pos.getX() + random.nextDouble(), pos.getY() + fluidState.getHeight(level, pos),
					pos.getZ() + random.nextDouble(), 0.0, 0.02, 0.0);
		}
		if (fluidState.isSource() && random.nextInt(300) == 0) {
			level.playLocalSound(pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, ModSounds.ICHOR_AMBIENT, SoundSource.BLOCKS,
					0.4F, 0.9F + random.nextFloat() * 0.2F, false);
		}
	}

	@Override
	public @Nullable ParticleOptions getDripParticle() {
		return ParticleTypes.DRIPPING_OBSIDIAN_TEAR;
	}

	@Override
	protected void beforeDestroyingBlock(LevelAccessor level, BlockPos pos, BlockState state) {
		level.levelEvent(1501, pos, 0); // the lava fizz
	}

	@Override
	public int getSlopeFindDistance(LevelReader level) {
		return 2;
	}

	@Override
	public int getDropOff(LevelReader level) {
		return 2;
	}

	@Override
	public int getTickDelay(LevelReader level) {
		return 20;
	}

	@Override
	protected boolean canConvertToSource(ServerLevel level) {
		return false;
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
		return false;
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
