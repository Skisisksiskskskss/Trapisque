package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricBlockLootSubProvider;
import net.minecraft.core.HolderLookup;

import thesift.registry.ModBlocks;

/** Block loot tables for block set I. The gatestone drops nothing (it can't be broken in survival). */
final class ModLootProvider extends FabricBlockLootSubProvider {
	ModLootProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries);
	}

	@Override
	public void generate() {
		dropSelf(ModBlocks.HYMNSTONE);
		dropSelf(ModBlocks.HYMNSTONE_BRICKS);
		dropSelf(ModBlocks.HYMNSTONE_BRICK_STAIRS);
		add(ModBlocks.HYMNSTONE_BRICK_SLAB, createSlabItemTable(ModBlocks.HYMNSTONE_BRICK_SLAB));
		dropSelf(ModBlocks.HYMNSTONE_BRICK_WALL);
		// Like nylium: hymnstone unless mined with Silk Touch.
		add(ModBlocks.HEALTHY_SCULK, createSingleItemTableWithSilkTouch(ModBlocks.HEALTHY_SCULK, ModBlocks.HYMNSTONE));
		add(ModBlocks.HEALTHY_SCULK_GRASS, createShearsOnlyDrop(ModBlocks.HEALTHY_SCULK_GRASS));
		add(ModBlocks.TALL_HEALTHY_SCULK_GRASS, createDoublePlantShearsDrop(ModBlocks.HEALTHY_SCULK_GRASS));
		dropSelf(ModBlocks.SONGWOOD_LOG);
		dropSelf(ModBlocks.SONGWOOD_PLANKS);
		add(ModBlocks.SONGWOOD_LEAVES, createLeavesDrops(ModBlocks.SONGWOOD_LEAVES, ModBlocks.SONGWOOD_SAPLING, 0.05F, 0.0625F, 0.083333336F, 0.1F));
		dropSelf(ModBlocks.SONGWOOD_SAPLING);
		dropPottedContents(ModBlocks.POTTED_SONGWOOD_SAPLING);
		dropSelf(ModBlocks.TIDE_SAND);
		dropSelf(ModBlocks.TIDE_VENT);
	}
}
