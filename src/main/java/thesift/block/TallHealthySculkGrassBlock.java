package thesift.block;

import net.minecraft.world.level.block.state.properties.DoubleBlockHalf;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.DoublePlantBlock;
import net.minecraft.world.level.block.state.BlockState;

/** Tall healthy-sculk grass: a double plant that stands on the same ground as the short grass. */
public class TallHealthySculkGrassBlock extends DoublePlantBlock {
	public TallHealthySculkGrassBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.mayPlaceOn(state, level, pos);
	}

	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		if (state.getValue(HALF) == DoubleBlockHalf.UPPER) {
			MusicNearby.shedPetals(level, pos, random, 0.6);
		}
	}
}
