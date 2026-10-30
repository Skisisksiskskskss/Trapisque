package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.ItemLike;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.CropBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.registry.ModBlocks;
import thesift.registry.ModItems;
import thesift.registry.ModTags;

/**
 * Tide roots (survival_sift.md §1): the Sift's crop. It grows on tide sand with ichor beside the sand,
 * as sugar cane needs water beside its ground, so it never needs farmland (ichor isn't water). Four
 * stages, as beetroots; bone meal speeds it.
 */
public class TideRootsBlock extends CropBlock {
	public static final IntegerProperty AGE = BlockStateProperties.AGE_3;
	private static final VoxelShape[] SHAPES = Block.boxes(3, age -> Block.column(16.0, 0.0, 3 + age * 3));

	public TideRootsBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected IntegerProperty getAgeProperty() {
		return AGE;
	}

	@Override
	public int getMaxAge() {
		return 3;
	}

	@Override
	protected ItemLike getBaseSeedId() {
		return ModItems.TIDE_ROOT;
	}

	/** Tide sand with ichor touching it on a side. */
	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		if (!state.is(ModBlocks.TIDE_SAND)) {
			return false;
		}
		for (Direction side : Direction.Plane.HORIZONTAL) {
			if (level.getFluidState(pos.relative(side)).is(ModTags.ICHOR)) {
				return true;
			}
		}
		return false;
	}

	@Override
	protected boolean canSurvive(BlockState state, LevelReader level, BlockPos pos) {
		return this.mayPlaceOn(level.getBlockState(pos.below()), level, pos.below());
	}

	/** Ichor-watered every time: about one stage per 6 random ticks in good light (carrots on moist farmland). */
	@Override
	protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
		if (level.getRawBrightness(pos, 0) >= 9 && !this.isMaxAge(state) && random.nextInt(6) == 0) {
			level.setBlock(pos, this.getStateForAge(this.getAge(state) + 1), Block.UPDATE_CLIENTS);
		}
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		builder.add(AGE);
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPES[this.getAge(state)];
	}
}
