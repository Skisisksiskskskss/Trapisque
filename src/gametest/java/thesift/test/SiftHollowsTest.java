package thesift.test;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

import javax.imageio.ImageIO;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkAccess;
import net.minecraft.world.level.levelgen.Heightmap;

import thesift.TheSift;
import thesift.block.TideVentBlock;
import thesift.registry.ModBlocks;
import thesift.world.SiftKeys;
import thesift.world.TideBasin;

/**
 * WP-063: the Sift Hollows, the cave layer under the Meadow. Four patches of 25 chunks (SiftSamples),
 * far apart so one mountain or one sea doesn't decide the result, measured by depth below the ground
 * (the top hymnstone, healthy sculk or tide sand of each column).
 */
public final class SiftHollowsTest {
	private static final String SIFT = "thesift:the_sift";
	/**
	 * The Meadow's skin: the top this many blocks of each column. The Hollows begin at the biome depth
	 * SiftWorldgen.HOLLOWS_DEPTH, about 26 blocks under vanilla's smooth offset surface (3 / 384 a
	 * block); the real ground wanders above and below that, so the skin is measured a little shallower.
	 */
	private static final int HOLLOWS_DEPTH_BLOCKS = 19;
	/** The slices for looking (dump-hollows) are cut around the first patch. */
	private static final int RADIUS = 5;

	@GameTest(dimension = SIFT, maxTicks = 400)
	public void hollowsLieUnderTheMeadow(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		long nearAir = 0;
		long nearAll = 0;
		long deepAir = 0;
		long deepAll = 0;
		int hymnstoneFloors = 0;
		int soilFloors = 0;
		int bottomAir = 0;
		int biomeChecks = 0;
		int meadowRight = 0;
		int hollowsRight = 0;
		int vents = 0;
		int openVents = 0;
		int chunks = 0;
		for (int[] centre : SiftSamples.PATCHES) {
			for (int dx = -SiftSamples.PATCH; dx <= SiftSamples.PATCH; dx++) {
				for (int dz = -SiftSamples.PATCH; dz <= SiftSamples.PATCH; dz++) {
					ChunkAccess chunk = level.getChunk(centre[0] + dx, centre[1] + dz);
					chunks++;
					for (int x = 0; x < 16; x++) {
						for (int z = 0; z < 16; z++) {
							int ground = ground(chunk, x, z);
							BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
							for (int y = ground; y >= level.getMinY(); y--) {
								BlockState state = chunk.getBlockState(p.set(x, y, z));
								int depth = ground - y;
								boolean air = state.isAir() || state.is(ModBlocks.ICHOR); // open: caves below sea level fill with ichor
								if (y <= level.getMinY() + 2 && air) {
									bottomAir++;
								}
								if (depth < HOLLOWS_DEPTH_BLOCKS) {
									nearAll++;
									nearAir += air ? 1 : 0;
								} else {
									deepAll++;
									deepAir += air ? 1 : 0;
									if (!air && chunk.getBlockState(p.set(x, y + 1, z)).isAir()) {
										if (state.is(ModBlocks.HEALTHY_SCULK)) {
											soilFloors++;
										} else if (state.is(ModBlocks.HYMNSTONE)) {
											hymnstoneFloors++;
										}
									}
									p.set(x, y, z);
								}
								if (state.is(ModBlocks.TIDE_VENT)) {
									vents++;
									BlockPos vent = new BlockPos(chunk.getPos().getMinBlockX() + x, y, chunk.getPos().getMinBlockZ() + z);
								openVents += enclosed(level, vent, TideVentBlock.inner(state)) ? 0 : 1;
								}
							}
							if ((x & 7) == 4 && (z & 7) == 4 && chunk.getFluidState(p.set(x, ground + 1, z)).isEmpty() && ground - 50 > level.getMinY() + 8) {
								int wx = chunk.getPos().getMinBlockX() + x;
								int wz = chunk.getPos().getMinBlockZ() + z;
								biomeChecks++;
								boolean meadowAbove = level.getBiome(new BlockPos(wx, ground + 1, wz)).is(SiftKeys.SINGERS_MEADOW)
										|| level.getBiome(new BlockPos(wx, ground + 1, wz)).is(SiftKeys.ICHOR_FLATS)
										|| level.getBiome(new BlockPos(wx, ground + 1, wz)).is(SiftKeys.CARAPACE)
										|| level.getBiome(new BlockPos(wx, ground + 1, wz)).is(SiftKeys.LULLABY_HILLS);
								boolean hollowsBelow = level.getBiome(new BlockPos(wx, ground - 50, wz)).is(SiftKeys.SIFT_HOLLOWS);
								meadowRight += meadowAbove ? 1 : 0;
								hollowsRight += hollowsBelow ? 1 : 0;
							}
						}
					}
				}
			}
		}
		double near = 100.0 * nearAir / Math.max(1, nearAll);
		double deep = 100.0 * deepAir / Math.max(1, deepAll);
		double soil = 100.0 * soilFloors / Math.max(1, soilFloors + hymnstoneFloors);
		TheSift.LOGGER.info("Hollows sample, {} chunks: open {}% in the top {} blocks, {}% below; cave floors {} ({}% healthy sculk); biomes checked in {} columns (Meadow above {}, Hollows below {}); {} vents, {} open; {} air blocks at the bottom",
				chunks, fmt(near), HOLLOWS_DEPTH_BLOCKS, fmt(deep), soilFloors + hymnstoneFloors, fmt(soil), biomeChecks, meadowRight, hollowsRight, vents, openVents, bottomAir);
		dumpSlices(level, SiftSamples.PATCHES[0][0], SiftSamples.PATCHES[0][1]);
		// Vanilla's caves: a few percent open on average, more under hills, less under plains.
		helper.assertTrue(deep > 1.0 && deep < 35.0, "the Hollows are caves, not a void: " + fmt(deep) + "% open below " + HOLLOWS_DEPTH_BLOCKS);
		helper.assertTrue(near < 10.0, "the Meadow's skin holds; only entrances open it: " + fmt(near) + "% open in the top " + HOLLOWS_DEPTH_BLOCKS);
		helper.assertTrue(soil > 15.0 && soil < 75.0, "cave floors are hymnstone with patches of soil: " + fmt(soil) + "% soil");
		// An entrance pit puts its own floor in the Hollows, so a few columns read otherwise.
		helper.assertTrue(meadowRight >= biomeChecks * 0.9, "on dry land the Meadow or the Ichor Flats is the surface: " + meadowRight + "/" + biomeChecks);
		// Depth is measured from vanilla's smooth offset surface: under a peak the real ground stands
		// well above it, and the Hollows begin deeper than 50 blocks down.
		helper.assertTrue(hollowsRight >= biomeChecks * 0.7, "the Hollows lie 50 blocks under most dry land: " + hollowsRight + "/" + biomeChecks);
		// A basin checks its walls when placed; a neighbour chunk's pool decorated later can still open
		// one now and then. Harmless since D-024 (the leak runs like water and dries with the tide), so
		// rare is enough.
		helper.assertTrue(openVents * 10 <= Math.max(vents, 1), "generated basins are walled in rock (at most 1 in 10 opened later): " + openVents + "/" + vents);
		helper.assertValueEqual(bottomAir, 0, "the bedrock floor is whole");
		helper.succeed();
	}

