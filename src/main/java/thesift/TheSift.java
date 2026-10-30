package thesift;

import net.fabricmc.api.ModInitializer;
import net.minecraft.resources.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import thesift.entity.blub.BlubCrossing;
import thesift.entity.hunt.Hunt;
import thesift.entry.FrameCues;
import thesift.entry.FrameMusic;
import thesift.entry.Offering;
import thesift.entry.Rifts;
import thesift.item.SongCharges;
import thesift.loot.SoulBlockLoot;
import thesift.registry.ModAttachments;
import thesift.registry.ModAttributes;
import thesift.registry.ModBlockEntities;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModFeatureTypes;
import thesift.registry.ModCreativeTab;
import thesift.registry.ModFluids;
import thesift.registry.ModGameRules;
import thesift.registry.ModLootConditions;
import thesift.registry.ModParticles;
import thesift.registry.ModPoiTypes;
import thesift.registry.ModSounds;
import thesift.registry.ModItems;
import thesift.world.EndureRest;
import thesift.world.TideClock;
import thesift.world.TideCues;

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
		ModGameRules.init();
		ModAttachments.init();
		ModSounds.init();
		ModParticles.init();
		ModFluids.init();
		ModBlocks.init();
		ModPoiTypes.init();
		ModLootConditions.init();
		ModBlockEntities.init();
		ModEntities.init();
		ModFeatureTypes.init();
		ModItems.init();
		ModCreativeTab.init();
		TideClock.init();
		EndureRest.init();
		Offering.init();
		FrameMusic.init();
		FrameCues.init();
		TideCues.init();
		BlubCrossing.init();
		Hunt.init();
		Rifts.init();
		SongCharges.init();
		SoulBlockLoot.init();
		LOGGER.info("The Sift initialized (unofficial fan project)");
	}

	/** Builds an identifier in our own namespace; nothing is ever registered under {@code minecraft}. */
	public static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(MOD_ID, path);
	}
}
