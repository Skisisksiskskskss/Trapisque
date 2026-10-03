package thesift.block;

import net.minecraft.world.level.Level;
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
 * The Sift's grass over Sift soil (owner rework; was nylium over hymnstone, world.md §3): covered by a
 * block that stops light it dies back to soil, and in light it spreads onto nearby soil, as vanilla
 * grass does with dirt. Without Silk Touch it drops soil.
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
			level.setBlockAndUpdate(pos, ModBlocks.SIFT_SOIL.defaultBlockState());
			return;
		}
		// Spreading, as vanilla grass: four tries a tick, in light, onto soil that could stay alive.
		if (level.getMaxLocalRawBrightness(pos.above()) >= 9) {
			BlockState grass = this.defaultBlockState();
			for (int i = 0; i < 4; i++) {
				BlockPos target = pos.offset(random.nextInt(3) - 1, random.nextInt(5) - 3, random.nextInt(3) - 1);
				if (level.getBlockState(target).is(ModBlocks.SIFT_SOIL) && canStayAlive(grass, level, target)
						&& level.getFluidState(target.above()).isEmpty()) {
					level.setBlockAndUpdate(target, grass);
				}
			}
		}
	}

	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		if (level.getBlockState(pos.above()).canBeReplaced()) {
			MusicNearby.shedPetals(level, pos, random, 1.05);
		}
	}
}
