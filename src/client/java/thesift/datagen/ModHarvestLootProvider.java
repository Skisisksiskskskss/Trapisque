package thesift.datagen;

import java.util.concurrent.CompletableFuture;
import java.util.function.BiConsumer;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.SimpleFabricLootTableSubProvider;
import net.minecraft.core.HolderLookup;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.level.storage.loot.LootPool;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.level.storage.loot.entries.LootItem;
import net.minecraft.world.level.storage.loot.functions.SetItemCountFunction;
import net.minecraft.world.level.storage.loot.parameters.LootContextParamSets;
import net.minecraft.world.level.storage.loot.providers.number.ints.ContextIntProviders;

import thesift.block.EndureBloomBlock;
import thesift.block.TidewrackBlock;
import thesift.registry.ModItems;

/**
 * What a pick drops (block_flora_ii.md), as vanilla's harvest tables for sweet berries and glow
 * berries: the block checks that the plant is ready before it rolls.
 */
final class ModHarvestLootProvider extends SimpleFabricLootTableSubProvider {
	ModHarvestLootProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries, LootContextParamSets.BLOCK_USE);
	}

	/** Fabric drives this provider through {@link #generate}; vanilla's own entry point is unused. */
	@Override
	public void run() {
	}

	@Override
	public void generate(BiConsumer<ResourceKey<LootTable>, LootTable.Builder> output) {
		output.accept(TidewrackBlock.HARVEST, LootTable.lootTable().withPool(LootPool.lootPool()
				.add(LootItem.lootTableItem(ModItems.TIDEWRACK_FROND).apply(SetItemCountFunction.setCount(ContextIntProviders.between(1, 2))))));
		output.accept(EndureBloomBlock.HARVEST, LootTable.lootTable().withPool(LootPool.lootPool()
				.add(LootItem.lootTableItem(ModItems.ENDURE_PETAL))));
	}
}
