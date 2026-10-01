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
 * Places one tide basin in the middle of a chunk when that spot is a low: the basin sits at the
 * lowest point of its rim, and the land around must be higher on average. A basin is
 * at most 13 wide and centred, so it never crosses its chunk.
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
		int cx = (origin.getX() & ~15) + 8;
		int cz = (origin.getZ() & ~15) + 8;
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
		basin.carve(level);
		return true;
	}

	/** The y of the topmost solid block during generation. */
	private static int groundAt(WorldGenLevel level, int x, int z) {
		return level.getHeight(Heightmap.Types.OCEAN_FLOOR_WG, x, z) - 1;
	}
}
