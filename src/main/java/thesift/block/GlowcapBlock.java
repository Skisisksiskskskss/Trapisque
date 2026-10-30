package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.BonemealSource;
import net.minecraft.world.level.block.BonemealableBlock;
import net.minecraft.world.level.block.VegetationBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

/**
 * The glowcap (block_flora_ii.md §3): small flat-capped cave fungi with light 10 that ring the
 * Hollows' pools, so nothing spawns beside them. It stands on a solid floor (the mushrooms' test) in
 * any light, never spreads on its own, and in the Sift bone meal adds one more nearby, stopping at
 * vanilla's mushroom cap: 5 in the 9 × 3 × 9 box around it.
 */
public class GlowcapBlock extends VegetationBlock implements BonemealableBlock {
	private static final VoxelShape SHAPE = Block.column(12.0, 0.0, 6.0);
	private static final int CAP = 5;

	public GlowcapBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPE;
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return state.isSolidRender();
	}

	private boolean crowded(LevelReader level, BlockPos pos) {
		return !level.findBlocksIn(pos.offset(-4, -1, -4), pos.offset(4, 1, 4)).filterState(s -> s.is(this)).atMostMatched(CAP - 1);
	}

	@Override
	public boolean isValidBonemealTarget(LevelReader level, BlockPos pos, BlockState state, BonemealSource source) {
		return SiftPlants.canGrow(level, pos) && !this.crowded(level, pos);
	}

	@Override
	public boolean isBonemealSuccess(Level level, RandomSource random, BlockPos pos, BlockState state, BonemealSource source) {
		return true;
	}

	@Override
	public void performBonemeal(ServerLevel level, RandomSource random, BlockPos pos, BlockState state, BonemealSource source) {
		for (int i = 0; i < 8; i++) {
			BlockPos spot = pos.offset(random.nextInt(3) - 1, random.nextInt(3) - 1, random.nextInt(3) - 1);
			if (level.isEmptyBlock(spot) && state.canSurvive(level, spot)) {
				level.setBlock(spot, state, Block.UPDATE_ALL);
				return;
			}
		}
	}
}
