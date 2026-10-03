package thesift.registry;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.function.Function;
import java.util.function.UnaryOperator;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Registry;
import net.minecraft.core.dispenser.BlockSource;
import net.minecraft.core.dispenser.DefaultDispenseItemBehavior;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.food.Foods;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.DoubleHighBlockItem;
import net.minecraft.world.item.DispensibleContainerItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.PlaceOnWaterBlockItem;
import net.minecraft.world.item.SpawnEggItem;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.DispenserBlock;
import net.minecraft.world.level.block.DoublePlantBlock;
import net.minecraft.world.level.block.LilyPadBlock;
import net.minecraft.world.level.storage.loot.providers.number.ints.ContextIntProviders;

import thesift.TheSift;
import thesift.item.IchorBucketItem;

/** Items (D-019). Block items are registered together with their blocks, in creative-tab order. */
public final class ModItems {
	private static final List<Item> CREATIVE_ORDER = new ArrayList<>();
	private static final List<Item> OTHER_ITEMS = new ArrayList<>();

	public static final Item BLUB_SPAWN_EGG = other(register(key("blub_spawn_egg"), SpawnEggItem::new,
			new Item.Properties().spawnEgg(ModEntities.BLUB)));
	public static final Item NESTER_SPAWN_EGG = other(register(key("nester_spawn_egg"), SpawnEggItem::new,
			new Item.Properties().spawnEgg(ModEntities.NESTER)));
	/** Picked from open tidewrack in Thrive (block_flora_ii.md §1); its uses come in WP-065. */
	public static final Item TIDEWRACK_FROND = other(register(key("tidewrack_frond"), Item::new,
			new Item.Properties().compostable(ContextIntProviders.COMPOSTABLE_LOW)));
	// Living in the Sift (survival_sift.md §1): food from the leaves, the caves and the shores.
	/** Plants tide roots (on tide sand beside ichor); raw, a little food, as a potato. */
	public static final Item TIDE_ROOT = other(register(key("tide_root"), p -> new BlockItem(ModBlocks.TIDE_ROOTS, p),
			new Item.Properties().useItemDescriptionPrefix().food(new FoodProperties.Builder().nutrition(2).saturationModifier(0.3F).build())
					.compostable(ContextIntProviders.COMPOSTABLE_MEDIUM)));
	/** A baked potato's worth. */
	public static final Item BAKED_TIDE_ROOT = other(register(key("baked_tide_root"), Item::new,
			new Item.Properties().food(Foods.BAKED_POTATO).compostable(ContextIntProviders.COMPOSTABLE_MEDIUM_HIGH)));
	/** Songwood leaves drop it as oak leaves drop apples; an apple's worth. */
	public static final Item SONGFRUIT = other(register(key("songfruit"), Item::new,
			new Item.Properties().food(Foods.APPLE).compostable(ContextIntProviders.COMPOSTABLE_MEDIUM)));
	/** Two glowcaps in a bowl: mushroom stew's worth. */
	public static final Item GLOWCAP_STEW = other(register(key("glowcap_stew"), Item::new,
			new Item.Properties().stacksTo(1).food(Foods.MUSHROOM_STEW).usingConvertsTo(Items.BOWL)));
	/** Picked from an open Endure bloom in Endure (block_flora_ii.md §2); lanterns and traits use it (WP-065). */
	public static final Item ENDURE_PETAL = other(register(key("endure_petal"), Item::new, new Item.Properties()));
	public static final Item ICHOR_BUCKET = other(register(key("ichor_bucket"), p -> new IchorBucketItem(ModFluids.ICHOR, p),
			new Item.Properties().craftRemainder(Items.BUCKET).stacksTo(1)));

	private ModItems() {
	}

	static void registerBlockItem(Block block) {
		registerBlockItem(block, UnaryOperator.identity());
	}

	/** A block item with extra item properties (a compost chance, say). */
	static void registerBlockItem(Block block, UnaryOperator<Item.Properties> extra) {
		ResourceKey<Item> key = ResourceKey.create(Registries.ITEM, BuiltInRegistries.BLOCK.getKey(block));
		Function<Item.Properties, Item> factory = block instanceof DoublePlantBlock ? p -> new DoubleHighBlockItem(block, p)
				: block instanceof LilyPadBlock ? p -> new PlaceOnWaterBlockItem(block, p) // placed on a liquid's surface
				: p -> new BlockItem(block, p);
		Item item = register(key, factory, extra.apply(new Item.Properties().useBlockDescriptionPrefix()));
		CREATIVE_ORDER.add(item);
	}

	static Item register(ResourceKey<Item> key, Function<Item.Properties, Item> factory, Item.Properties properties) {
		Item item = factory.apply(properties.setId(key));
		if (item instanceof BlockItem blockItem) {
			blockItem.registerBlocks(Item.BY_BLOCK, item);
		}
		return Registry.register(BuiltInRegistries.ITEM, key, item);
	}

	private static Item other(Item item) {
		OTHER_ITEMS.add(item);
		return item;
	}

	static ResourceKey<Item> key(String name) {
		return ResourceKey.create(Registries.ITEM, TheSift.id(name));
	}

	/** Every mod item in the order the creative tab shows them. */
	public static List<Item> creativeOrder() {
		List<Item> all = new ArrayList<>(CREATIVE_ORDER);
		all.addAll(OTHER_ITEMS);
		return Collections.unmodifiableList(all);
	}

	public static void init() {
		// Block items register with ModBlocks. Dispensers know only vanilla's buckets, so the ichor
		// bucket brings vanilla's filled-bucket behaviour along (it can then fill a tidewrack in front).
		DispenserBlock.registerBehavior(ICHOR_BUCKET, new DefaultDispenseItemBehavior() {
			private final DefaultDispenseItemBehavior eject = new DefaultDispenseItemBehavior();

			@Override
			public ItemStack execute(BlockSource source, ItemStack dispensed) {
				DispensibleContainerItem bucket = (DispensibleContainerItem) dispensed.getItem();
				BlockPos target = source.pos().relative(source.state().getValue(DispenserBlock.FACING));
				if (bucket.emptyContents(null, source.level(), target, null)) {
					bucket.checkExtraContent(null, source.level(), dispensed, target);
					return this.consumeWithRemainder(source, dispensed, new ItemStack(Items.BUCKET));
				}
				return this.eject.dispense(source, dispensed);
			}
		});
	}
}
