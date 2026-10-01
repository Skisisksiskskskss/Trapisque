package thesift.block;

import java.util.Map;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Portal;
import net.minecraft.world.level.block.Rotation;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.EnumProperty;
import net.minecraft.world.level.gamerules.GameRules;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.entry.SiftGates;
import thesift.registry.ModTags;
import thesift.world.SiftKeys;
import thesift.world.Tide;

/**
 * The cyan membrane that fills an open frame or gate (entry_path.md §5–8). It is a portal like the
 * Nether's, with two differences: entities in {@code #thesift:cannot_cross} (wardens, bosses) are
 * never let through, and in the Overworld its particles show the Tide on the far side.
 */
public class SiftMembraneBlock extends Block implements Portal {
	public static final EnumProperty<Direction.Axis> AXIS = BlockStateProperties.HORIZONTAL_AXIS;
	private static final Map<Direction.Axis, VoxelShape> SHAPES = Shapes.rotateHorizontalAxis(Block.column(4.0, 16.0, 0.0, 16.0));

	@SuppressWarnings("this-escape") // vanilla blocks register their default state the same way
	public SiftMembraneBlock(BlockBehaviour.Properties properties) {
		super(properties);
		this.registerDefaultState(this.stateDefinition.any().setValue(AXIS, Direction.Axis.X));
	}

	public static boolean canCross(Entity entity) {
		return !entity.is(ModTags.CANNOT_CROSS);
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPES.get(state.getValue(AXIS));
	}

	@Override
	protected void entityInside(BlockState state, Level level, BlockPos pos, Entity entity, InsideBlockEffectApplier effectApplier, boolean isPrecise) {
		if (canCross(entity) && entity.canUsePortal(false)) {
			entity.setAsInsidePortal(this, pos);
		}
	}

	@Override
	public int getPortalTransitionTime(ServerLevel level, Entity entity) {
		// The same delay as a Nether portal, so the gamerules players already know apply.
		return entity instanceof Player player
				? Math.max(0, level.getGameRules().get(player.getAbilities().invulnerable
						? GameRules.PLAYERS_NETHER_PORTAL_CREATIVE_DELAY : GameRules.PLAYERS_NETHER_PORTAL_DEFAULT_DELAY))
				: 0;
	}

	@Override
	public @Nullable TeleportTransition getPortalDestination(ServerLevel currentLevel, Entity entity, BlockPos portalEntryPos) {
		return SiftGates.destination(currentLevel, entity, portalEntryPos);
	}

	@Override
	public Portal.Transition getLocalTransition() {
		return Portal.Transition.CONFUSION;
	}

	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		if (random.nextInt(120) == 0) {
			level.playLocalSound(pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, SoundEvents.AMETHYST_BLOCK_CHIME,
					SoundSource.BLOCKS, 0.6F, 0.5F + random.nextFloat() * 0.3F, false);
		}
		if (random.nextInt(3) != 0) {
			return;
		}
		ParticleOptions particle = farSideParticle(level);
		boolean alongX = state.getValue(AXIS) == Direction.Axis.X;
		double flip = random.nextBoolean() ? 1 : -1;
		double x = pos.getX() + (alongX ? random.nextDouble() : 0.5 + 0.3 * flip);
		double z = pos.getZ() + (alongX ? 0.5 + 0.3 * flip : random.nextDouble());
		double drift = 0.02 * flip;
		level.addParticle(particle, x, pos.getY() + random.nextDouble(), z, alongX ? 0 : drift, 0.01, alongX ? drift : 0);
	}

	/** Placeholder particles until the Sift's own particle types land (WP-041/042). */
	private static ParticleOptions farSideParticle(Level level) {
		if (SiftKeys.isSift(level)) {
			return ParticleTypes.GLOW; // the far side is the Overworld
		}
		Tide tide = Tide.fromClock(level);
		if (tide == null || tide == Tide.THRIVE) {
			return ParticleTypes.SPORE_BLOSSOM_AIR;
		}
		return tide == Tide.ENDURE ? ParticleTypes.SOUL : ParticleTypes.WAX_ON;
	}

	@Override
	protected ItemStack getCloneItemStack(LevelReader level, BlockPos pos, BlockState state, boolean includeData) {
		return ItemStack.EMPTY;
	}

	@Override
	protected BlockState rotate(BlockState state, Rotation rotation) {
		return rotation == Rotation.CLOCKWISE_90 || rotation == Rotation.COUNTERCLOCKWISE_90
				? state.setValue(AXIS, state.getValue(AXIS) == Direction.Axis.X ? Direction.Axis.Z : Direction.Axis.X)
				: state;
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		builder.add(AXIS);
	}
}
