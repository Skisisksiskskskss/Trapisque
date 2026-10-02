package thesift.world.feature;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.world.TideBasin;

/**
 * Places one tide basin near the middle of a chunk when that spot is a low: the basin sits at the
 * lowest point of its rim, and the land around must be higher on average. A basin is at most 13
 * wide and within a block of the chunk's middle, so it never crosses its chunk.
 */
public record TideBasinFeature() implements Feature {
	public static final TideBasinFeature INSTANCE = new TideBasinFeature();
	public static final MapCodec<TideBasinFeature> CODEC = MapCodec.unit(INSTANCE);
	private static final int LOOK_AROUND = 20;
	private static final int MAX_MIDDLE_ABOVE_RIM = 3;

	@Override
	public MapCodec<TideBasinFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		// Near the middle of the chunk, a block either way (owner playtest 2: centred basins lined up
		// into a grid), so it still never crosses its chunk.
		int cx = (origin.getX() & ~15) + 8 + random.nextInt(3) - 1;
		int cz = (origin.getZ() & ~15) + 8 + random.nextInt(3) - 1;
		int inner = 2 + random.nextInt(2);
		TideBasin shape = new TideBasin(BlockPos.ZERO, inner);
		// The basin's ground is the lowest cell around it (the outer ring and the cut corners), so
		// its walls hold the top layer by construction.
		int rim = shape.half() + 1;
		int ground = Integer.MAX_VALUE;
		for (int dx = -rim; dx <= rim; dx++) {
			for (int dz = -rim; dz <= rim; dz++) {
				if (!shape.inFootprint(dx, dz)) {
					ground = Math.min(ground, groundAt(level, cx + dx, cz + dz));
				}
			}
		}
		// Not in a lake or river: a basin is a dry hollow the tide fills (D-024 brought standing ichor).
		if (!level.getFluidState(new BlockPos(cx, groundAt(level, cx, cz) + 1, cz)).isEmpty()) {
			return false;
		}
		// Not on a hilltop: the middle may stand at most a little above the rim's low point.
		if (groundAt(level, cx, cz) - ground > MAX_MIDDLE_ABOVE_RIM) {
			return false;
		}
		TideBasin basin = new TideBasin(new BlockPos(cx, ground - TideBasin.DEPTH, cz), inner);
		if (basin.vent().getY() <= level.getMinY() + 2) {
			return false;
		}
		// A low: the land around stands higher on average.
		int around = groundAt(level, cx + LOOK_AROUND, cz) + groundAt(level, cx - LOOK_AROUND, cz)
				+ groundAt(level, cx, cz + LOOK_AROUND) + groundAt(level, cx, cz - LOOK_AROUND);
		if (around < 4 * (ground + 1)) {
			return false;
		}
		// Caves can open the side of a low (WP-063): a basin needs rock all round its layers, or its
		// ichor would run off into them.
		if (!enclosed(level, shape, cx, cz, basin.vent().getY(), ground)) {
			return false;
		}
		basin.carve(level);
		return true;
	}

	/** True if every cell around the footprint is solid from the vent's level up to the ground. */
	private static boolean enclosed(WorldGenLevel level, TideBasin shape, int cx, int cz, int bottom, int ground) {
		int rim = shape.half() + 1;
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int dx = -rim; dx <= rim; dx++) {
			for (int dz = -rim; dz <= rim; dz++) {
				if (shape.inFootprint(dx, dz)) {
					continue;
				}
				for (int y = bottom; y <= ground; y++) {
					if (level.getBlockState(p.set(cx + dx, y, cz + dz)).isAir()) {
						return false;
					}
				}
			}
		}
		return true;
	}

	/** The y of the topmost solid block during generation. */
	private static int groundAt(WorldGenLevel level, int x, int z) {
		return level.getHeight(Heightmap.Types.OCEAN_FLOOR_WG, x, z) - 1;
	}
}
