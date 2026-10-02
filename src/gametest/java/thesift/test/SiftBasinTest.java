package thesift.test;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.levelgen.Heightmap;

import thesift.TheSift;
import thesift.block.TideVentBlock;
import thesift.block.entity.TideVentBlockEntity;
import thesift.registry.ModBlocks;
import thesift.world.Tide;
import thesift.world.TideBasin;

/** WP-045: tide basins follow the Tide (systems.md §1). */
public final class SiftBasinTest {
	private static final String SIFT = "thesift:the_sift";
	/** Worldgen's smallest basin (inner 2: 11 x 11) with its walls, in a 17 x 16 x 17 test area. */
	static final String BIG = "thesift-gametest:big_empty";
	private static final int INNER = 2;
	private static final BlockPos VENT = new BlockPos(8, 1, 8);
	private static final long MID_THRIVE = 6_000;
	private static final long MID_ENDURE = Tide.ENDURE.startTick() + 6_000;

	/** A solid block of hymnstone with a basin carved into it; returns its vent. */
	private static TideVentBlockEntity basin(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		for (int x = 1; x <= 15; x++) {
			for (int z = 1; z <= 15; z++) {
				for (int y = 0; y <= 5; y++) {
					helper.setBlock(new BlockPos(x, y, z), ModBlocks.HYMNSTONE);
				}
			}
		}
		new TideBasin(helper.absolutePos(VENT), INNER).carve(level);
		return (TideVentBlockEntity) level.getBlockEntity(helper.absolutePos(VENT));
	}

	private static int ichorIn(GameTestHelper helper, TideBasin basin, int layer) {
		int n = 0;
		for (BlockPos p : basin.layer(layer)) {
			if (helper.getLevel().getBlockState(p).is(ModBlocks.ICHOR)) {
				n++;
			}
		}
		return n;
	}

	private static int filledLayers(GameTestHelper helper, TideBasin basin) {
		int full = 0;
		for (int k = 0; k < TideBasin.MAX_LAYERS; k++) {
			int n = ichorIn(helper, basin, k);
			if (n == basin.layer(k).size()) {
				full++;
			} else {
				helper.assertValueEqual(n, 0, "layer " + k + " is all or nothing");
			}
		}
		return full;
	}

	@GameTest(dimension = SIFT)
	public void targetLayersFollowTheTide(GameTestHelper helper) {
		helper.assertValueEqual(TideBasin.targetLayers(MID_THRIVE), 0, "Thrive is low tide");
		helper.assertValueEqual(TideBasin.targetLayers(MID_ENDURE), 3, "Endure is high tide");
		helper.assertValueEqual(TideBasin.targetLayers(Tide.FLOW_RISING.startTick()), 1, "rising Flow starts a layer up");
		helper.assertValueEqual(TideBasin.targetLayers(Tide.ENDURE.startTick() - 1), 3, "full by the end of rising Flow");
		helper.assertValueEqual(TideBasin.targetLayers(Tide.FLOW_FALLING.startTick()), 2, "falling Flow starts a layer down");
		helper.assertValueEqual(TideBasin.targetLayers(Tide.PERIOD_TICKS - 1), 0, "empty by the end of falling Flow");
		helper.succeed();
	}

	@GameTest(dimension = SIFT, structure = BIG)
	public void aBasinFloodsInEndureAndDrainsInThrive(GameTestHelper helper) {
		TideVentBlockEntity vent = basin(helper);
		ServerLevel level = helper.getLevel();
		vent.update(level, MID_ENDURE); // first update after a load: snaps
		helper.assertValueEqual(filledLayers(helper, vent.basin()), 3, "full in Endure");
		for (int step = 1; step <= 3; step++) {
			vent.update(level, MID_THRIVE);
			helper.assertValueEqual(filledLayers(helper, vent.basin()), 3 - step, "one layer drains per step");
		}
		vent.update(level, MID_THRIVE);
		helper.assertValueEqual(filledLayers(helper, vent.basin()), 0, "empty in Thrive, and it stays so");
		helper.succeed();
	}

