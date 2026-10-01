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
import thesift.client.fog.IchorFogEnvironment;
import thesift.block.entity.TideVentBlockEntity;
import thesift.registry.ModBlocks;
import thesift.entity.blub.Blub;
import thesift.world.SiftAdvancements;
import thesift.world.SiftKeys;
import thesift.world.Tide;
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

	/** The "game mode updated" lines would cover the bottom of the shot. */
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
		boolean inIchor = context.computeOnClient(client -> IchorFogEnvironment.eyesInIchor(client.player));
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
							SiftLinks.get(server).addCharge(f, Offering.PRICE);
							if (!FrameMusic.open(level, f)) {
								throw new AssertionError("music could not open a natural frame: " + blocking);
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
		context.waitTicks(40);
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
