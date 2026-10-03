package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricBlockLootSubProvider;
import net.minecraft.advancements.predicates.StatePropertiesPredicate;
import net.minecraft.core.HolderLookup;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.enchantment.Enchantments;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.storage.loot.LootPool;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.level.storage.loot.entries.LootItem;
import net.minecraft.world.level.storage.loot.entries.UniformContainerBase;
import net.minecraft.world.level.storage.loot.functions.ApplyBonusCount;
import net.minecraft.world.level.storage.loot.functions.SetItemCountFunction;
import net.minecraft.world.level.storage.loot.predicates.BonusLevelTableCondition;
import net.minecraft.world.level.storage.loot.predicates.LootItemCondition;
import net.minecraft.world.level.storage.loot.predicates.MatchBlock;
import net.minecraft.world.level.storage.loot.providers.number.ints.ContextIntProviders;

import thesift.block.TideRootsBlock;
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
		add(ModBlocks.HYMNSTONE, b -> createSingleItemTableWithSilkTouch(b, ModBlocks.COBBLED_HYMNSTONE));
		for (Block b : new Block[] {ModBlocks.CRACKED_HYMNSTONE_BRICKS, ModBlocks.CHISELED_HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE_STAIRS,
				ModBlocks.COBBLED_HYMNSTONE, ModBlocks.COBBLED_HYMNSTONE_STAIRS, ModBlocks.COBBLED_HYMNSTONE_WALL, ModBlocks.SMOOTH_HYMNSTONE,
				ModBlocks.POLISHED_HYMNSTONE, ModBlocks.POLISHED_HYMNSTONE_STAIRS, ModBlocks.POLISHED_HYMNSTONE_WALL}) {
			dropSelf(b);
		}
		for (Block b : new Block[] {ModBlocks.HYMNSTONE_SLAB, ModBlocks.COBBLED_HYMNSTONE_SLAB, ModBlocks.SMOOTH_HYMNSTONE_SLAB,
				ModBlocks.POLISHED_HYMNSTONE_SLAB}) {
			add(b, this::createSlabItemTable);
		}
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
		// Songwood leaves drop songfruit as oak leaves drop apples (survival_sift.md §1).
		add(ModBlocks.SONGWOOD_LEAVES, createLeavesDrops(ModBlocks.SONGWOOD_LEAVES, ModBlocks.SONGWOOD_SAPLING, 0.05F, 0.0625F, 0.083333336F, 0.1F)
				.withPool(LootPool.lootPool().setRolls(ContextIntProviders.exactly(1)).when(this.doesNotHaveShearsOrSilkTouch())
						.add(((UniformContainerBase.Builder<?>) this.applyExplosionCondition(ModBlocks.SONGWOOD_LEAVES, LootItem.lootTableItem(ModItems.SONGFRUIT)))
								.when(BonusLevelTableCondition.bonusLevelFlatChance(this.enchantments.getOrThrow(Enchantments.FORTUNE),
										0.005F, 0.0055555557F, 0.00625F, 0.008333334F, 0.025F)))));
		// Hymnstone ores drop vanilla's items, as deepslate's do.
		add(ModBlocks.HYMNSTONE_COAL_ORE, createOreDrop(ModBlocks.HYMNSTONE_COAL_ORE, Items.COAL));
		add(ModBlocks.HYMNSTONE_COPPER_ORE, createCopperOreDrops(ModBlocks.HYMNSTONE_COPPER_ORE));
		add(ModBlocks.HYMNSTONE_IRON_ORE, createOreDrop(ModBlocks.HYMNSTONE_IRON_ORE, Items.RAW_IRON));
		add(ModBlocks.HYMNSTONE_GOLD_ORE, createOreDrop(ModBlocks.HYMNSTONE_GOLD_ORE, Items.RAW_GOLD));
		add(ModBlocks.HYMNSTONE_REDSTONE_ORE, createRedstoneOreDrops(ModBlocks.HYMNSTONE_REDSTONE_ORE));
		add(ModBlocks.HYMNSTONE_LAPIS_ORE, createLapisOreDrops(ModBlocks.HYMNSTONE_LAPIS_ORE));
		add(ModBlocks.HYMNSTONE_DIAMOND_ORE, createOreDrop(ModBlocks.HYMNSTONE_DIAMOND_ORE, Items.DIAMOND));
		add(ModBlocks.HYMNSTONE_EMERALD_ORE, createOreDrop(ModBlocks.HYMNSTONE_EMERALD_ORE, Items.EMERALD));
		// Echo ore: one or two echo shards, Fortune adding as on any ore.
		add(ModBlocks.ECHO_ORE, createSilkTouchDispatchTable(ModBlocks.ECHO_ORE, applyExplosionDecay(ModBlocks.ECHO_ORE,
				LootItem.lootTableItem(Items.ECHO_SHARD).apply(SetItemCountFunction.setCount(ContextIntProviders.between(1, 2)))
						.apply(ApplyBonusCount.addOreBonusCount(this.enchantments.getOrThrow(Enchantments.FORTUNE))))));
		// Tide roots: a root always; ripe, two to four more, as carrots.
		LootItemCondition.Builder ripe = MatchBlock.blockMatches(this.blocks, ModBlocks.TIDE_ROOTS,
				StatePropertiesPredicate.Builder.properties().hasProperty(TideRootsBlock.AGE, 3));
		add(ModBlocks.TIDE_ROOTS, applyExplosionDecay(ModBlocks.TIDE_ROOTS, LootTable.lootTable()
				.withPool(LootPool.lootPool().add(LootItem.lootTableItem(ModItems.TIDE_ROOT)))
				.withPool(LootPool.lootPool().when(ripe).add(LootItem.lootTableItem(ModItems.TIDE_ROOT)
						.apply(ApplyBonusCount.addBonusBinomialDistributionCount(this.enchantments.getOrThrow(Enchantments.FORTUNE), 0.5714286F, 3))))));
		dropSelf(ModBlocks.SONGWOOD_SAPLING);
		dropPottedContents(ModBlocks.POTTED_SONGWOOD_SAPLING);
		dropSelf(ModBlocks.TIDE_SAND);
		dropSelf(ModBlocks.TIDE_VENT);
		dropSelf(ModBlocks.LUMEN_LANTERN);
		dropSelf(ModBlocks.ICHOR_LILY);
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
