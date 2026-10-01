package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricLanguageProvider;
import net.minecraft.core.HolderLookup;

import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModItems;

/** English (en_us) strings. Every player-facing string in the mod is added here. */
final class ModLanguageProvider extends FabricLanguageProvider {
	ModLanguageProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, "en_us", registries);
	}

	@Override
	public void generateTranslations(HolderLookup.Provider registries, TranslationBuilder builder) {
		builder.add("thesift.disclaimer", "Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.");
		builder.add("thesift.bed.no_sleep", "You can't sleep here: the Sift never goes quiet");
		builder.add("thesift.bed.rested", "You rest a while; the Tide keeps turning");
		builder.add("itemGroup.thesift", "The Sift");
		builder.add(ModBlocks.HYMNSTONE, "Hymnstone");
		builder.add(ModBlocks.HYMNSTONE_BRICKS, "Hymnstone Bricks");
		builder.add(ModBlocks.HYMNSTONE_BRICK_STAIRS, "Hymnstone Brick Stairs");
		builder.add(ModBlocks.HYMNSTONE_BRICK_SLAB, "Hymnstone Brick Slab");
		builder.add(ModBlocks.HYMNSTONE_BRICK_WALL, "Hymnstone Brick Wall");
		builder.add(ModBlocks.HEALTHY_SCULK, "Healthy Sculk");
		builder.add(ModBlocks.HEALTHY_SCULK_GRASS, "Healthy Sculk Grass");
		builder.add(ModBlocks.TALL_HEALTHY_SCULK_GRASS, "Tall Healthy Sculk Grass");
		builder.add(ModBlocks.SONGWOOD_LOG, "Songwood Log");
		builder.add(ModBlocks.SONGWOOD_PLANKS, "Songwood Planks");
		builder.add(ModBlocks.SONGWOOD_LEAVES, "Songwood Leaves");
		builder.add(ModBlocks.SONGWOOD_SAPLING, "Songwood Sapling");
		builder.add(ModBlocks.POTTED_SONGWOOD_SAPLING, "Potted Songwood Sapling");
		builder.add(ModBlocks.TIDE_SAND, "Tide Sand");
		builder.add(ModBlocks.TIDE_VENT, "Tide Vent");
		builder.add(ModBlocks.GATESTONE, "Gatestone");
		builder.add(ModBlocks.SIFT_MEMBRANE, "Sift Membrane");
		builder.add("subtitles.thesift.frame.offer", "Soul flows into the frame");
		builder.add("subtitles.thesift.frame.wake", "The frame wakes");
		builder.add("subtitles.thesift.frame.open", "The frame opens");
		builder.add("subtitles.thesift.frame.hum", "The frame hums");
		builder.add("subtitles.thesift.membrane.ambient", "Membrane chimes");
		builder.add("subtitles.thesift.membrane.travel", "Crossing the membrane");
		builder.add("subtitles.thesift.tide.thrive", "The Tide ebbs: Thrive");
		builder.add("subtitles.thesift.tide.flow", "The Tide turns: Flow");
		builder.add("subtitles.thesift.tide.endure", "The Tide rises: Endure");
		builder.add("subtitles.thesift.basin.fill", "Ichor bubbles up");
		builder.add("subtitles.thesift.basin.drain", "Ichor drains away");
		builder.add("subtitles.thesift.ichor.wade", "Wading through ichor");
		builder.add("subtitles.thesift.ichor.ambient", "Ichor pops");
		builder.add("subtitles.thesift.ichor.evaporate", "Ichor evaporates");
		builder.add("subtitles.thesift.bucket.fill_ichor", "Bucket fills");
		builder.add("subtitles.thesift.bucket.empty_ichor", "Bucket empties");
		builder.add("subtitles.thesift.meadow.loop", "Wind sings in the songwood");
		builder.add("subtitles.thesift.blub.ambient", "Blub squeaks");
		builder.add("subtitles.thesift.blub.listen", "Blub listens");
		builder.add("subtitles.thesift.blub.happy", "Blub is happy");
		builder.add("subtitles.thesift.blub.sing", "Blub sings");
		builder.add("subtitles.thesift.blub.restless", "Blub is restless");
		builder.add("subtitles.thesift.blub.curl", "Blub hums");
		builder.add("subtitles.thesift.blub.splash", "Blub splashes");
		builder.add("subtitles.thesift.blub.topple", "Blubs topple");
		builder.add("subtitles.thesift.blub.hurt", "Blub hurts");
		builder.add("subtitles.thesift.blub.death", "Blub dies");
		builder.add("subtitles.thesift.blub.hop", "Blub hops");
		builder.add("subtitles.thesift.frame.notice", "Your soul stirs toward the frame");
		builder.add("subtitles.thesift.meadow.mood", "A far-off flute");
		builder.add(ModBlocks.ICHOR, "Ichor");
		builder.add(ModItems.ICHOR_BUCKET, "Ichor Bucket");
		builder.add(ModEntities.BLUB, "Blub");
		builder.add(ModItems.BLUB_SPAWN_EGG, "Blub Spawn Egg");
		builder.add("advancements.thesift.root.title", "The Sift");
		builder.add("advancements.thesift.root.description", "Walk an Ancient City, where something old is listening");
		builder.add("advancements.thesift.an_offering.title", "An Offering");
		builder.add("advancements.thesift.an_offering.description", "Wake an Ancient City's frame with your experience");
		builder.add("advancements.thesift.where_souls_drift.title", "Where Souls Drift");
		builder.add("advancements.thesift.where_souls_drift.description", "Play music to an awake frame and cross into the Sift");
		builder.add("advancements.thesift.the_tide_turns.title", "The Tide Turns");
		builder.add("advancements.thesift.the_tide_turns.description", "Be in the Sift when the Tide changes");
		builder.add("tag.fluid.thesift.ichor", "Ichor");
		builder.add("tag.item.thesift.songwood_logs", "Songwood Logs");
		builder.add("thesift.frame.offering", "Your soul flows into the frame (%s%%)");
		builder.add("thesift.frame.woke", "The frame wakes; it is listening for music");
		builder.add("thesift.frame.awake", "The frame is awake; play it some music");
		builder.add("thesift.frame.no_soul", "You have no experience left to offer");
	}
}