	/** The top of the land in a column: hymnstone, healthy sculk, tide sand or a vent (not trees or plants). */
	private static int ground(ChunkAccess chunk, int x, int z) {
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int y = chunk.getHeight(Heightmap.Types.WORLD_SURFACE, x, z); y > chunk.getMinY(); y--) {
			BlockState state = chunk.getBlockState(p.set(x, y, z));
			if (state.is(ModBlocks.HYMNSTONE) || state.is(ModBlocks.HEALTHY_SCULK) || state.is(ModBlocks.TIDE_SAND) || state.is(ModBlocks.TIDE_VENT)) {
				return y;
			}
		}
		return chunk.getMinY();
	}

	/**
	 * True if every cell around a generated basin's footprint is solid from its vent up to its ground.
	 * Read through the level, not the chunk: the ring crosses into neighbouring chunks.
	 */
	private static boolean enclosed(ServerLevel level, BlockPos vent, int inner) {
		TideBasin shape = new TideBasin(BlockPos.ZERO, inner);
		int rim = shape.half() + 1;
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int dx = -rim; dx <= rim; dx++) {
			for (int dz = -rim; dz <= rim; dz++) {
				if (shape.inFootprint(dx, dz)) {
					continue;
				}
				for (int y = vent.getY(); y <= vent.getY() + TideBasin.DEPTH; y++) {
					if (level.getBlockState(p.set(vent.getX() + dx, y, vent.getZ() + dz)).isAir()) {
						return false;
					}
				}
			}
		}
		return true;
	}

	private static String fmt(double v) {
		return String.format(Locale.ROOT, "%.1f", v);
	}

	/**
	 * For looking at the caves without a client: with a file named {@code dump-hollows} in the run
	 * directory, writes a vertical slice (x by y) and a level slice (x by z, at y 40) of the sample.
	 */
	private static void dumpSlices(ServerLevel level, int cx0, int cz0) {
		Path marker = Path.of("dump-hollows");
		if (!Files.exists(marker)) {
			return;
		}
		int size = (2 * RADIUS + 1) * 16;
		int x0 = (cx0 - RADIUS) << 4;
		int z0 = (cz0 - RADIUS) << 4;
		BufferedImage side = new BufferedImage(size, level.getHeight(), BufferedImage.TYPE_INT_RGB);
		BufferedImage plan = new BufferedImage(size, size, BufferedImage.TYPE_INT_RGB);
		for (int i = 0; i < size; i++) {
			int surface = level.getHeight(Heightmap.Types.WORLD_SURFACE, x0 + i, z0 + size / 2);
			for (int y = level.getMinY(); y < level.getMaxY(); y++) {
				BlockState state = level.getBlockState(new BlockPos(x0 + i, y, z0 + size / 2));
				side.setRGB(i, level.getMaxY() - 1 - y, colour(state, y >= surface));
			}
			for (int j = 0; j < size; j++) {
				plan.setRGB(i, j, colour(level.getBlockState(new BlockPos(x0 + i, 20, z0 + j)), false));
			}
		}
		// A shaded map of a wider area, to judge the land as a whole.
		int mapSize = 32 * 16;
		int mx0 = x0 - mapSize / 2 + size / 2;
		int mz0 = z0 - mapSize / 2 + size / 2;
		BufferedImage map = new BufferedImage(mapSize, mapSize, BufferedImage.TYPE_INT_RGB);
		int[][] heights = new int[mapSize][mapSize];
		for (int cx = mx0 >> 4; cx <= (mx0 + mapSize - 1) >> 4; cx++) {
			for (int cz = mz0 >> 4; cz <= (mz0 + mapSize - 1) >> 4; cz++) {
				level.getChunk(cx, cz);
			}
		}
		int wet = 0;
		for (int i = 0; i < mapSize; i++) {
			for (int j = 0; j < mapSize; j++) {
				heights[i][j] = level.getHeight(Heightmap.Types.WORLD_SURFACE, mx0 + i, mz0 + j);
			}
		}
		for (int i = 0; i < mapSize; i++) {
			for (int j = 0; j < mapSize; j++) {
				int h = heights[i][j];
				BlockState top = level.getBlockState(new BlockPos(mx0 + i, h - 1, mz0 + j));
				wet += top.is(ModBlocks.ICHOR) ? 1 : 0;
				int c = colour(top, false);
				int slope = (i > 0 ? heights[i][j] - heights[i - 1][j] : 0) + (j > 0 ? heights[i][j] - heights[i][j - 1] : 0);
				double shade = Math.max(0.55, Math.min(1.3, 1.0 + slope * 0.08));
				int r = (int) Math.min(255, ((c >> 16) & 255) * shade);
				int g = (int) Math.min(255, ((c >> 8) & 255) * shade);
				int b = (int) Math.min(255, (c & 255) * shade);
				map.setRGB(i, j, (r << 16) | (g << 8) | b);
			}
		}
		TheSift.LOGGER.info("Sift map, {} x {} blocks: {}% under ichor", mapSize, mapSize, fmt(100.0 * wet / (mapSize * mapSize)));
		// The surface biomes over a wide area, from the biome source alone (no chunks generated): one
		// pixel per 32 blocks, at y 80.
		int span = 192;
		BufferedImage biomes = new BufferedImage(span, span, BufferedImage.TYPE_INT_RGB);
		var resolver = level.getChunkSource().getGenerator().getBiomeSource().createUncachedResolver(level.getChunkSource().randomState());
		int flats = 0;
		for (int i = 0; i < span; i++) {
			for (int j = 0; j < span; j++) {
				var biome = resolver.getNoiseBiome((x0 >> 2) + (i - span / 2) * 8, 20, (z0 >> 2) + (j - span / 2) * 8);
				boolean isFlats = biome.is(SiftKeys.ICHOR_FLATS);
				flats += isFlats ? 1 : 0;
				biomes.setRGB(i, j, isFlats ? 0x3ABCCB : biome.is(SiftKeys.SIFT_HOLLOWS) ? 0x101018 : 0xF27B86);
			}
		}
		TheSift.LOGGER.info("Biome map, {} x {} blocks around ({}, {}): {}% Ichor Flats at y 80", span * 32, span * 32, x0, z0, fmt(100.0 * flats / (span * span)));
		try {
			ImageIO.write(side, "png", Path.of("hollows_side.png").toFile());
			ImageIO.write(plan, "png", Path.of("hollows_y20.png").toFile());
			ImageIO.write(map, "png", Path.of("sift_map.png").toFile());
			ImageIO.write(biomes, "png", Path.of("biome_map.png").toFile());
		} catch (IOException e) {
			TheSift.LOGGER.warn("Couldn't write the Hollows slices", e);
		}
	}

	private static int colour(BlockState state, boolean sky) {
		if (state.isAir()) {
			return sky ? 0xBDE8E0 : 0x101018;
		}
		if (state.is(ModBlocks.HYMNSTONE)) {
			return 0x8C3F4A;
		}
		if (state.is(ModBlocks.HEALTHY_SCULK)) {
			return 0xF27B86;
		}
		if (state.is(ModBlocks.ICHOR)) {
			return 0x3ABCCB;
		}
		if (state.is(ModBlocks.TIDE_SAND) || state.is(ModBlocks.TIDE_VENT)) {
			return 0xC3BED1;
		}
		if (state.is(Blocks.BEDROCK)) {
			return 0x555555;
		}
		return 0x6D86B8; // trees and plants
	}
}
