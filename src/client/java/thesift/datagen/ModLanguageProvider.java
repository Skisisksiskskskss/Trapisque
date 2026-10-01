package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricLanguageProvider;
import net.minecraft.core.HolderLookup;

import thesift.registry.ModBlocks;
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
		builder.add("thesift.bed.rested", "You rest a while. The Tide keeps turning.");
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
		builder.add(ModBlocks.ICHOR, "Ichor");
		builder.add(ModItems.ICHOR_BUCKET, "Ichor Bucket");
		builder.add("tag.fluid.thesift.ichor", "Ichor");
		builder.add("tag.item.thesift.songwood_logs", "Songwood Logs");
		builder.add("thesift.frame.offering", "Your soul flows into the frame (%s%%)");
		builder.add("thesift.frame.woke", "The frame wakes. It is listening for music");
		builder.add("thesift.frame.awake", "The frame is awake. Play it some music");
		builder.add("thesift.frame.no_soul", "You have no experience left to offer");
	}
}
