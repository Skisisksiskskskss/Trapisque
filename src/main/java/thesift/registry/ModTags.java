package thesift.registry;

import net.minecraft.core.registries.Registries;
import net.minecraft.tags.TagKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.material.Fluid;

import thesift.TheSift;

/** Our own tags. */
public final class ModTags {
	public static final TagKey<Block> SONGWOOD_LOGS = TagKey.create(Registries.BLOCK, TheSift.id("songwood_logs"));
	public static final TagKey<Item> SONGWOOD_LOGS_ITEM = TagKey.create(Registries.ITEM, TheSift.id("songwood_logs"));
	public static final TagKey<Fluid> ICHOR = TagKey.create(Registries.FLUID, TheSift.id("ichor"));
	/** The two plants that keep time with the Tide (block_flora_ii.md). */
	public static final TagKey<Block> TIDE_FLORA = TagKey.create(Registries.BLOCK, TheSift.id("tide_flora"));
	/** Where blubs spawn: healthy sculk and tide sand (mob_blub.md, Spawning). */
	public static final TagKey<Block> BLUBS_SPAWNABLE_ON = TagKey.create(Registries.BLOCK, TheSift.id("blubs_spawnable_on"));
	/** Entities the membrane never lets through: nothing chases a player into a gate's sanctuary. */
	public static final TagKey<EntityType<?>> CANNOT_CROSS = TagKey.create(Registries.ENTITY_TYPE, TheSift.id("cannot_cross"));

	private ModTags() {
	}
}
