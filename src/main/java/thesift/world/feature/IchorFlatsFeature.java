package thesift.world.feature;

import java.util.concurrent.atomic.AtomicReference;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.LegacyRandomSource;
import net.minecraft.world.level.levelgen.WorldgenRandom;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.synth.SimplexNoise;

import thesift.registry.ModBlocks;
import thesift.world.SiftKeys;

/**
 * The Ichor Flats' pools (owner playtest 2, D-026): shallow, blotchy ichor spread among the grass,
 * as a mangrove swamp's water lies among its roots. One pass per chunk: where a world-seeded noise
 * is high and the ground is level, the top block becomes ichor (two deep where the noise is
 * highest) over a floor of tide sand. A cell is filled only if every neighbour at its level is
 * solid or ichor, so no pool ever runs downhill.
 */
public record IchorFlatsFeature() implements Feature {
	public static final IchorFlatsFeature INSTANCE = new IchorFlatsFeature();
	public static final MapCodec<IchorFlatsFeature> CODEC = MapCodec.unit(INSTANCE);
	/** Above this the column is a pool; above {@link #DEEP} it is two deep. */
	private static final float SHALLOW = 0.12F;
	private static final float DEEP = 0.55F;
	private static final AtomicReference<SeededNoise> NOISE = new AtomicReference<>();

	private record SeededNoise(long seed, SimplexNoise broad, SimplexNoise fine) {
	}

	@Override
	public MapCodec<IchorFlatsFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		SeededNoise noise = noise(level.getSeed());
		int x0 = origin.getX() & ~15;
		int z0 = origin.getZ() & ~15;
		BlockState ichor = ModBlocks.ICHOR.defaultBlockState();
		BlockState floor = ModBlocks.TIDE_SAND.defaultBlockState();
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		boolean placed = false;
		for (int dx = 0; dx < 16; dx++) {
			for (int dz = 0; dz < 16; dz++) {
				int x = x0 + dx;
				int z = z0 + dz;
				float n = noise.broad.get(x / 22.0, z / 22.0) + 0.5F * noise.fine.get(x / 7.0, z / 7.0);
				if (n < SHALLOW) {
					continue;
				}
				int y = level.getHeight(Heightmap.Types.OCEAN_FLOOR_WG, x, z) - 1;
				p.set(x, y, z);
				if (!isGround(level.getBlockState(p)) || !level.getBiome(p).is(SiftKeys.ICHOR_FLATS)
						|| !level.getBlockState(p.set(x, y + 1, z)).isAir()) {
					continue;
				}
				int depth = n > DEEP ? 2 : 1;
				if (!contained(level, x, y, z, depth)) {
					continue;
				}
				for (int d = 0; d < depth; d++) {
					level.setBlock(p.set(x, y - d, z), ichor, Block.UPDATE_CLIENTS);
				}
				level.setBlock(p.set(x, y - depth, z), floor, Block.UPDATE_CLIENTS);
				placed = true;
			}
		}
		return placed;
	}

	/** Natural ground a pool may sink into: the Meadow's grass, its soil, or tide sand. */
	private static boolean isGround(BlockState state) {
		return state.is(ModBlocks.HEALTHY_SCULK) || state.is(ModBlocks.SIFT_SOIL) || state.is(ModBlocks.TIDE_SAND);
	}

	/** True if every side of the column, at every level it will hold, is solid or already ichor. */
	private static boolean contained(WorldGenLevel level, int x, int y, int z, int depth) {
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int d = 0; d < depth; d++) {
			for (Direction side : Direction.Plane.HORIZONTAL) {
				BlockState state = level.getBlockState(p.set(x + side.getStepX(), y - d, z + side.getStepZ()));
				if (!state.is(ModBlocks.ICHOR) && !state.isSolid()) {
					return false;
				}
			}
		}
		return level.getBlockState(p.set(x, y - depth, z)).isSolid();
	}

	private static SeededNoise noise(long seed) {
		SeededNoise current = NOISE.get();
		if (current == null || current.seed() != seed) {
			current = new SeededNoise(seed,
					new SimplexNoise(new WorldgenRandom(new LegacyRandomSource(seed ^ 0x1C40_F1A7L))),
					new SimplexNoise(new WorldgenRandom(new LegacyRandomSource(seed ^ 0x5EED_F1A7L))));
			NOISE.set(current);
		}
		return current;
	}
}
