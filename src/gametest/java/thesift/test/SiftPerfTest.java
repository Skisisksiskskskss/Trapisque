package thesift.test;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;

import thesift.TheSift;
import thesift.block.entity.TideVentBlockEntity;
import thesift.registry.ModBlocks;
import thesift.world.Tide;
import thesift.world.TideBasin;

/**
 * Cost measurements for the M1 budgets (WP-044, WP-045). Each measures our own work directly,
 * synchronously on the server thread, so other tests don't interleave. Numbers go to the log and
 * the PLAN; the assertions only guard against gross regressions (machines differ).
 */
public final class SiftPerfTest {
	/**
	 * WP-044: 20 mobs standing in ichor against 20 in lava, each entity ticked by hand in alternating
	 * order after a warm-up. Zombified piglins are fire-immune, so neither group dies mid-run.
	 */
	@GameTest(structure = SiftBasinTest.BIG, maxTicks = 400)
	public void twentyInIchorCostAboutAsMuchAsTwentyInLava(GameTestHelper helper) {
		for (int x = 0; x < 17; x++) {
			for (int z = 0; z < 17; z++) {
				helper.setBlock(new BlockPos(x, 0, z), Blocks.STONE);
				helper.setBlock(new BlockPos(x, 1, z), z < 8 ? ModBlocks.ICHOR.defaultBlockState() : Blocks.LAVA.defaultBlockState());
			}
		}
		List<Entity> inIchor = new ArrayList<>();
		List<Entity> inLava = new ArrayList<>();
		for (int i = 0; i < 20; i++) {
			double x = 1.5 + (i % 5) * 3;
			double z = 1.5 + (i / 5) * 1.5;
			inIchor.add(helper.spawn(EntityTypes.ZOMBIFIED_PIGLIN, new Vec3(x, 1, z)));
			inLava.add(helper.spawn(EntityTypes.ZOMBIFIED_PIGLIN, new Vec3(x, 1, z + 9)));
		}
		long[] cost = new long[2];
		for (int round = 0; round < 400; round++) {
			boolean ichorFirst = round % 2 == 0;
			for (int pass = 0; pass < 2; pass++) {
				boolean ichor = (pass == 0) == ichorFirst;
				long t0 = System.nanoTime();
				for (Entity e : ichor ? inIchor : inLava) {
					e.tick();
				}
				if (round >= 100) {
					cost[ichor ? 0 : 1] += System.nanoTime() - t0;
				}
			}
		}
		double ratio = (double) cost[0] / Math.max(1, cost[1]);
		TheSift.LOGGER.info("Ichor cost, 300 rounds: 20 in ichor {} ms, 20 in lava {} ms, ratio {}",
				cost[0] / 1_000_000, cost[1] / 1_000_000, String.format(Locale.ROOT, "%.2f", ratio));
		inIchor.forEach(Entity::discard);
		inLava.forEach(Entity::discard);
		helper.assertTrue(ratio < 3.0, "20 in ichor cost " + ratio + "x 20 in lava");
		helper.succeed();
	}

