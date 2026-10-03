package thesift.registry;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;

import thesift.TheSift;
import thesift.loot.TideFloraReady;

/** Our loot conditions: {@code thesift:tide_flora_ready} (block_flora_ii.md). */
public final class ModLootConditions {
	private ModLootConditions() {
	}

	public static void init() {
		Registry.register(BuiltInRegistries.LOOT_CONDITION_TYPE, TheSift.id("tide_flora_ready"), TideFloraReady.CODEC);
	}
}