	@GameTest(dimension = SIFT, structure = BIG)
	public void flowMovesOneLayerPerStep(GameTestHelper helper) {
		TideVentBlockEntity vent = basin(helper);
		ServerLevel level = helper.getLevel();
		vent.update(level, MID_THRIVE);
		helper.assertValueEqual(filledLayers(helper, vent.basin()), 0, "low tide");
		long lateRising = Tide.ENDURE.startTick() - 100;
		for (int step = 1; step <= 3; step++) {
			vent.update(level, lateRising);
			helper.assertValueEqual(filledLayers(helper, vent.basin()), step, "one layer per step");
		}
		helper.succeed();
	}

	@GameTest(dimension = SIFT, structure = BIG)
	public void aReloadedVentCatchesUpAtOnce(GameTestHelper helper) {
		TideVentBlockEntity vent = basin(helper);
		ServerLevel level = helper.getLevel();
		vent.update(level, MID_THRIVE);
		// A reload makes a fresh block entity: replace the vent block the same way.
		BlockPos pos = helper.absolutePos(VENT);
		var state = level.getBlockState(pos);
		level.setBlockAndUpdate(pos, Blocks.AIR.defaultBlockState());
		level.setBlockAndUpdate(pos, state);
		TideVentBlockEntity fresh = (TideVentBlockEntity) level.getBlockEntity(pos);
		int changed = fresh.update(level, MID_ENDURE);
		helper.assertValueEqual(filledLayers(helper, fresh.basin()), 3, "caught up in one update");
		helper.assertTrue(changed < 800, "catching up stays under the 800-block budget: " + changed);
		helper.succeed();
	}

	@GameTest(dimension = SIFT, structure = BIG)
	public void aBasinNeverSpillsAndKeepsPlayerBlocks(GameTestHelper helper) {
		TideVentBlockEntity vent = basin(helper);
		ServerLevel level = helper.getLevel();
		BlockPos wall = vent.basin().layer(0).getFirst();
		level.setBlockAndUpdate(wall, Blocks.COBBLESTONE.defaultBlockState());
		vent.update(level, MID_ENDURE);
		helper.assertTrue(level.getBlockState(wall).is(Blocks.COBBLESTONE), "a player's block stays");
		// Every top-layer cell's neighbours outside the basin are the basin's own walls, not open air.
		TideBasin basin = vent.basin();
		for (BlockPos p : basin.layer(TideBasin.MAX_LAYERS - 1)) {
			for (var dir : net.minecraft.core.Direction.Plane.HORIZONTAL) {
				BlockPos n = p.relative(dir);
				int dx = n.getX() - basin.vent().getX();
				int dz = n.getZ() - basin.vent().getZ();
				if (!basin.inFootprint(dx, dz)) {
					helper.assertFalse(level.getBlockState(n).isAir() || level.getBlockState(n).is(ModBlocks.ICHOR), "the wall holds at " + n);
				}
			}
		}
		helper.assertTrue(basin.layer(TideBasin.MAX_LAYERS - 1).getFirst().getY() < basin.vent().getY() + TideBasin.DEPTH, "top layer below the rim");
		helper.succeed();
	}

	/** The vent's own ticker runs: a basin flooded by hand moves toward the clock's Tide. */
	@GameTest(dimension = SIFT, structure = BIG, maxTicks = 100)
	public void theVentTicksOnItsOwn(GameTestHelper helper) {
		TideVentBlockEntity vent = basin(helper);
		ServerLevel level = helper.getLevel();
		long flooded = MID_ENDURE;
		vent.update(level, flooded);
		helper.succeedWhen(() -> {
			int target = TideBasin.targetLayers(Tide.clockTicks(level));
			helper.assertTrue(target == TideBasin.MAX_LAYERS || vent.layers() < TideBasin.MAX_LAYERS,
					"the vent stepped toward the clock's Tide on its own (target " + target + ", layers " + vent.layers() + ")");
		});
	}

