package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.BonemealSource;
import net.minecraft.world.level.block.SaplingBlock;
import net.minecraft.world.level.block.grower.TreeGrower;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Songwood sapling (world.md §3). It grows, by random ticks or bone meal, only where sift_life is
 * true, so songwood can be planted at home as decoration but never grows there.
 */
public class SongwoodSaplingBlock extends SaplingBlock {
	public SongwoodSaplingBlock(TreeGrower grower, Properties properties) {
		super(grower, properties);
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.mayPlaceOn(state, level, pos);
	}

	@Override
	protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
		if (SiftPlants.canGrow(level, pos)) {
			super.randomTick(state, level, pos, random);
		}
	}

	@Override
	public boolean isValidBonemealTarget(LevelReader level, BlockPos pos, BlockState state, BonemealSource source) {
		return SiftPlants.canGrow(level, pos) && super.isValidBonemealTarget(level, pos, state, source);
	}
}
