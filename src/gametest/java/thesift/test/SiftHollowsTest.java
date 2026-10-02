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
 * WP-063: the Sift Hollows, the cave layer under the Meadow. One sample of 121 fresh chunks, measured
 * by depth below the ground (the top hymnstone, healthy sculk or tide sand of each column).
 */
public final class SiftHollowsTest {
	private static final String SIFT = "thesift:the_sift";
	/** The Hollows begin about this many blocks below the ground (SiftWorldgen.HOLLOWS_DEPTH / 0.021). */
	private static final int HOLLOWS_DEPTH_BLOCKS = 19;
	private static final int RADIUS = 5;

	@GameTest(dimension = SIFT, maxTicks = 400)
	public void hollowsLieUnderTheMeadow(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockPos origin = helper.absolutePos(BlockPos.ZERO);
		int cx0 = (origin.getX() >> 4) + 160;
		int cz0 = (origin.getZ() >> 4) + 160;
		long nearAir = 0;
		long nearAll = 0;
		long deepAir = 0;
		long deepAll = 0;
		int hymnstoneFloors = 0;
		int soilFloors = 0;
		int bottomAir = 0;
		int biomeChecks = 0;
		int biomeRight = 0;
		int vents = 0;
		int openVents = 0;
		for (int dx = -RADIUS; dx <= RADIUS; dx++) {
			for (int dz = -RADIUS; dz <= RADIUS; dz++) {
				ChunkAccess chunk = level.getChunk(cx0 + dx, cz0 + dz);
				for (int x = 0; x < 16; x++) {
					for (int z = 0; z < 16; z++) {
						int ground = ground(chunk, x, z);
						BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
						for (int y = ground; y >= level.getMinY(); y--) {
							BlockState state = chunk.getBlockState(p.set(x, y, z));
							int depth = ground - y;
							boolean air = state.isAir();
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
								openVents += enclosed(chunk, p.immutable(), TideVentBlock.inner(state)) ? 0 : 1;
							}
						}
						if (x == 8 && z == 8 && ground - 30 > level.getMinY() + 8) {
							int wx = chunk.getPos().getMinBlockX() + x;
							int wz = chunk.getPos().getMinBlockZ() + z;
							biomeChecks++;
							boolean meadowAbove = level.getBiome(new BlockPos(wx, ground + 1, wz)).is(SiftKeys.SINGERS_MEADOW);
							boolean hollowsBelow = level.getBiome(new BlockPos(wx, ground - 30, wz)).is(SiftKeys.SIFT_HOLLOWS);
							biomeRight += meadowAbove && hollowsBelow ? 1 : 0;
						}
					}
				}
			}
		}
		double near = 100.0 * nearAir / Math.max(1, nearAll);
		double deep = 100.0 * deepAir / Math.max(1, deepAll);
		double soil = 100.0 * soilFloors / Math.max(1, soilFloors + hymnstoneFloors);
		TheSift.LOGGER.info("Hollows sample, 121 chunks: air {}% in the top {} blocks, {}% below; cave floors {} ({}% healthy sculk); biomes right in {}/{} columns; {} vents, {} open; {} air blocks at the bottom",
				fmt(near), HOLLOWS_DEPTH_BLOCKS, fmt(deep), soilFloors + hymnstoneFloors, fmt(soil), biomeRight, biomeChecks, vents, openVents, bottomAir);
		dumpSlices(level, cx0, cz0);
		helper.assertTrue(deep > 3.0 && deep < 30.0, "the Hollows are caves, not a void: " + fmt(deep) + "% air below " + HOLLOWS_DEPTH_BLOCKS);
		helper.assertTrue(near < 6.0, "the Meadow's skin holds; only entrances open it: " + fmt(near) + "% air in the top " + HOLLOWS_DEPTH_BLOCKS);
		helper.assertTrue(soil > 15.0 && soil < 75.0, "cave floors are hymnstone with patches of soil: " + fmt(soil) + "% soil");
		// An entrance pit puts its own floor in the Hollows, so a few columns read otherwise.
		helper.assertTrue(biomeRight >= biomeChecks * 0.9, "Meadow above, Hollows 30 blocks down: " + biomeRight + "/" + biomeChecks);
		helper.assertValueEqual(openVents, 0, "every generated basin is walled in rock (its ichor can't run into a cave)");
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

	/** True if every cell around a generated basin's footprint is solid from its vent up to its ground. */
	private static boolean enclosed(ChunkAccess chunk, BlockPos vent, int inner) {
		TideBasin shape = new TideBasin(BlockPos.ZERO, inner);
		int rim = shape.half() + 1;
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int dx = -rim; dx <= rim; dx++) {
			for (int dz = -rim; dz <= rim; dz++) {
				if (shape.inFootprint(dx, dz)) {
					continue;
				}
				for (int y = vent.getY(); y <= vent.getY() + TideBasin.DEPTH; y++) {
					if (chunk.getBlockState(p.set(vent.getX() + dx, y, vent.getZ() + dz)).isAir()) {
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
				plan.setRGB(i, j, colour(level.getBlockState(new BlockPos(x0 + i, 40, z0 + j)), false));
			}
		}
		try {
			ImageIO.write(side, "png", Path.of("hollows_side.png").toFile());
			ImageIO.write(plan, "png", Path.of("hollows_y40.png").toFile());
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
			return 0xD45FBF;
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
