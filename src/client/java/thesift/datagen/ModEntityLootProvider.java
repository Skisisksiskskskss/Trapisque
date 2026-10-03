package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricEntityLootSubProvider;
import net.minecraft.core.HolderLookup;
import net.minecraft.world.level.storage.loot.LootTable;

import thesift.registry.ModEntities;

/** Entity loot tables. A blub drops nothing but its experience, as the allay and axolotl (mob_blub.md). */
final class ModEntityLootProvider extends FabricEntityLootSubProvider {
	ModEntityLootProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries);
	}

	@Override
	public void generate() {
		this.add(ModEntities.BLUB, LootTable.lootTable());
	}
}
