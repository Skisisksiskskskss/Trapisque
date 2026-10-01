package thesift.test.client;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestSingleplayerContext;

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
