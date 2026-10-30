package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.state.BlockState;

import thesift.registry.ModAttributes;
import thesift.registry.ModBlocks;

/** Shared rules for Sift plants (world.md §4): they grow and take bone meal only where sift_life is true. */
final class SiftPlants {
	private SiftPlants() {
	}

	static boolean isSiftGround(BlockState ground) {
		return ground.is(ModBlocks.HEALTHY_SCULK) || ground.is(BlockTags.DIRT);
	}

	static boolean canGrow(LevelReader level, BlockPos pos) {
		return level instanceof Level l && l.environmentAttributes().getValue(ModAttributes.SIFT_LIFE, pos);
	}

	static boolean canGrow(ServerLevel level, BlockPos pos) {
		return level.environmentAttributes().getValue(ModAttributes.SIFT_LIFE, pos);
	}

	static boolean mayPlaceOn(BlockState ground, BlockGetter level, BlockPos pos) {
		return isSiftGround(ground);
	}
}
