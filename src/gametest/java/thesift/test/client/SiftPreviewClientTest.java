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

import thesift.TheSift;
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
