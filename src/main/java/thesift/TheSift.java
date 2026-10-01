package thesift;

import net.fabricmc.api.ModInitializer;
import net.minecraft.resources.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import thesift.entry.FrameMusic;
import thesift.entry.Offering;
import thesift.registry.ModAttributes;
import thesift.registry.ModBlocks;
import thesift.registry.ModCreativeTab;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;
import thesift.world.EndureRest;
import thesift.world.TideClock;

/**
 * Common (client + dedicated server) entrypoint for The Sift.
 *
 * <p>Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.
 */
public final class TheSift implements ModInitializer {
	public static final String MOD_ID = "thesift";
	public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

	@Override
	public void onInitialize() {
		ModAttributes.init();
		ModFluids.init();
		ModBlocks.init();
		ModItems.init();
		ModCreativeTab.init();
		TideClock.init();
		EndureRest.init();
		Offering.init();
		FrameMusic.init();
		LOGGER.info("The Sift initialized (unofficial fan project)");
	}

	/** Builds an identifier in our own namespace; nothing is ever registered under {@code minecraft}. */
	public static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(MOD_ID, path);
	}
}
