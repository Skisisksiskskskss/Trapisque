package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.lighting.LightEngine;

import thesift.registry.ModBlocks;

/**
 * The Sift's living ground cover over hymnstone, following crimson nylium's rules: covered by a block
 * that stops light, it dies back to hymnstone (world.md §3). Without Silk Touch it drops hymnstone.
 */
public class HealthySculkBlock extends Block {
	public HealthySculkBlock(Properties properties) {
		super(properties);
	}

	static boolean canStayAlive(BlockState state, LevelReader level, BlockPos pos) {
		BlockPos above = pos.above();
		BlockState aboveState = level.getBlockState(above);
		return LightEngine.getLightDampeningInto(state, aboveState, Direction.UP, aboveState.getLightDampening()) < 15;
	}

	@Override
	protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
		if (!canStayAlive(state, level, pos)) {
			level.setBlockAndUpdate(pos, ModBlocks.HYMNSTONE.defaultBlockState());
		}
	}
}
