package thesift.test.client;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestSingleplayerContext;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.HolderSet;
import net.minecraft.core.registries.Registries;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.levelgen.structure.BuiltinStructures;
import net.minecraft.world.phys.Vec3;

import java.util.List;

import net.minecraft.world.level.levelgen.Heightmap;

import thesift.TheSift;
import thesift.block.MusicNearby;
import thesift.block.entity.TideVentBlockEntity;
import thesift.registry.ModBlocks;
import thesift.registry.ModTags;
import thesift.entity.blub.Blub;
import thesift.world.SiftAdvancements;
import thesift.world.SiftKeys;
import thesift.world.Tide;
import thesift.entry.FrameCues;
import thesift.entry.FrameMusic;
import thesift.entry.FrameShapes;
import thesift.entry.Offering;
import thesift.entry.SiftFrame;
import thesift.entry.SiftGates;
import thesift.entry.SiftLinks;

/**
 * Client GameTest (dev only): screenshots of the Sift in each Tide for review (WP-040/042 DoD).
 * Run under Xvfb: tools/dev/client-previews.sh. Screenshots land in build/run/clientGameTest/screenshots.
 */
public final class SiftPreviewClientTest implements FabricClientGameTest {
	@Override
	public void runTest(ClientGameTestContext context) {
		// For look development (SIFT_LOOK_ONLY=1 tools/dev/client-previews.sh): only the landscape shots.
		if ("1".equals(System.getenv("SIFT_LOOK_ONLY"))) {
			try (TestSingleplayerContext world = context.worldBuilder().create()) {
				world.getServer().runCommand("gamerule advance_time false");
				world.getServer().runCommand("gamemode spectator @a");
				lookShots(context, world);
			}
			return;
		}
		try (TestSingleplayerContext world = context.worldBuilder().create()) {
			world.getServer().runCommand("gamerule advance_time false");
			world.getServer().runCommand("gamemode spectator @a");
			world.getServer().runCommand("execute in thesift:the_sift run tp @a 8 112 8 -35 18");
			world.getConnection().waitForChunksRender();
			context.waitTicks(40);
			shoot(context, world, "thesift:thrive", "sift_thrive");
			shoot(context, world, "thesift:flow_rising", "sift_flow");
			shoot(context, world, "thesift:endure", "sift_endure");
			world.getServer().runCommand("execute in thesift:the_sift run tp @a 8 90 8 -35 30");
			world.getConnection().waitForChunksRender();
			shoot(context, world, "thesift:thrive", "sift_thrive_close");
			lookShots(context, world);
			basinShots(context, world);
			musicShot(context, world);
			ichorFogShot(context, world);
			blubShot(context, world);
			// WP-052: the Tide changed under the player (by command, as above) at least once.
			assertAdvancement(world, SiftAdvancements.TIDE_TURNS, "The Tide Turns");
		}
		// The consistent test world is flat without structures; the entry needs a real Ancient City.
		try (TestSingleplayerContext world = context.worldBuilder().setUseConsistentSettings(false).adjustSettings(s -> {
			s.setSeed("thesift-preview");
			s.setGenerateStructures(true);
		}).create()) {
			world.getServer().runCommand("gamerule advance_time false");
			world.getServer().runCommand("gamemode spectator @a");
			entryShots(context, world);
			// WP-052: the camera stood in a natural Ancient City, then went into the Sift.
			assertAdvancement(world, SiftAdvancements.ROOT, "The Sift");
			assertAdvancement(world, SiftAdvancements.ENTER, "Where Souls Drift");
			chunkGenerationCost(world);
		}
	}

