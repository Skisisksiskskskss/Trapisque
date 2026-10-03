package thesift.block;

import java.util.Optional;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceKey;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.ScheduledTickAccess;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.BucketPickup;
import net.minecraft.world.level.block.LiquidBlockContainer;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.TheSift;
import thesift.registry.ModBlocks;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;
import thesift.registry.ModSounds;
import thesift.world.Tide;

/**
 * Tidewrack (block_flora_ii.md §1): wrack on a tide basin's floor that opens in Thrive. Basins flood
 * over it every Endure, so it holds ichor as a waterloggable block holds water: an ichor source only,
 * set by the vent's fill, a bucket or a dispenser, and given back to an empty bucket.
 */
public class TidewrackBlock extends TideFloraBlock implements LiquidBlockContainer, BucketPickup {
	public static final BooleanProperty SUBMERGED = BooleanProperty.create("submerged");
	public static final ResourceKey<LootTable> HARVEST = ResourceKey.create(net.minecraft.core.registries.Registries.LOOT_TABLE,
			TheSift.id("harvest/tidewrack"));
	private static final VoxelShape SHAPE = Block.column(14.0, 0.0, 4.0);

	@SuppressWarnings("this-escape") // vanilla blocks register their default state the same way
	public TidewrackBlock(Properties properties) {
		super(properties);
		this.registerDefaultState(this.defaultBlockState().setValue(SUBMERGED, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		super.createBlockStateDefinition(builder);
		builder.add(SUBMERGED);
	}

	@Override
	protected Tide openTide() {
		return Tide.THRIVE;
	}

	@Override
	protected ResourceKey<LootTable> harvestTable() {
		return HARVEST;
	}

	@Override
	protected SoundEvent openSound() {
		return ModSounds.TIDEWRACK_OPEN;
	}

	@Override
	protected SoundEvent closeSound() {
		return ModSounds.TIDEWRACK_CLOSE;
	}

	@Override
	protected int switchColour(boolean opening) {
		return opening ? 0xA9B34A : 0x5E6B2E;
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPE;
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return state.is(ModBlocks.TIDE_SAND);
	}

	@Override
	public @Nullable BlockState getStateForPlacement(BlockPlaceContext context) {
		FluidState fluid = context.getLevel().getFluidState(context.getClickedPos());
		return this.defaultBlockState().setValue(SUBMERGED, fluid.is(ModFluids.ICHOR));
	}

	@Override
	protected FluidState getFluidState(BlockState state) {
		return state.getValue(SUBMERGED) ? ModFluids.ICHOR.getSource(false) : super.getFluidState(state);
	}

	@Override
	protected BlockState updateShape(BlockState state, LevelReader level, ScheduledTickAccess ticks, BlockPos pos, Direction direction,
			BlockPos neighbourPos, BlockState neighbourState, RandomSource random) {
		if (state.getValue(SUBMERGED)) {
			ticks.scheduleTick(pos, ModFluids.ICHOR, ModFluids.ICHOR.getTickDelay(level));
		}
		return super.updateShape(state, level, ticks, pos, direction, neighbourPos, neighbourState, random);
	}

	/** Takes an ichor source only, and only while dry (as waterlogging takes source water only). */
	@Override
	public boolean canPlaceLiquid(@Nullable LivingEntity user, BlockGetter level, BlockPos pos, BlockState state, Fluid type) {
		return !state.getValue(SUBMERGED) && type == ModFluids.ICHOR;
	}

	@Override
	public boolean placeLiquid(LevelAccessor level, BlockPos pos, BlockState state, FluidState fluidState) {
		if (state.getValue(SUBMERGED) || !fluidState.is(ModFluids.ICHOR)) {
			return false;
		}
		if (!level.isClientSide()) {
			level.setBlock(pos, state.setValue(SUBMERGED, true), Block.UPDATE_ALL);
			level.scheduleTick(pos, fluidState.getType(), fluidState.getType().getTickDelay(level));
		}
		return true;
	}

	@Override
	public ItemStack pickupBlock(@Nullable LivingEntity user, LevelAccessor level, BlockPos pos, BlockState state) {
		if (!state.getValue(SUBMERGED)) {
			return ItemStack.EMPTY;
		}
		level.setBlock(pos, state.setValue(SUBMERGED, false), Block.UPDATE_ALL);
		return new ItemStack(ModItems.ICHOR_BUCKET);
	}

	@Override
	public Optional<SoundEvent> getPickupSound() {
		return ModFluids.ICHOR.getPickupSound();
	}

	/** The vent's fill and drain: submerge or dry a tidewrack in a basin layer. */
	public static BlockState withSubmerged(BlockState state, boolean submerged) {
		return state.setValue(SUBMERGED, submerged);
	}
}
