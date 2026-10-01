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
		}
		// The consistent test world is flat without structures; the entry needs a real Ancient City.
		try (TestSingleplayerContext world = context.worldBuilder().setUseConsistentSettings(false).adjustSettings(s -> {
			s.setSeed("thesift-preview");
			s.setGenerateStructures(true);
		}).create()) {
			world.getServer().runCommand("gamerule advance_time false");
			world.getServer().runCommand("gamemode spectator @a");
			entryShots(context, world);
		}
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
