package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricRecipeProvider;
import net.minecraft.advancements.Advancement;
import net.minecraft.core.HolderLookup;
import net.minecraft.data.recipes.RecipeCategory;
import net.minecraft.data.recipes.RecipeProvider;
import net.minecraft.data.worldgen.BootstrapContext;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.crafting.Recipe;

import thesift.registry.ModBlocks;
import thesift.registry.ModItems;
import thesift.registry.ModTags;

/** Crafting and stonecutting recipes for block set I, in vanilla's patterns. */
final class ModRecipeProvider extends FabricRecipeProvider {
	ModRecipeProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries);
	}

	@Override
	protected RecipeProvider createRecipeProvider(HolderLookup.Provider registries, BootstrapContext<Recipe<?>> recipes,
			BootstrapContext<Advancement> advancements) {
		return new RecipeProvider(recipes, advancements) {
			@Override
			public void buildRecipes() {
				planksFromLog(ModBlocks.SONGWOOD_PLANKS, ModTags.SONGWOOD_LOGS_ITEM, 4);
				twoByTwoPacker(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE);
				stairBuilder(ModBlocks.HYMNSTONE_BRICK_STAIRS, net.minecraft.world.item.crafting.Ingredient.of(ModBlocks.HYMNSTONE_BRICKS))
						.unlockedBy(getHasName(ModBlocks.HYMNSTONE_BRICKS), has(ModBlocks.HYMNSTONE_BRICKS)).save(output);
				slab(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICK_SLAB, ModBlocks.HYMNSTONE_BRICKS);
				wall(RecipeCategory.DECORATIONS, ModBlocks.HYMNSTONE_BRICK_WALL, ModBlocks.HYMNSTONE_BRICKS);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICK_STAIRS, ModBlocks.HYMNSTONE);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICK_SLAB, ModBlocks.HYMNSTONE, 2);
				stonecutterResultFromBase(RecipeCategory.DECORATIONS, ModBlocks.HYMNSTONE_BRICK_WALL, ModBlocks.HYMNSTONE);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICK_STAIRS, ModBlocks.HYMNSTONE_BRICKS);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICK_SLAB, ModBlocks.HYMNSTONE_BRICKS, 2);
				stonecutterResultFromBase(RecipeCategory.DECORATIONS, ModBlocks.HYMNSTONE_BRICK_WALL, ModBlocks.HYMNSTONE_BRICKS);
				// M2 materials (items_m2.md): a frond is a cyan dye, four Endure petals around hymnstone a lumen lantern.
				oneToOneConversionRecipe(Items.DYE.cyan(), ModItems.TIDEWRACK_FROND, "cyan_dye");
				shaped(RecipeCategory.DECORATIONS, ModBlocks.LUMEN_LANTERN)
						.define('P', ModItems.ENDURE_PETAL).define('H', ModBlocks.HYMNSTONE)
						.pattern(" P ").pattern("PHP").pattern(" P ")
						.unlockedBy(getHasName(ModItems.ENDURE_PETAL), has(ModItems.ENDURE_PETAL)).save(output);
			}
		};
	}

	@Override
	public String getName() {
		return "The Sift recipes";
	}
}
