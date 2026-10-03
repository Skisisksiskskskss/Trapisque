package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricTagsProvider;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.tags.BlockItemTags;
import net.minecraft.tags.BlockTags;
import net.minecraft.tags.ItemTags;
import net.minecraft.tags.TagKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;

import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModFluids;
import thesift.registry.ModTags;

/** Block and item tags for block set I. */
final class ModTagProviders {
	private ModTagProviders() {
	}

	static ResourceKey<Block> key(Block block) {
		return BuiltInRegistries.BLOCK.getResourceKey(block).orElseThrow();
	}

	static ResourceKey<Item> itemKey(Block block) {
		return BuiltInRegistries.ITEM.getResourceKey(block.asItem()).orElseThrow();
	}

	static final class Blocks extends FabricTagsProvider.BlockTagsProvider {
		Blocks(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
			super(output, registries);
		}

		private void tag(TagKey<Block> tag, Block... blocks) {
			var appender = builder(tag);
			for (Block block : blocks) {
				appender.add(key(block));
			}
		}

		@Override
		protected void addTags(HolderLookup.Provider registries) {
			tag(BlockTags.MINEABLE_WITH_PICKAXE, ModBlocks.HYMNSTONE, ModBlocks.HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE_BRICK_STAIRS,
					ModBlocks.HYMNSTONE_BRICK_SLAB, ModBlocks.HYMNSTONE_BRICK_WALL, ModBlocks.CRACKED_HYMNSTONE_BRICKS, ModBlocks.CHISELED_HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE_STAIRS, ModBlocks.HYMNSTONE_SLAB,
					ModBlocks.COBBLED_HYMNSTONE, ModBlocks.COBBLED_HYMNSTONE_STAIRS, ModBlocks.COBBLED_HYMNSTONE_SLAB, ModBlocks.COBBLED_HYMNSTONE_WALL,
					ModBlocks.SMOOTH_HYMNSTONE, ModBlocks.SMOOTH_HYMNSTONE_SLAB, ModBlocks.POLISHED_HYMNSTONE, ModBlocks.POLISHED_HYMNSTONE_STAIRS,
					ModBlocks.POLISHED_HYMNSTONE_SLAB, ModBlocks.POLISHED_HYMNSTONE_WALL, ModBlocks.TIDE_VENT,
					ModBlocks.LUMEN_LANTERN);
			tag(BlockTags.MINEABLE_WITH_AXE, ModBlocks.SONGWOOD_LOG, ModBlocks.SONGWOOD_PLANKS);
			tag(BlockTags.MINEABLE_WITH_HOE, ModBlocks.SONGWOOD_LEAVES, ModBlocks.SONGWOOD_DRAPES);
			tag(BlockTags.MINEABLE_WITH_SHOVEL, ModBlocks.TIDE_SAND, ModBlocks.HEALTHY_SCULK, ModBlocks.SIFT_SOIL);
			// Sift soil is the Sift's dirt: plants that grow on dirt grow on it.
			tag(BlockTags.DIRT, ModBlocks.SIFT_SOIL);
			// Hymnstone ores (survival_sift.md §4): vanilla's ore tags and tool tiers.
			tag(BlockTags.MINEABLE_WITH_PICKAXE, ModBlocks.HYMNSTONE_COAL_ORE, ModBlocks.HYMNSTONE_COPPER_ORE, ModBlocks.HYMNSTONE_IRON_ORE,
					ModBlocks.HYMNSTONE_GOLD_ORE, ModBlocks.HYMNSTONE_REDSTONE_ORE, ModBlocks.HYMNSTONE_LAPIS_ORE, ModBlocks.HYMNSTONE_DIAMOND_ORE,
					ModBlocks.HYMNSTONE_EMERALD_ORE, ModBlocks.ECHO_ORE);
			tag(BlockTags.NEEDS_STONE_TOOL, ModBlocks.HYMNSTONE_COPPER_ORE, ModBlocks.HYMNSTONE_IRON_ORE, ModBlocks.HYMNSTONE_LAPIS_ORE);
			tag(BlockTags.NEEDS_IRON_TOOL, ModBlocks.HYMNSTONE_GOLD_ORE, ModBlocks.HYMNSTONE_REDSTONE_ORE, ModBlocks.HYMNSTONE_DIAMOND_ORE,
					ModBlocks.HYMNSTONE_EMERALD_ORE, ModBlocks.ECHO_ORE);
			tag(BlockItemTags.COAL_ORES.block(), ModBlocks.HYMNSTONE_COAL_ORE);
			tag(BlockItemTags.COPPER_ORES.block(), ModBlocks.HYMNSTONE_COPPER_ORE);
			tag(BlockItemTags.IRON_ORES.block(), ModBlocks.HYMNSTONE_IRON_ORE);
			tag(BlockItemTags.GOLD_ORES.block(), ModBlocks.HYMNSTONE_GOLD_ORE);
			tag(BlockItemTags.REDSTONE_ORES.block(), ModBlocks.HYMNSTONE_REDSTONE_ORE);
			tag(BlockItemTags.LAPIS_ORES.block(), ModBlocks.HYMNSTONE_LAPIS_ORE);
			tag(BlockItemTags.DIAMOND_ORES.block(), ModBlocks.HYMNSTONE_DIAMOND_ORE);
			tag(BlockItemTags.EMERALD_ORES.block(), ModBlocks.HYMNSTONE_EMERALD_ORE);
			tag(BlockTags.CROPS, ModBlocks.TIDE_ROOTS);
			// Soil (system_hunt.md): hunters come up out of it and dig back in; stone and planks are safe floors.
			tag(ModTags.HUNTER_BURROWABLE, ModBlocks.HEALTHY_SCULK, ModBlocks.SIFT_SOIL);
			tag(BlockTags.STAIRS, ModBlocks.HYMNSTONE_BRICK_STAIRS,
					ModBlocks.HYMNSTONE_STAIRS, ModBlocks.COBBLED_HYMNSTONE_STAIRS, ModBlocks.POLISHED_HYMNSTONE_STAIRS);
			tag(BlockTags.SLABS, ModBlocks.HYMNSTONE_BRICK_SLAB,
					ModBlocks.HYMNSTONE_SLAB, ModBlocks.COBBLED_HYMNSTONE_SLAB, ModBlocks.SMOOTH_HYMNSTONE_SLAB, ModBlocks.POLISHED_HYMNSTONE_SLAB);
			tag(BlockTags.WALLS, ModBlocks.HYMNSTONE_BRICK_WALL,
					ModBlocks.COBBLED_HYMNSTONE_WALL, ModBlocks.POLISHED_HYMNSTONE_WALL);
			tag(BlockTags.LEAVES, ModBlocks.SONGWOOD_LEAVES);
			tag(BlockTags.SAPLINGS, ModBlocks.SONGWOOD_SAPLING);
			tag(BlockTags.FLOWER_POTS, ModBlocks.POTTED_SONGWOOD_SAPLING);
			tag(BlockTags.PLANKS, ModBlocks.SONGWOOD_PLANKS);
			tag(ModTags.SONGWOOD_LOGS, ModBlocks.SONGWOOD_LOG);
			tag(ModTags.BLUBS_SPAWNABLE_ON, ModBlocks.HEALTHY_SCULK, ModBlocks.SIFT_SOIL, ModBlocks.TIDE_SAND);
			builder(BlockItemTags.LOGS_THAT_BURN.block()).addTag(ModTags.SONGWOOD_LOGS);
			// Like vanilla grass: trees, mushrooms and flowing liquids replace it.
			tag(BlockTags.REPLACEABLE, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			tag(BlockTags.REPLACEABLE_BY_TREES, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS, ModBlocks.SONGWOOD_DRAPES);
			tag(BlockTags.REPLACEABLE_BY_MUSHROOMS, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			tag(BlockTags.WASHED_AWAY_BY_FLUIDS, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			// 26.3 decides "blocks motion" (heightmaps, spawning, worldgen placement) by tag, not by shape.
			tag(BlockTags.BLOCKS_MOTION_NO_LEAVES, ModBlocks.HYMNSTONE, ModBlocks.HYMNSTONE_BRICKS, ModBlocks.HEALTHY_SCULK, ModBlocks.SIFT_SOIL,
					ModBlocks.TIDE_SAND, ModBlocks.TIDE_VENT, ModBlocks.GATESTONE);
			tag(BlockTags.WITHER_IMMUNE, ModBlocks.GATESTONE, ModBlocks.SIFT_MEMBRANE);
			tag(BlockTags.DRAGON_IMMUNE, ModBlocks.GATESTONE, ModBlocks.SIFT_MEMBRANE);
			tag(BlockTags.PORTALS, ModBlocks.SIFT_MEMBRANE);
			// Flora II (block_flora_ii.md): the chime bell is a small flower (bees, stew, endermen); it and the
			// glowcap wash away as vanilla's flowers and mushrooms do; the two wild blooms hold fluids back.
			tag(ModTags.TIDE_FLORA, ModBlocks.TIDEWRACK, ModBlocks.ENDURE_BLOOM);
			tag(BlockTags.SMALL_FLOWERS, ModBlocks.CHIME_BELL_FLOWER);
			tag(BlockTags.BEE_ATTRACTIVE, ModBlocks.CHIME_BELL_FLOWER);
			tag(BlockTags.WASHED_AWAY_BY_FLUIDS, ModBlocks.CHIME_BELL_FLOWER, ModBlocks.GLOWCAP);
			tag(BlockTags.FLOWER_POTS, ModBlocks.POTTED_GLOWCAP, ModBlocks.POTTED_CHIME_BELL_FLOWER);
		}
	}

	static final class Items extends FabricTagsProvider.ItemTagsProvider {
		Items(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
			super(output, registries);
		}

		private void tag(TagKey<Item> tag, Block... blocks) {
			var appender = builder(tag);
			for (Block block : blocks) {
				appender.add(itemKey(block));
			}
		}

		@Override
		protected void addTags(HolderLookup.Provider registries) {
			tag(BlockItemTags.STAIRS.item(), ModBlocks.HYMNSTONE_BRICK_STAIRS,
					ModBlocks.HYMNSTONE_STAIRS, ModBlocks.COBBLED_HYMNSTONE_STAIRS, ModBlocks.POLISHED_HYMNSTONE_STAIRS);
			tag(BlockItemTags.SLABS.item(), ModBlocks.HYMNSTONE_BRICK_SLAB,
					ModBlocks.HYMNSTONE_SLAB, ModBlocks.COBBLED_HYMNSTONE_SLAB, ModBlocks.SMOOTH_HYMNSTONE_SLAB, ModBlocks.POLISHED_HYMNSTONE_SLAB);
			tag(ItemTags.WALLS, ModBlocks.HYMNSTONE_BRICK_WALL,
					ModBlocks.COBBLED_HYMNSTONE_WALL, ModBlocks.POLISHED_HYMNSTONE_WALL);
			tag(ItemTags.LEAVES, ModBlocks.SONGWOOD_LEAVES);
			tag(ItemTags.SAPLINGS, ModBlocks.SONGWOOD_SAPLING);
			tag(ItemTags.PLANKS, ModBlocks.SONGWOOD_PLANKS);
			// Hymnstone is the Sift's cobblestone: stone tools and furnaces (survival_sift.md §1).
			tag(ItemTags.STONE_TOOL_MATERIALS, ModBlocks.COBBLED_HYMNSTONE);
			tag(ItemTags.STONE_CRAFTING_MATERIALS, ModBlocks.COBBLED_HYMNSTONE);
			tag(ModTags.SONGWOOD_LOGS_ITEM, ModBlocks.SONGWOOD_LOG);
			builder(ItemTags.LOGS_THAT_BURN).addTag(ModTags.SONGWOOD_LOGS_ITEM);
			tag(BlockItemTags.SMALL_FLOWERS.item(), ModBlocks.CHIME_BELL_FLOWER);
			tag(BlockItemTags.BEE_FOOD.item(), ModBlocks.CHIME_BELL_FLOWER);
		}
	}

	static final class EntityTypes extends FabricTagsProvider.EntityTypeTagsProvider {
		EntityTypes(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
			super(output, registries);
		}

		@Override
		protected void addTags(HolderLookup.Provider registries) {
			// Wardens and bosses never follow a player through the membrane (entry_path.md §7).
			var cannotCross = builder(ModTags.CANNOT_CROSS);
			for (EntityType<?> type : new EntityType<?>[] {net.minecraft.world.entity.EntityTypes.WARDEN, net.minecraft.world.entity.EntityTypes.WITHER,
					net.minecraft.world.entity.EntityTypes.ENDER_DRAGON, net.minecraft.world.entity.EntityTypes.ELDER_GUARDIAN}) {
				cannotCross.add(BuiltInRegistries.ENTITY_TYPE.getResourceKey(type).orElseThrow());
			}
			// Blubs never use the membrane themselves; owners' blubs come along (BlubCrossing).
			cannotCross.add(ModEntities.BLUB_KEY);
			// Hunters never cross: in an Ancient City there is no Tide, so one would never hear and never leave (D-023).
			builder(ModTags.HUNTERS).add(ModEntities.NESTER_KEY);
			cannotCross.addTag(ModTags.HUNTERS);
		}
	}

	static final class Fluids extends FabricTagsProvider.FluidTagsProvider {
		Fluids(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
			super(output, registries);
		}

		@Override
		protected void addTags(HolderLookup.Provider registries) {
			builder(ModTags.ICHOR)
					.add(BuiltInRegistries.FLUID.getResourceKey(ModFluids.ICHOR).orElseThrow())
					.add(BuiltInRegistries.FLUID.getResourceKey(ModFluids.FLOWING_ICHOR).orElseThrow());
			// Ichor is the Sift's water (D-024): swimming, currents, breath and boats are water's.
			builder(net.minecraft.tags.FluidTags.WATER).addTag(ModTags.ICHOR);
		}
	}
}
