package thesift.world.feature;

import java.util.ArrayList;
import java.util.List;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.block.TideRootsBlock;
import thesift.registry.ModBlocks;
import thesift.registry.ModTags;

/**
 * Wild tide roots (survival_sift.md §1): within 6 blocks of the origin, the grass or soil at the ichor's
 * edge turns to tide sand in a few places, and a grown clump of roots stands on each. Ponds' rims lie
 * below the grass, so no surface sand meets ichor until this makes some.
 */
public record TideRootsShoreFeature() implements Feature {
	public static final TideRootsShoreFeature INSTANCE = new TideRootsShoreFeature();
	public static final MapCodec<TideRootsShoreFeature> CODEC = MapCodec.unit(INSTANCE);
	private static final int REACH = 6;
	private static final int MAX = 5;

	@Override
	public MapCodec<TideRootsShoreFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		List<BlockPos> shore = new ArrayList<>();
		for (int dx = -REACH; dx <= REACH; dx++) {
			for (int dz = -REACH; dz <= REACH; dz++) {
				int x = origin.getX() + dx;
				int z = origin.getZ() + dz;
				BlockPos ground = new BlockPos(x, level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x, z) - 1, z);
				BlockState state = level.getBlockState(ground);
				if ((state.is(ModBlocks.HEALTHY_SCULK) || state.is(ModBlocks.SIFT_SOIL) || state.is(ModBlocks.TIDE_SAND)) && besideIchor(level, ground)) {
					shore.add(ground);
				}
			}
		}
		if (shore.isEmpty()) {
			return false;
		}
		BlockState roots = ModBlocks.TIDE_ROOTS.defaultBlockState().setValue(TideRootsBlock.AGE, 3);
		int placed = 0;
		for (int i = 0; i < MAX * 2 && placed < MAX; i++) {
			BlockPos ground = shore.get(random.nextInt(shore.size()));
			if (!level.getBlockState(ground.above()).isAir()) {
				continue;
			}
			level.setBlock(ground, ModBlocks.TIDE_SAND.defaultBlockState(), Block.UPDATE_CLIENTS);
			if (roots.canSurvive(level, ground.above())) {
				level.setBlock(ground.above(), roots, Block.UPDATE_CLIENTS);
				placed++;
			}
		}
		return placed > 0;
	}

	private static boolean besideIchor(WorldGenLevel level, BlockPos pos) {
		for (Direction side : Direction.Plane.HORIZONTAL) {
			if (level.getFluidState(pos.relative(side)).is(ModTags.ICHOR)) {
				return true;
			}
		}
		return false;
	}
}