	/** Every step in a basin is at most one block, so it can be walked or jumped out of, full or empty. */
	@GameTest(dimension = SIFT)
	public void everyBasinStepIsOneBlock(GameTestHelper helper) {
		for (int inner = 2; inner <= 3; inner++) {
			TideBasin basin = new TideBasin(BlockPos.ZERO, inner);
			int h = basin.half();
			for (int dx = -h; dx <= h; dx++) {
				for (int dz = -h; dz <= h; dz++) {
					if (!basin.inFootprint(dx, dz)) {
						continue;
					}
					for (int[] n : new int[][] {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
						int nx = dx + n[0];
						int nz = dz + n[1];
						// Outside the footprint is the rim: the ground, DEPTH above the pool floor.
						int there = basin.inFootprint(nx, nz) ? basin.floorY(nx, nz) : TideBasin.DEPTH;
						helper.assertTrue(Math.abs(there - basin.floorY(dx, dz)) <= 1,
								"step from (" + dx + "," + dz + ") to (" + nx + "," + nz + ") in inner " + inner);
					}
				}
			}
		}
		helper.succeed();
	}

	@GameTest(dimension = SIFT, structure = BIG)
	public void aPlacedVentIsInert(GameTestHelper helper) {
		helper.setBlock(VENT.below(), ModBlocks.HYMNSTONE);
		helper.setBlock(VENT, ModBlocks.TIDE_VENT);
		helper.assertValueEqual(helper.getLevel().getBlockState(helper.absolutePos(VENT)).getValue(TideVentBlock.BASIN), 0, "placed vents carry no basin");
		TideVentBlockEntity vent = (TideVentBlockEntity) helper.getLevel().getBlockEntity(helper.absolutePos(VENT));
		helper.assertValueEqual(vent.update(helper.getLevel(), MID_ENDURE), 0, "and never flood anything");
		helper.succeed();
	}

	/** Worldgen: basins sit centred in their chunks, ichor pools exist, and nothing crosses a chunk edge. */
	@GameTest(dimension = SIFT, maxTicks = 400)
	public void meadowWorldgenHasBasinsAndPools(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		int vents = 0;
		int surfaceIchor = 0;
		int deepIchor = 0;
		int blubs = 0;
		for (int[] centre : SiftSamples.PATCHES) {
			for (int dx = -SiftSamples.PATCH; dx <= SiftSamples.PATCH; dx++) {
				for (int dz = -SiftSamples.PATCH; dz <= SiftSamples.PATCH; dz++) {
					var chunk = level.getChunk(centre[0] + dx, centre[1] + dz);
					for (int x = 0; x < 16; x++) {
						for (int z = 0; z < 16; z++) {
							int top = chunk.getHeight(Heightmap.Types.WORLD_SURFACE, x, z);
							// Whole columns: rivers and lakes sit near the top, underground pools anywhere from y 8 to 90.
							for (int y = top; y >= level.getMinY(); y--) {
								var state = chunk.getBlockState(new BlockPos(x, y, z));
								if (state.is(ModBlocks.TIDE_VENT)) {
									vents++;
									helper.assertTrue(Math.abs(x - 8) <= 1 && Math.abs(z - 8) <= 1, "a vent sits within a block of the middle of its chunk");
									helper.assertTrue(state.getValue(TideVentBlock.BASIN) > 0, "generated vents are live");
								} else if (state.is(ModBlocks.ICHOR)) {
									if (y > top - 16) {
										surfaceIchor++;
									} else {
										deepIchor++;
									}
								}
							}
						}
					}
				}
			}
			int r = SiftSamples.PATCH;
			var area = new net.minecraft.world.phys.AABB((centre[0] - r) << 4, level.getMinY(), (centre[1] - r) << 4, (centre[0] + r + 1) << 4, level.getMaxY(), (centre[1] + r + 1) << 4);
			blubs += level.getEntitiesOfClass(thesift.entity.blub.Blub.class, area).size();
		}
		// Blubs from chunk generation (about one group per 30 chunks): logged, not asserted, as a sample
		// of 100 chunks can hold none.
		TheSift.LOGGER.info("Worldgen sample, 100 Meadow chunks: {} vents, {} surface ichor, {} deep ichor, {} blubs", vents, surfaceIchor, deepIchor, blubs);
		helper.assertTrue(vents > 0, "tide basins in 100 Meadow chunks: " + vents);
		helper.assertTrue(surfaceIchor + deepIchor > 0, "ichor in 100 Meadow chunks: " + surfaceIchor + " near the surface, " + deepIchor + " deeper");
		helper.succeed();
	}
}