	/**
	 * WP-045: 50 loaded basins through a whole rising and falling Flow, each vent updated on its own
	 * schedule (once a second, spread by position) as its block entity ticker does. Reports the
	 * vents' work per server tick: p95 and max. Fluid ticks the fills schedule are not included;
	 * basin ichor can't spread (solid walls, nothing below), so each is a no-op.
	 *
	 * <p>The Flow is run {@link #SWEEPS} times (it ends with every basin empty again) and each tick's
	 * cost is its least over the sweeps. A GC pause or the OS taking the server thread lands on one
	 * sweep's tick (a CI runner once put 36 ms on a single tick that measures 3 to 11 ms locally); the
	 * vents' own work is in every sweep. The raw worst tick is logged too, with whether a GC ran in it.
	 */
	@GameTest(maxTicks = 400)
	public void fiftyBasinsThroughAFlowStayWithinBudget(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockPos origin = helper.absolutePos(BlockPos.ZERO);
		int cx0 = (origin.getX() >> 4) + 40;
		int cz0 = (origin.getZ() >> 4) + 40;
		List<TideVentBlockEntity> vents = new ArrayList<>();
		for (int i = 0; i < 50; i++) {
			BlockPos vent = new BlockPos(((cx0 + i % 10) << 4) + 8, level.getMinY() + 12, ((cz0 + i / 10) << 4) + 8);
			level.getChunk(vent);
			new TideBasin(vent, 3).carve(level);
			vents.add((TideVentBlockEntity) level.getBlockEntity(vent));
		}
		long slots = vents.stream().mapToInt(v -> TideVentBlockEntity.phase(v.getBlockPos())).distinct().count();
		// Plain hashes used 5 slots; 50 well-mixed vents use 18 or so (fewer than 15: 1 in 2000; fewer than 12: 1 in 6 x 10^7).
		helper.assertTrue(slots >= 12, "50 chunk-centred vents spread over most of the 20 slots: " + slots);
		long start = Tide.FLOW_RISING.startTick() - 40;
		vents.forEach(v -> v.update(level, start)); // loaded in Thrive: empty
		int span = (Tide.ENDURE.startTick() - Tide.FLOW_RISING.startTick()) + 80;
		int n = 2 * span;
		long[][] perTick = new long[SWEEPS][n];
		boolean[][] gcInTick = new boolean[SWEEPS][n];
		long gcStart = gcCount();
		int changed = 0;
		for (int sweep = 0; sweep < SWEEPS; sweep++) {
			int i = 0;
			for (long from : new long[] {start, Tide.FLOW_FALLING.startTick() - 40}) {
				for (int t = 0; t < span; t++, i++) {
					long cycleTick = from + t;
					long gc = gcCount();
					long t0 = System.nanoTime();
					for (TideVentBlockEntity vent : vents) {
						if (Math.floorMod(cycleTick + TideVentBlockEntity.phase(vent.getBlockPos()), TideVentBlockEntity.UPDATE_INTERVAL) == 0) {
							changed += vent.update(level, cycleTick);
						}
					}
					perTick[sweep][i] = System.nanoTime() - t0;
					gcInTick[sweep][i] = gcCount() != gc;
				}
			}
		}
		long gcs = gcCount() - gcStart;
		long[] least = new long[n];
		int rawSweep = 0;
		int rawTick = 0;
		for (int i = 0; i < n; i++) {
			least[i] = Long.MAX_VALUE;
			for (int sweep = 0; sweep < SWEEPS; sweep++) {
				least[i] = Math.min(least[i], perTick[sweep][i]);
				if (perTick[sweep][i] > perTick[rawSweep][rawTick]) {
					rawSweep = sweep;
					rawTick = i;
				}
			}
		}
		long[] sorted = least.clone();
		Arrays.sort(sorted);
		double p95 = sorted[(int) (n * 0.95)] / 1e6;
		double max = sorted[n - 1] / 1e6;
		long overOneMs = Arrays.stream(least).filter(t -> t > 1_000_000).count();
		TheSift.LOGGER.info("Basins, 50 through a whole Flow (rising and falling, {} ticks, {} slots, least of {} sweeps): {} blocks changed per sweep, vent work per tick p95 {} ms, max {} ms, {} ticks over 1 ms (the layer changes); raw worst {} ms (sweep {}, tick {}, GC in it: {}; {} GCs in all sweeps)",
				n, slots, SWEEPS, changed / SWEEPS, String.format(Locale.ROOT, "%.3f", p95), String.format(Locale.ROOT, "%.3f", max), overOneMs,
				String.format(Locale.ROOT, "%.3f", perTick[rawSweep][rawTick] / 1e6), rawSweep, rawTick, gcInTick[rawSweep][rawTick] ? "yes" : "no", gcs);
		helper.assertValueEqual(changed, SWEEPS * 50 * 2 * layerCells(), "every basin filled and drained all three layers, every sweep");
		helper.assertTrue(max < 25.0, "the worst tick's vent work (least of " + SWEEPS + " sweeps) stays under half a tick: " + max + " ms");
		helper.succeed();
	}

	private static final int SWEEPS = 3;

	/** Collections so far, all collectors. */
	private static long gcCount() {
		long count = 0;
		for (GarbageCollectorMXBean gc : ManagementFactory.getGarbageCollectorMXBeans()) {
			count += Math.max(0, gc.getCollectionCount());
		}
		return count;
	}

	/** Cells in the three layers of an inner-3 basin. */
	private static int layerCells() {
		TideBasin basin = new TideBasin(BlockPos.ZERO, 3);
		int cells = 0;
		for (int k = 0; k < TideBasin.MAX_LAYERS; k++) {
			cells += basin.layer(k).size();
		}
		return cells;
	}
}
