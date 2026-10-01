package thesift.registry;

import net.minecraft.core.registries.Registries;
import net.minecraft.tags.TagKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;

import thesift.TheSift;

/** Our own tags. */
public final class ModTags {
	public static final TagKey<Block> SONGWOOD_LOGS = TagKey.create(Registries.BLOCK, TheSift.id("songwood_logs"));
	public static final TagKey<Item> SONGWOOD_LOGS_ITEM = TagKey.create(Registries.ITEM, TheSift.id("songwood_logs"));
	/** Entities the membrane never lets through: nothing chases a player into a gate's sanctuary. */
	public static final TagKey<EntityType<?>> CANNOT_CROSS = TagKey.create(Registries.ENTITY_TYPE, TheSift.id("cannot_cross"));

	private ModTags() {
	}
}
