package thesift.loot;

import net.fabricmc.fabric.api.loot.v3.LootTableEvents;
import net.minecraft.world.level.storage.loot.BuiltInLootTables;
import net.minecraft.world.level.storage.loot.LootPool;
import net.minecraft.world.level.storage.loot.entries.LootItem;
import net.minecraft.world.level.storage.loot.predicates.LootItemRandomChanceCondition;

import thesift.registry.ModBlocks;

/**
 * Stolen soul blocks (items.md §1.1; canon: "Lost Harmonies: Find the stolen soul blocks"): the
 * Illagers took them, so a pillager outpost's chest holds one half the time.
 */
public final class SoulBlockLoot {
	private SoulBlockLoot() {
	}

	public static void init() {
		LootTableEvents.MODIFY.register((key, table, source, registries) -> {
			if (source.isBuiltin() && key.equals(BuiltInLootTables.PILLAGER_OUTPOST)) {
				table.withPool(LootPool.lootPool()
						.add(LootItem.lootTableItem(ModBlocks.SOUL_BLOCK))
						.when(LootItemRandomChanceCondition.randomChance(0.5F)));
			}
		});
	}
}
