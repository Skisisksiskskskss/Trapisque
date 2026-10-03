package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricBlockLootSubProvider;
import net.minecraft.core.HolderLookup;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.storage.loot.LootPool;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.level.storage.loot.entries.LootItem;
import net.minecraft.world.level.storage.loot.functions.SetItemCountFunction;
import net.minecraft.world.level.storage.loot.providers.number.ints.ContextIntProviders;

import thesift.loot.TideFloraReady;
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;

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
		// Like grass: soil unless mined with Silk Touch.
		add(ModBlocks.HEALTHY_SCULK, createSingleItemTableWithSilkTouch(ModBlocks.HEALTHY_SCULK, ModBlocks.SIFT_SOIL));
		dropSelf(ModBlocks.SIFT_SOIL);
		add(ModBlocks.SONGWOOD_DRAPES, createShearsOrSilkTouchOnlyDrop(ModBlocks.SONGWOOD_DRAPES));
		add(ModBlocks.HEALTHY_SCULK_GRASS, createShearsOnlyDrop(ModBlocks.HEALTHY_SCULK_GRASS));
		add(ModBlocks.TALL_HEALTHY_SCULK_GRASS, createDoublePlantShearsDrop(ModBlocks.HEALTHY_SCULK_GRASS));
		dropSelf(ModBlocks.SONGWOOD_LOG);
		dropSelf(ModBlocks.SONGWOOD_PLANKS);
		add(ModBlocks.SONGWOOD_LEAVES, createLeavesDrops(ModBlocks.SONGWOOD_LEAVES, ModBlocks.SONGWOOD_SAPLING, 0.05F, 0.0625F, 0.083333336F, 0.1F));
		dropSelf(ModBlocks.SONGWOOD_SAPLING);
		dropPottedContents(ModBlocks.POTTED_SONGWOOD_SAPLING);
		dropSelf(ModBlocks.TIDE_SAND);
		dropSelf(ModBlocks.TIDE_VENT);
		// Flora II (block_flora_ii.md, D-027): the tide plants give their harvest when broken ready, and
		// never themselves, whatever the tool; the lumen bloom gives nothing (no loot table at all).
		add(ModBlocks.TIDEWRACK, readyHarvest(ModItems.TIDEWRACK_FROND, 1, 2));
		add(ModBlocks.ENDURE_BLOOM, readyHarvest(ModItems.ENDURE_PETAL, 1, 1));
		dropSelf(ModBlocks.GLOWCAP);
		dropPottedContents(ModBlocks.POTTED_GLOWCAP);
		dropSelf(ModBlocks.CHIME_BELL_FLOWER);
		dropPottedContents(ModBlocks.POTTED_CHIME_BELL_FLOWER);
	}

	/** The harvest, only if the plant is ready (open, unpicked this cycle, its own Tide). No Fortune. */
	static LootTable.Builder readyHarvest(Item item, int min, int max) {
		return LootTable.lootTable().withPool(LootPool.lootPool()
				.when(TideFloraReady.ready())
				.add(LootItem.lootTableItem(item).apply(SetItemCountFunction.setCount(ContextIntProviders.between(min, max)))));
	}
}
