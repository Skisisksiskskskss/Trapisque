package thesift.test;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.gametest.framework.GameTestHelper;

/** The Phase 3 smoke test: the mod is loaded on a real server and the test framework runs our tests. */
public final class SmokeTest {
	@GameTest
	public void modIsLoaded(GameTestHelper helper) {
		helper.assertTrue(FabricLoader.getInstance().isModLoaded("thesift"), "thesift is not loaded");
		helper.succeed();
	}
}
