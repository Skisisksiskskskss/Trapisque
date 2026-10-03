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

import thesift.registry.ModBlocks;

/**
 * Endure blooms on the waterline (block_flora_ii.md §2): the chunk's surface is scanned for
 * waterline cells (ground with air above and ichor beside it at the same height); if there are any,
 * 2-4 blooms grow on waterline cells within 3 blocks of one of them.
 */
public record EndureBloomsFeature() implements Feature {
	public static final EndureBloomsFeature INSTANCE = new EndureBloomsFeature();
	public static final MapCodec<EndureBloomsFeature> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<EndureBloomsFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		int x0 = origin.getX() & ~15;
		int z0 = origin.getZ() & ~15;
		List<BlockPos> shore = new ArrayList<>();
		for (int dx = 0; dx < 16; dx++) {
			for (int dz = 0; dz < 16; dz++) {
				BlockPos plant = new BlockPos(x0 + dx, level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x0 + dx, z0 + dz), z0 + dz);
				if (waterline(level, plant)) {
					shore.add(plant);
				}
			}
		}
		if (shore.isEmpty()) {
			return false;
		}
		BlockPos centre = shore.get(random.nextInt(shore.size()));
		int blooms = 2 + random.nextInt(3);
		boolean placed = false;
		for (BlockPos p : shore) {
			if (blooms > 0 && p.distManhattan(centre) <= 3 && random.nextFloat() < 0.7F) {
				level.setBlock(p, ModBlocks.ENDURE_BLOOM.defaultBlockState(), Block.UPDATE_CLIENTS);
				blooms--;
				placed = true;
			}
		}
		return placed;
	}

	/** Air for the bloom, its ground below, and ichor beside the ground at the ground's height. */
	private static boolean waterline(WorldGenLevel level, BlockPos plant) {
		if (!level.getBlockState(plant).isAir()) {
			return false;
		}
		BlockPos ground = plant.below();
		BlockState below = level.getBlockState(ground);
		if (!ModBlocks.ENDURE_BLOOM.defaultBlockState().canSurvive(level, plant) || below.is(ModBlocks.ICHOR)) {
			return false;
		}
		for (Direction side : Direction.Plane.HORIZONTAL) {
			if (level.getBlockState(ground.relative(side)).is(ModBlocks.ICHOR)) {
				return true;
			}
		}
		return false;
	}
}
