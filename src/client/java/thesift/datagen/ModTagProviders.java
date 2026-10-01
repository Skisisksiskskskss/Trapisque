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
					ModBlocks.HYMNSTONE_BRICK_SLAB, ModBlocks.HYMNSTONE_BRICK_WALL, ModBlocks.HEALTHY_SCULK, ModBlocks.TIDE_VENT);
			tag(BlockTags.MINEABLE_WITH_AXE, ModBlocks.SONGWOOD_LOG, ModBlocks.SONGWOOD_PLANKS);
			tag(BlockTags.MINEABLE_WITH_HOE, ModBlocks.SONGWOOD_LEAVES);
			tag(BlockTags.MINEABLE_WITH_SHOVEL, ModBlocks.TIDE_SAND);
			tag(BlockTags.STAIRS, ModBlocks.HYMNSTONE_BRICK_STAIRS);
			tag(BlockTags.SLABS, ModBlocks.HYMNSTONE_BRICK_SLAB);
			tag(BlockTags.WALLS, ModBlocks.HYMNSTONE_BRICK_WALL);
			tag(BlockTags.LEAVES, ModBlocks.SONGWOOD_LEAVES);
			tag(BlockTags.SAPLINGS, ModBlocks.SONGWOOD_SAPLING);
			tag(BlockTags.FLOWER_POTS, ModBlocks.POTTED_SONGWOOD_SAPLING);
			tag(BlockTags.PLANKS, ModBlocks.SONGWOOD_PLANKS);
			tag(ModTags.SONGWOOD_LOGS, ModBlocks.SONGWOOD_LOG);
			tag(ModTags.BLUBS_SPAWNABLE_ON, ModBlocks.HEALTHY_SCULK, ModBlocks.TIDE_SAND);
			builder(BlockItemTags.LOGS_THAT_BURN.block()).addTag(ModTags.SONGWOOD_LOGS);
			// Like vanilla grass: trees, mushrooms and flowing liquids replace it.
			tag(BlockTags.REPLACEABLE, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			tag(BlockTags.REPLACEABLE_BY_TREES, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			tag(BlockTags.REPLACEABLE_BY_MUSHROOMS, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			tag(BlockTags.WASHED_AWAY_BY_FLUIDS, ModBlocks.HEALTHY_SCULK_GRASS, ModBlocks.TALL_HEALTHY_SCULK_GRASS);
			// 26.3 decides "blocks motion" (heightmaps, spawning, worldgen placement) by tag, not by shape.
			tag(BlockTags.BLOCKS_MOTION_NO_LEAVES, ModBlocks.HYMNSTONE, ModBlocks.HYMNSTONE_BRICKS, ModBlocks.HEALTHY_SCULK,
					ModBlocks.TIDE_SAND, ModBlocks.TIDE_VENT, ModBlocks.GATESTONE);
			tag(BlockTags.WITHER_IMMUNE, ModBlocks.GATESTONE, ModBlocks.SIFT_MEMBRANE);
			tag(BlockTags.DRAGON_IMMUNE, ModBlocks.GATESTONE, ModBlocks.SIFT_MEMBRANE);
			tag(BlockTags.PORTALS, ModBlocks.SIFT_MEMBRANE);
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
			tag(BlockItemTags.STAIRS.item(), ModBlocks.HYMNSTONE_BRICK_STAIRS);
			tag(BlockItemTags.SLABS.item(), ModBlocks.HYMNSTONE_BRICK_SLAB);
			tag(ItemTags.WALLS, ModBlocks.HYMNSTONE_BRICK_WALL);
			tag(ItemTags.LEAVES, ModBlocks.SONGWOOD_LEAVES);
			tag(ItemTags.SAPLINGS, ModBlocks.SONGWOOD_SAPLING);
			tag(ItemTags.PLANKS, ModBlocks.SONGWOOD_PLANKS);
			tag(ModTags.SONGWOOD_LOGS_ITEM, ModBlocks.SONGWOOD_LOG);
			builder(ItemTags.LOGS_THAT_BURN).addTag(ModTags.SONGWOOD_LOGS_ITEM);
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
			// The Sift's natives: blubs bathe in ichor (mob_blub.md).
			builder(ModTags.ICHOR_ADAPTED).add(ModEntities.BLUB_KEY);
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
		}
	}
}
