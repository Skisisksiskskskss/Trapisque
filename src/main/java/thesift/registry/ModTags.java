package thesift.registry;

import net.minecraft.core.registries.Registries;
import net.minecraft.tags.TagKey;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;

import thesift.TheSift;

/** Our own tags. */
public final class ModTags {
	public static final TagKey<Block> SONGWOOD_LOGS = TagKey.create(Registries.BLOCK, TheSift.id("songwood_logs"));
	public static final TagKey<Item> SONGWOOD_LOGS_ITEM = TagKey.create(Registries.ITEM, TheSift.id("songwood_logs"));

	private ModTags() {
	}
}