	/**
	 * WP-042's budget: generating fresh Sift chunks against fresh Overworld chunks (default world
	 * settings, the same machine and run). 49 chunks each, far from anything loaded, Sift first and
	 * then the Overworld, then the other way round; logged.
	 */
	private static void chunkGenerationCost(TestSingleplayerContext world) {
		long[] nanos = world.getServer().computeOnServer(server -> {
			long[] t = new long[2];
			int[][] origins = {{3000, 3000}, {-3000, 3000}};
			for (int run = 0; run < 2; run++) {
				for (int side = 0; side < 2; side++) {
					boolean sift = (side == 0) == (run == 0);
					ServerLevel level = sift ? server.getLevel(SiftKeys.LEVEL) : server.overworld();
					int ox = origins[run][0] + (sift ? 0 : 500);
					int oz = origins[run][1];
					long t0 = System.nanoTime();
					for (int dx = 0; dx < 7; dx++) {
						for (int dz = 0; dz < 7; dz++) {
							level.getChunk(ox + dx, oz + dz);
						}
					}
					t[sift ? 0 : 1] += System.nanoTime() - t0;
				}
			}
			return t;
		});
		TheSift.LOGGER.info("Chunk generation, 98 fresh chunks each: the Sift {} ms, the Overworld {} ms, ratio {}",
				nanos[0] / 1_000_000, nanos[1] / 1_000_000, String.format(java.util.Locale.ROOT, "%.2f", (double) nanos[0] / Math.max(1, nanos[1])));
	}

	private static void assertAdvancement(TestSingleplayerContext world, net.minecraft.resources.Identifier id, String name) {
		boolean has = world.getServer().computeOnServer(server -> SiftAdvancements.has(server.getPlayerList().getPlayers().get(0), id));
		if (!has) {
			throw new AssertionError("the player should have earned \"" + name + "\"");
		}
	}

