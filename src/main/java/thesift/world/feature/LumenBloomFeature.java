package thesift.world.feature;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.registry.ModBlocks;

/**
 * A lumen bloom (block_flora_ii.md §5): one at the origin, sometimes a second beside it; on the
 * surface, half of them are ringed by a dense band of chime bells 7-8 blocks out, just beyond the
 * repel radius, so the safe pocket is reached by sneaking (concept 7). In the Hollows, no band.
 */
public record LumenBloomFeature() implements Feature {
	public static final LumenBloomFeature INSTANCE = new LumenBloomFeature();
	public static final MapCodec<LumenBloomFeature> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<LumenBloomFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		BlockState lumen = ModBlocks.LUMEN_BLOOM.defaultBlockState();
		if (!level.getBlockState(origin).isAir() || !lumen.canSurvive(level, origin)) {
			return false;
		}
		level.setBlock(origin, lumen, Block.UPDATE_CLIENTS);
		if (random.nextBoolean()) {
			BlockPos second = origin.offset(random.nextInt(3) - 1, 0, random.nextInt(3) - 1);
			if (level.getBlockState(second).isAir() && lumen.canSurvive(level, second)) {
				level.setBlock(second, lumen, Block.UPDATE_CLIENTS);
			}
		}
		if (level.canSeeSkyFromBelowWater(origin) && random.nextBoolean()) {
			this.band(level, random, origin);
		}
		return true;
	}

	/** About 70 % of the cells 7-8 blocks out, each on its own surface (the band follows the ground). */
	private void band(WorldGenLevel level, RandomSource random, BlockPos centre) {
		BlockState bell = ModBlocks.CHIME_BELL_FLOWER.defaultBlockState();
		for (int dx = -8; dx <= 8; dx++) {
			for (int dz = -8; dz <= 8; dz++) {
				double d = Math.sqrt(dx * dx + dz * dz);
				if (d < 6.5 || d >= 8.5 || random.nextFloat() >= 0.7F) {
					continue;
				}
				int x = centre.getX() + dx;
				int z = centre.getZ() + dz;
				BlockPos p = new BlockPos(x, level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x, z), z);
				if (Math.abs(p.getY() - centre.getY()) <= 4 && level.getBlockState(p).isAir() && bell.canSurvive(level, p)) {
					level.setBlock(p, bell, Block.UPDATE_CLIENTS);
				}
			}
		}
	}
}
