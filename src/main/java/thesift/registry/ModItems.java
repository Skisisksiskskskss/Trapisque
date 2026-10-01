package thesift.registry;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.function.Function;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.DoubleHighBlockItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.DoublePlantBlock;

import thesift.TheSift;

/** Items (D-019). Block items are registered together with their blocks, in creative-tab order. */
public final class ModItems {
	private static final List<Item> CREATIVE_ORDER = new ArrayList<>();

	private ModItems() {
	}

	static void registerBlockItem(Block block) {
		ResourceKey<Item> key = ResourceKey.create(Registries.ITEM, BuiltInRegistries.BLOCK.getKey(block));
		Function<Item.Properties, Item> factory = block instanceof DoublePlantBlock
				? p -> new DoubleHighBlockItem(block, p)
				: p -> new BlockItem(block, p);
		Item item = register(key, factory, new Item.Properties().useBlockDescriptionPrefix());
		CREATIVE_ORDER.add(item);
	}

	static Item register(ResourceKey<Item> key, Function<Item.Properties, Item> factory, Item.Properties properties) {
		Item item = factory.apply(properties.setId(key));
		if (item instanceof BlockItem blockItem) {
			blockItem.registerBlocks(Item.BY_BLOCK, item);
		}
		return Registry.register(BuiltInRegistries.ITEM, key, item);
	}

	static ResourceKey<Item> key(String name) {
		return ResourceKey.create(Registries.ITEM, TheSift.id(name));
	}

	/** Every mod item in the order the creative tab shows them. */
	public static List<Item> creativeOrder() {
		return Collections.unmodifiableList(CREATIVE_ORDER);
	}

	public static void init() {
		// Block items register with ModBlocks.
	}
}