	/**
	 * WP-049: blubs on the Meadow in Thrive (one walking, a tower of three, one bathing in a one-deep
	 * ichor pool), then the same blubs in Endure, one curled with its belly glowing.
	 */
	private static void blubShot(ClientGameTestContext context, TestSingleplayerContext world) {
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:thrive");
		// A small flat stage of healthy sculk at the area's highest point, so nothing hides the blubs.
		BlockPos ground = world.getServer().computeOnServer(server -> {
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			int top = 0;
			for (int dx = -5; dx <= 5; dx++) {
				for (int dz = -6; dz <= 5; dz++) {
					top = Math.max(top, sift.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, 90 + dx, 90 + dz));
				}
			}
			return new BlockPos(90, top, 90);
		});
		int x = ground.getX();
		int y = ground.getY();
		int z = ground.getZ();
		run(world, "fill %d %d %d %d %d %d thesift:healthy_sculk", x - 5, y - 2, z - 6, x + 5, y - 1, z + 5);
		run(world, "fill %d %d %d %d %d %d air", x - 5, y, z - 6, x + 5, y + 6, z + 5);
		run(world, "setblock %d %d %d thesift:ichor", x + 2, y - 1, z + 1); // a one-deep bath
		String facing = "{NoAI:1b,Rotation:[%df,0f]}";
		summon(world, new BlockPos(x - 2, y, z + 1), String.format(java.util.Locale.ROOT, facing, 200));
		summon(world, new BlockPos(x, y, z + 2), "{NoAI:1b,Rotation:[180f,0f],Passengers:[{id:\"thesift:blub\",NoAI:1b,Rotation:[170f,0f],"
				+ "Passengers:[{id:\"thesift:blub\",NoAI:1b,Rotation:[190f,0f]}]}]}");
		summon(world, new BlockPos(x + 2, y - 1, z + 1), String.format(java.util.Locale.ROOT, facing, 150));
		world.getServer().runCommand("gamemode spectator @a");
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %.1f %.1f %.1f 0 22",
				x + 0.5, y + 1.6, z - 3.5));
		world.getConnection().waitForChunksRender();
		context.waitTicks(20);
		clearChat(context);
		context.takeScreenshot("wp049_blubs");
		// The walkthrough's befriending: two notes played by the player's own hand next to the lone blub.
		world.getServer().runCommand("gamemode creative @a");
		run(world, "setblock %d %d %d minecraft:note_block", x - 3, y, z - 1);
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %.1f %d %.1f facing %.1f %d %.1f",
				x - 1.5, y, z - 1.5, x - 1.5, y, z + 1.5));
		context.waitTicks(5);
		boolean befriended = world.getServer().computeOnServer(server -> {
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			var player = server.getPlayerList().getPlayers().getFirst();
			BlockPos note = new BlockPos(x - 3, y, z - 1);
			sift.gameEvent(player, net.minecraft.world.level.gameevent.GameEvent.NOTE_BLOCK_PLAY, note);
			sift.gameEvent(player, net.minecraft.world.level.gameevent.GameEvent.NOTE_BLOCK_PLAY, note);
			return sift.getEntitiesOfClass(Blub.class, new net.minecraft.world.phys.AABB(new BlockPos(x - 2, y, z + 1)).inflate(1),
					b -> b.isOwnedBy(player)).size() == 1;
		});
		if (!befriended) {
			throw new AssertionError("two hand-played notes should befriend the lone blub");
		}
		context.waitTicks(4);
		clearChat(context);
		context.takeScreenshot("wp051_befriended");
		world.getServer().runCommand("gamemode spectator @a");
		// Beside vanilla neighbours under Flow's light, close up and from 10 blocks.
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:flow_rising");
		String still = "{NoAI:1b,Rotation:[180f,0f]}";
		run(world, "summon minecraft:rabbit %.1f %d %.1f %s", x + 3.5, y, z + 4.5, still);
		run(world, "summon minecraft:allay %.1f %d %.1f %s", x + 1.5, y, z + 4.5, still);
		run(world, "summon minecraft:axolotl %.1f %d %.1f %s", x - 0.5, y, z + 4.5, still);
		summon(world, new BlockPos(x - 3, y, z + 4), still);
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %.1f %.1f %.1f 0 17",
				x + 0.5, y + 0.2, z - 0.5));
		context.waitTicks(20);
		clearChat(context);
		context.takeScreenshot("wp049_lineup_flow");
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %.1f %.1f %.1f 0 8",
				x + 0.5, y + 2.5, z - 6.0));
		context.waitTicks(10);
		clearChat(context);
		context.takeScreenshot("wp049_10_blocks");
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %.1f %.1f %.1f 0 22",
				x + 0.5, y + 1.6, z - 3.5));
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:endure");
		world.getServer().runOnServer(server -> {
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			sift.getEntitiesOfClass(Blub.class, new net.minecraft.world.phys.AABB(ground).inflate(4), b -> !b.isVehicle() && !b.isPassenger()
					&& !sift.getFluidState(b.blockPosition()).is(thesift.registry.ModTags.ICHOR)).forEach(b -> b.setCurled(true));
		});
		context.waitTicks(30); // the glow fades in over a second
		clearChat(context);
		context.takeScreenshot("wp049_blubs_endure");
	}

	/** In front of the frame, not off its ends: mostly across its plane, within its width. */
	private static boolean inFront(SiftFrame frame, Vec3 p) {
		Vec3 d = p.subtract(frame.center());
		double across = frame.axis() == Direction.Axis.X ? Math.abs(d.z) : Math.abs(d.x);
		double along = frame.axis() == Direction.Axis.X ? Math.abs(d.x) : Math.abs(d.z);
		return across >= 3.5 && along <= 8;
	}

	/** True if nothing but the frame itself stands between {@code eye} and the frame's centre. */
	private static boolean seesFrame(ServerLevel level, Vec3 eye, SiftFrame frame) {
		var hit = level.clip(new net.minecraft.world.level.ClipContext(eye, frame.center(), net.minecraft.world.level.ClipContext.Block.COLLIDER,
				net.minecraft.world.level.ClipContext.Fluid.NONE, net.minecraft.world.phys.shapes.CollisionContext.empty()));
		return hit.getType() == net.minecraft.world.phys.HitResult.Type.MISS || frame.box().inflate(0.5).contains(hit.getLocation());
	}

	/**
	 * The owner's playtest rework: the land as a player first meets it, to compare with the teasers.
	 * The server finds a spire, a shore, a stretch of meadow and a high viewpoint in fresh land.
	 */
	private static void lookShots(ClientGameTestContext context, TestSingleplayerContext world) {
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:thrive");
		double[][] views = world.getServer().computeOnServer(server -> lookViews(server.getLevel(SiftKeys.LEVEL)));
		String[] names = {"look_spire", "look_shore", "look_meadow", "look_overview", "look_flats", "look_wood", "look_ichor"};
		for (int i = 0; i < views.length; i++) {
			double[] v = views[i];
			if (v == null) {
				TheSift.LOGGER.warn("No spot found for {}", names[i]);
				continue;
			}
			run(world, "tp @a %.1f %.1f %.1f %.1f %.1f", v[0], v[1], v[2], v[3], v[4]);
			world.getConnection().waitForChunksRender();
			clearChat(context);
			context.waitTicks(40);
			context.takeScreenshot(names[i]);
			if ("look_ichor".equals(names[i])) {
				// Owner playtest 5: the film colours move. The same view three seconds on.
				context.waitTicks(60);
				context.takeScreenshot("look_ichor_later");
			}
		}
		double[] meadow = views[2];
		if (meadow != null) {
			// The first look's framing: low in the grass, a blub walking toward the camera.
			double yaw = Math.toRadians(meadow[3]);
			double fx = -Math.sin(yaw);
			double fz = Math.cos(yaw);
			world.getServer().runCommand(String.format(java.util.Locale.ROOT,
					"execute in thesift:the_sift run summon thesift:blub %.1f %.1f %.1f {NoAI:1b,Rotation:[%.1ff,0f]}",
					meadow[0] + fx * 3.0, meadow[1] - 0.4, meadow[2] + fz * 3.0, meadow[3] + 180.0));
			run(world, "tp @a %.1f %.1f %.1f %.1f %.1f", meadow[0], meadow[1] - 0.1, meadow[2], meadow[3], 8.0);
			clearChat(context);
			context.waitTicks(40);
			context.takeScreenshot("look_blub");
			// WP-067: a Nester (and an enduring one) in the same framing, a few blocks off, on the ground there.
			world.getServer().runCommand(String.format(java.util.Locale.ROOT,
					"execute in thesift:the_sift positioned %.1f 0 %.1f positioned over motion_blocking_no_leaves run summon thesift:nester ~ ~ ~ {NoAI:1b,Rotation:[%.1ff,0f]}",
					meadow[0] + fx * 5.0 - fz * 1.5, meadow[2] + fz * 5.0 + fx * 1.5, meadow[3] + 150.0));
			world.getServer().runCommand(String.format(java.util.Locale.ROOT,
					"execute in thesift:the_sift positioned %.1f 0 %.1f positioned over motion_blocking_no_leaves run summon thesift:nester ~ ~ ~ {NoAI:1b,Enduring:1b,Rotation:[%.1ff,0f]}",
					meadow[0] + fx * 6.0 + fz * 2.5, meadow[2] + fz * 6.0 - fx * 2.5, meadow[3] + 210.0));
			clearChat(context);
			context.waitTicks(40);
			context.takeScreenshot("look_nester");
			run(world, "tp @a %.1f %.1f %.1f %.1f %.1f", meadow[0], meadow[1], meadow[2], meadow[3], meadow[4]);
			world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:endure");
			clearChat(context);
			context.waitTicks(40);
			context.takeScreenshot("look_meadow_endure");
			world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:thrive");
		}
	}

	/**
	 * Camera views {x, y, z, yaw, pitch} for a spire, a pond's shore, a meadow, an overview, the Ichor
	 * Flats, a wood and a close look at ichor (null if none found).
	 */
	private static double[][] lookViews(ServerLevel level) {
		int cx0 = 40;
		int cz0 = 40;
		load(level, cx0, cz0, 8);
		int x0 = cx0 << 4;
		int z0 = cz0 << 4;
		double[] spire = null;
		double[] shore = null;
		double[] meadow = null;
		double[] wood = null;
		double[] close = null;
		int bestLeaves = 0;
		for (int dx = -100; dx <= 100; dx += 3) {
			for (int dz = -100; dz <= 100; dz += 3) {
				int x = x0 + dx;
				int z = z0 + dz;
				int h = level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x, z);
				var top = level.getBlockState(new BlockPos(x, h - 1, z));
				if (spire == null && h - around(level, x, z, 7) >= 14 && (top.is(ModBlocks.HEALTHY_SCULK) || top.is(ModBlocks.HYMNSTONE))) {
					double gx = x + 26;
					double gz = z + 12;
					// Above any canopy, in open air.
					int gh = level.getHeight(Heightmap.Types.MOTION_BLOCKING, (int) gx, (int) gz);
					if (level.getBlockState(new BlockPos((int) gx, gh + 1, (int) gz)).isAir()) {
						spire = aim(gx, gh + 2.0, gz, x, h - 6, z);
					}
				}
				if (top.is(ModBlocks.ICHOR)) {
					if (shore == null) {
						int lx = x + 12;
						int lh = level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, lx, z);
						if (level.getBlockState(new BlockPos(lx, lh - 1, z)).is(ModBlocks.HEALTHY_SCULK)) {
							shore = aim(lx, lh + 2.5, z, x - 4, h - 1, z);
						}
					}
					if (close == null) {
						close = new double[] {x + 0.5, h + 2.2, z - 1.5, 0.0, 55.0};
					}
				}
				if (meadow == null && top.is(ModBlocks.HEALTHY_SCULK) && Math.abs(h - around(level, x, z, 12)) <= 2) {
					meadow = new double[] {x + 0.5, h + 0.4, z + 0.5, 225.0, -4.0};
				}
				int leaves = leavesAround(level, x, z);
				if (leaves > bestLeaves) {
					bestLeaves = leaves;
					wood = aim(x - 18, h + 4.0, z - 18, x, h + 3, z);
				}
			}
		}
		int high = level.getHeight(Heightmap.Types.MOTION_BLOCKING, x0, z0) + 45;
		double[] overview = new double[] {x0, high, z0, 135.0, 32.0};
		return new double[][] {spire, shore, meadow, overview, flatsView(level, x0, z0), wood, close};
	}

	/** A view over the nearest Ichor Flats: from 14 blocks off and 7 up, at a pool. */
	private static double[] flatsView(ServerLevel level, int x0, int z0) {
		var found = level.findClosestBiome3d(biome -> biome.is(SiftKeys.ICHOR_FLATS), new BlockPos(x0, 80, z0), 3000, 32, 64);
		if (found == null) {
			return null;
		}
		BlockPos at = found.getFirst();
		load(level, at.getX() >> 4, at.getZ() >> 4, 4);
		for (int r = 0; r <= 48; r += 2) {
			for (int dx = -r; dx <= r; dx += 2) {
				for (int dz : new int[] {-r, r}) {
					int x = at.getX() + dx;
					int z = at.getZ() + dz;
					int h = level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x, z);
					if (level.getBlockState(new BlockPos(x, h - 1, z)).is(ModBlocks.ICHOR)) {
						int cx = x + 14;
						int ch = Math.max(h, level.getHeight(Heightmap.Types.MOTION_BLOCKING, cx, z + 6));
						return aim(cx, ch + 7.0, z + 6, x, h - 1, z);
					}
				}
			}
		}
		return null;
	}

	private static void load(ServerLevel level, int cx0, int cz0, int r) {
		for (int cx = cx0 - r; cx <= cx0 + r; cx++) {
			for (int cz = cz0 - r; cz <= cz0 + r; cz++) {
				level.getChunk(cx, cz);
			}
		}
	}

	/** How many columns within 8 blocks are topped by songwood leaves (a wood's density). */
	private static int leavesAround(ServerLevel level, int x, int z) {
		int n = 0;
		for (int dx = -8; dx <= 8; dx += 4) {
			for (int dz = -8; dz <= 8; dz += 4) {
				int h = level.getHeight(Heightmap.Types.MOTION_BLOCKING, x + dx, z + dz);
				n += level.getBlockState(new BlockPos(x + dx, h - 1, z + dz)).is(ModBlocks.SONGWOOD_LEAVES) ? 1 : 0;
			}
		}
		return n;
	}

	/** The mean ground height on a ring of radius r around a column. */
	private static int around(ServerLevel level, int x, int z, int r) {
		int sum = 0;
		for (int[] d : new int[][] {{r, 0}, {-r, 0}, {0, r}, {0, -r}}) {
			sum += level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x + d[0], z + d[1]);
		}
		return sum / 4;
	}

	/** A camera at (x, y, z) looking at (tx, ty, tz): {x, y, z, yaw, pitch}. */
	private static double[] aim(double x, double y, double z, double tx, double ty, double tz) {
		double dx = tx - x;
		double dy = ty - y;
		double dz = tz - z;
		double yaw = Math.toDegrees(Math.atan2(-dx, dz));
		double pitch = -Math.toDegrees(Math.atan2(dy, Math.sqrt(dx * dx + dz * dz)));
		return new double[] {x, y, z, yaw, pitch};
	}

	private static void clearChat(ClientGameTestContext context) {
		context.runOnClient(client -> client.gui.hud.getChat().clearMessages(false));
	}

	private static void run(TestSingleplayerContext world, String command, Object... args) {
		world.getServer().runCommand("execute in thesift:the_sift run " + String.format(java.util.Locale.ROOT, command, args));
	}

	private static void summon(TestSingleplayerContext world, BlockPos at, String nbt) {
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run summon thesift:blub %.1f %d %.1f %s",
				at.getX() + 0.5, at.getY(), at.getZ() + 0.5, nbt));
	}

	/** WP-044: the view from inside ichor (creative: spectators see through liquids, as with lava). */
	private static void ichorFogShot(ClientGameTestContext context, TestSingleplayerContext world) {
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:thrive");
		BlockPos ground = world.getServer().computeOnServer(server -> {
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			int y = sift.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, 60, 60);
			return new BlockPos(60, y, 60);
		});
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run fill %d %d %d %d %d %d thesift:ichor",
				ground.getX() - 3, ground.getY(), ground.getZ() - 3, ground.getX() + 3, ground.getY() + 3, ground.getZ() + 3));
		world.getServer().runCommand("gamemode creative @a");
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %d %d %d 30 0",
				ground.getX(), ground.getY() + 1, ground.getZ()));
		world.getConnection().waitForChunksRender();
		context.waitTicks(20);
		boolean inIchor = context.computeOnClient(client -> client.player.level().getFluidState(BlockPos.containing(client.player.getEyePosition())).is(ModTags.ICHOR));
		if (!inIchor) {
			throw new AssertionError("the camera should be inside ichor");
		}
		context.takeScreenshot("wp044_inside_ichor");
		world.getServer().runCommand("gamemode spectator @a");
	}

	/** WP-042 §3.2: a note block's sound makes the healthy sculk around it shed glowing petals. */
	private static void musicShot(ClientGameTestContext context, TestSingleplayerContext world) {
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set thesift:endure");
		BlockPos ground = world.getServer().computeOnServer(server -> {
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			int y = sift.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, 40, 40) - 1;
			return new BlockPos(40, y, 40);
		});
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %d %d %d 0 40",
				ground.getX(), ground.getY() + 4, ground.getZ() - 5));
		world.getConnection().waitForChunksRender();
		String play = String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run playsound minecraft:block.note_block.harp record @a %d %d %d",
				ground.getX(), ground.getY() + 1, ground.getZ());
		for (int i = 0; i < 6; i++) {
			world.getServer().runCommand(play);
			context.waitTicks(10);
		}
		boolean heard = context.computeOnClient(client -> MusicNearby.near(ground));
		if (!heard) {
			throw new AssertionError("the client did not register the note block's music near " + ground);
		}
		context.takeScreenshot("wp042_music_reaction");
	}

	/** WP-045: a generated tide basin at low tide and at high tide. */
	private static void basinShots(ClientGameTestContext context, TestSingleplayerContext world) {
		BlockPos vent = world.getServer().computeOnServer(server -> {
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			for (int r = 0; r <= 12; r++) {
				for (int cx = -r; cx <= r; cx++) {
					for (int cz = -r; cz <= r; cz++) {
						if (Math.max(Math.abs(cx), Math.abs(cz)) != r) {
							continue;
						}
						var chunk = sift.getChunk(cx, cz);
						int top = chunk.getHeight(Heightmap.Types.WORLD_SURFACE, 8, 8);
						for (int y = top; y > top - 12; y--) {
							BlockPos p = new BlockPos(cx * 16 + 8, y, cz * 16 + 8);
							if (sift.getBlockState(p).is(ModBlocks.TIDE_VENT)) {
								return p;
							}
						}
					}
				}
			}
			throw new AssertionError("no tide basin within 12 chunks of the Sift's origin");
		});
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %d %d %d 0 75",
				vent.getX(), vent.getY() + 22, vent.getZ() - 6));
		world.getConnection().waitForChunksRender();
		for (String[] shot : new String[][] {{"thesift:thrive", "wp045_basin_thrive"}, {"thesift:endure", "wp045_basin_endure"}}) {
			world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set " + shot[0]);
			world.getServer().runOnServer(server -> {
				ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
				TideVentBlockEntity be = (TideVentBlockEntity) sift.getBlockEntity(vent);
				for (int i = 0; i < 4; i++) {
					be.update(sift, Tide.clockTicks(sift));
				}
			});
			context.waitTicks(30);
			context.takeScreenshot(shot[1]);
		}
	}

	/**
	 * WP-046/047 on a naturally generated Ancient City (the server GameTest world has none): the
	 * frame is found, music opens it, and the first crossing builds the gate. Screenshots of both.
	 */
	private static void entryShots(ClientGameTestContext context, TestSingleplayerContext world) {
		SiftFrame frame = world.getServer().computeOnServer(server -> {
			ServerLevel level = server.overworld();
			var city = level.registryAccess().lookupOrThrow(Registries.STRUCTURE).getOrThrow(BuiltinStructures.ANCIENT_CITY);
			var nearest = level.getChunkSource().getGenerator().findNearestMapStructure(level, HolderSet.direct(city), BlockPos.ZERO, 100, false);
			if (nearest == null) {
				throw new AssertionError("no Ancient City within 100 chunks of spawn");
			}
			BlockPos start = nearest.getFirst();
			for (int dx = -48; dx <= 48; dx++) {
				for (int dz = -48; dz <= 48; dz++) {
					BlockPos p = new BlockPos(start.getX() + dx, -28, start.getZ() + dz);
					if (level.getBlockState(p).is(Blocks.REINFORCED_DEEPSLATE)) {
						SiftFrame f = FrameShapes.find(level, p, Blocks.REINFORCED_DEEPSLATE, SiftFrame.CITY_WIDTH, SiftFrame.CITY_HEIGHT).orElse(null);
						if (f != null) {
							List<String> blocking = f.opening().stream().filter(o -> !FrameMusic.isClearable(level.getBlockState(o)))
									.map(o -> level.getBlockState(o).getBlock() + "@" + o).toList();
							TheSift.LOGGER.info("[WP-046] natural city frame {} {}; blocking cells: {}", f.origin(), f.axis(), blocking);
							// FrameCues finds the same frame from the city's structure data (its chunks loaded).
							for (int cx = (start.getX() >> 4) - 6; cx <= (start.getX() >> 4) + 6; cx++) {
								for (int cz = (start.getZ() >> 4) - 6; cz <= (start.getZ() >> 4) + 6; cz++) {
									level.getChunk(cx, cz);
								}
							}
							long t0 = System.nanoTime();
							SiftFrame discovered = FrameCues.discover(level, BlockPos.containing(f.center()));
							TheSift.LOGGER.info("[WP-046] FrameCues found {} from the structure in {} ms", discovered, (System.nanoTime() - t0) / 1_000_000);
							if (!f.equals(discovered)) {
								throw new AssertionError("FrameCues should find the city's frame " + f + ", found " + discovered);
							}
							return f;
						}
					}
				}
			}
			throw new AssertionError("no frame found in the city at " + start);
		});
		world.getServer().runCommand("effect give @a minecraft:night_vision infinite 0 true");
		Vec3 c = frame.center();
		boolean alongX = frame.axis() == Direction.Axis.X;
		// Stage 2, notice: a survival player with experience 6 blocks from the dormant frame, empty-handed.
		world.getServer().runCommand("gamemode survival @a");
		world.getServer().runCommand("xp add @a 5 levels");
		// A real standing spot (floor, two open cells) in front of the frame and within 7.5 blocks of it,
		// as far as possible for the view; the camera faces the frame's centre.
		BlockPos stand = world.getServer().computeOnServer(server -> {
			ServerLevel level = server.overworld();
			BlockPos best = null;
			double bestDist = 0;
			BlockPos centre = BlockPos.containing(c);
			for (BlockPos p : BlockPos.betweenClosed(centre.offset(-12, -12, -12), centre.offset(12, 2, 12))) {
				double d = frame.distanceTo(Vec3.atBottomCenterOf(p)); // as FrameCues measures the notice range
				if (d <= 7.5 && d > bestDist && level.getBlockState(p).isAir() && level.getBlockState(p.above()).isAir()
						&& level.getBlockState(p.below()).isSolidRender() && !frame.box().contains(Vec3.atCenterOf(p))
						&& inFront(frame, Vec3.atCenterOf(p)) && seesFrame(level, Vec3.atBottomCenterOf(p).add(0, 1.62, 0), frame)) {
					bestDist = d;
					best = p.immutable();
				}
			}
			return best;
		});
		if (stand == null) {
			throw new AssertionError("no standing spot near the frame");
		}
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in minecraft:overworld run tp @a %.1f %d %.1f facing %.1f %.1f %.1f",
				stand.getX() + 0.5, stand.getY(), stand.getZ() + 0.5, c.x, c.y, c.z));
		world.getConnection().waitForChunksRender();
		context.waitTicks(60);
		clearChat(context);
		context.takeScreenshot("wp046_frame_notice");
		boolean noticed = world.getServer().computeOnServer(server -> {
			var player = server.getPlayerList().getPlayers().getFirst();
			return server.getAdvancements().get(SiftAdvancements.ROOT) != null
					&& player.getAdvancements().getOrStartProgress(server.getAdvancements().get(SiftAdvancements.ROOT)).getCriterion(SiftAdvancements.AWARDED) != null
					&& player.getAdvancements().getOrStartProgress(server.getAdvancements().get(SiftAdvancements.ROOT)).getCriterion(SiftAdvancements.AWARDED).isDone();
		});
		if (!noticed) {
			throw new AssertionError("the frame should have noticed the player (root advancement's 'awarded' criterion)");
		}
		world.getServer().runCommand("gamemode spectator @a");
		world.getServer().runOnServer(server -> {
			SiftLinks.get(server).addCharge(frame, Offering.PRICE);
			if (!FrameMusic.open(server.overworld(), frame)) {
				throw new AssertionError("music could not open a natural frame");
			}
		});
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in minecraft:overworld run tp @a %.1f %.1f %.1f %d 5",
				alongX ? c.x : c.x + 14, c.y - 1, alongX ? c.z + 14 : c.z, alongX ? 180 : 90));
		world.getConnection().waitForChunksRender();
		context.waitTicks(40);
		context.takeScreenshot("wp046_frame_open");

		SiftFrame gate = world.getServer().computeOnServer(server -> {
			ServerLevel level = server.overworld();
			var player = server.getPlayerList().getPlayers().getFirst();
			SiftGates.destination(level, player, frame.at(10, 1));
			return SiftLinks.get(server).frameWithBorder(frame.at(0, 0)).orElseThrow().gate().orElseThrow();
		});
		Vec3 g = gate.center();
		world.getServer().runCommand(String.format(java.util.Locale.ROOT, "execute in thesift:the_sift run tp @a %.1f %.1f %.1f %d 15",
				alongX ? g.x : g.x + 9, g.y + 1, alongX ? g.z + 9 : g.z, alongX ? 180 : 90));
		world.getConnection().waitForChunksRender();
		// A fresh Sift region takes a while to generate and reach the client (the land is vanilla's now).
		context.waitTicks(160);
		world.getConnection().waitForChunksRender();
		context.takeScreenshot("wp047_gate");
	}

	private static void shoot(ClientGameTestContext context, TestSingleplayerContext world, String marker, String name) {
		world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides set " + marker);
		// Flow is a blend: sample it mid-way through rising Flow.
		if (marker.endsWith("flow_rising")) {
			world.getServer().runCommand("execute in thesift:the_sift run time of thesift:tides add 1500");
		}
		context.waitTicks(30);
		context.takeScreenshot(name);
	}
}
