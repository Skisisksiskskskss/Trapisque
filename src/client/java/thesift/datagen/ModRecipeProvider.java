package thesift.datagen;

import java.util.List;
import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricRecipeProvider;
import net.minecraft.advancements.Advancement;
import net.minecraft.core.HolderLookup;
import net.minecraft.data.recipes.RecipeCategory;
import net.minecraft.data.recipes.RecipeProvider;
import net.minecraft.data.worldgen.BootstrapContext;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.crafting.CampfireCookingRecipe;
import net.minecraft.world.item.crafting.CookingBookCategory;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.world.item.crafting.Recipe;
import net.minecraft.world.item.crafting.SmeltingRecipe;
import net.minecraft.world.item.crafting.SmokingRecipe;
import net.minecraft.world.level.ItemLike;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.WallBlock;

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
			/** A silk-touched ore smelts and blasts as vanilla's do (vanilla's own recipes list only vanilla's ores). */
			private void smeltOre(ItemLike ore, ItemLike result, float xp, String group) {
				oreSmelting(List.of(ore), RecipeCategory.MISC, CookingBookCategory.MISC, result, xp, 200, group);
				oreBlasting(List.of(ore), RecipeCategory.MISC, CookingBookCategory.MISC, result, xp, 100, group);
			}

			@Override
			public void buildRecipes() {
				planksFromLog(ModBlocks.SONGWOOD_PLANKS, ModTags.SONGWOOD_LOGS_ITEM, 4);
				twoByTwoPacker(RecipeCategory.BUILDING_BLOCKS, ModBlocks.HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE);
				stairBuilder(ModBlocks.HYMNSTONE_BRICK_STAIRS, Ingredient.of(ModBlocks.HYMNSTONE_BRICKS))
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
				// The hymnstone family (owner: hymnstone works as stone): cobbled smelts back to hymnstone, hymnstone to smooth.
				for (Block[] set : new Block[][] {{ModBlocks.HYMNSTONE, ModBlocks.HYMNSTONE_STAIRS, ModBlocks.HYMNSTONE_SLAB, null},
						{ModBlocks.COBBLED_HYMNSTONE, ModBlocks.COBBLED_HYMNSTONE_STAIRS, ModBlocks.COBBLED_HYMNSTONE_SLAB, ModBlocks.COBBLED_HYMNSTONE_WALL},
						{ModBlocks.SMOOTH_HYMNSTONE, null, ModBlocks.SMOOTH_HYMNSTONE_SLAB, null},
						{ModBlocks.POLISHED_HYMNSTONE, ModBlocks.POLISHED_HYMNSTONE_STAIRS, ModBlocks.POLISHED_HYMNSTONE_SLAB, ModBlocks.POLISHED_HYMNSTONE_WALL}}) {
					Block base = set[0];
					if (set[1] != null) {
						stairBuilder(set[1], Ingredient.of(base)).unlockedBy(getHasName(base), has(base)).save(output);
						stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, set[1], base);
					}
					slab(RecipeCategory.BUILDING_BLOCKS, set[2], base);
					stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, set[2], base, 2);
					if (set[3] != null) {
						wall(RecipeCategory.DECORATIONS, set[3], base);
						stonecutterResultFromBase(RecipeCategory.DECORATIONS, set[3], base);
					}
				}
				smeltingResultFromBase(ModBlocks.HYMNSTONE, ModBlocks.COBBLED_HYMNSTONE);
				smeltingResultFromBase(ModBlocks.SMOOTH_HYMNSTONE, ModBlocks.HYMNSTONE);
				smeltingResultFromBase(ModBlocks.CRACKED_HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE_BRICKS);
				polished(RecipeCategory.BUILDING_BLOCKS, ModBlocks.POLISHED_HYMNSTONE, ModBlocks.SMOOTH_HYMNSTONE);
				chiseled(RecipeCategory.BUILDING_BLOCKS, ModBlocks.CHISELED_HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE_BRICK_SLAB);
				for (Block cut : new Block[] {ModBlocks.POLISHED_HYMNSTONE, ModBlocks.POLISHED_HYMNSTONE_STAIRS, ModBlocks.POLISHED_HYMNSTONE_WALL,
						ModBlocks.CHISELED_HYMNSTONE_BRICKS}) {
					stonecutterResultFromBase(cut instanceof WallBlock ? RecipeCategory.DECORATIONS
							: RecipeCategory.BUILDING_BLOCKS, cut, ModBlocks.HYMNSTONE);
				}
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.POLISHED_HYMNSTONE_SLAB, ModBlocks.HYMNSTONE, 2);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.POLISHED_HYMNSTONE, ModBlocks.SMOOTH_HYMNSTONE);
				stonecutterResultFromBase(RecipeCategory.BUILDING_BLOCKS, ModBlocks.CHISELED_HYMNSTONE_BRICKS, ModBlocks.HYMNSTONE_BRICKS);
				// M2 materials (items_m2.md): a frond is a cyan dye, four Endure petals around hymnstone a lumen lantern.
				oneToOneConversionRecipe(Items.DYE.cyan(), ModItems.TIDEWRACK_FROND, "cyan_dye");
				// Living in the Sift (survival_sift.md §1): stew, string, a baked root, smelted ores.
				shapeless(RecipeCategory.FOOD, ModItems.GLOWCAP_STEW).requires(Items.BOWL).requires(ModBlocks.GLOWCAP, 2)
						.unlockedBy(getHasName(ModBlocks.GLOWCAP), has(ModBlocks.GLOWCAP)).save(output);
				shapeless(RecipeCategory.MISC, Items.STRING).requires(ModBlocks.SONGWOOD_DRAPES, 3)
						.unlockedBy(getHasName(ModBlocks.SONGWOOD_DRAPES), has(ModBlocks.SONGWOOD_DRAPES)).save(output, "string_from_songwood_drapes");
				simpleCookingRecipe("smelting", SmeltingRecipe::new, 200, ModItems.TIDE_ROOT, ModItems.BAKED_TIDE_ROOT, 0.35F);
				simpleCookingRecipe("smoking", SmokingRecipe::new, 100, ModItems.TIDE_ROOT, ModItems.BAKED_TIDE_ROOT, 0.35F);
				simpleCookingRecipe("campfire_cooking", CampfireCookingRecipe::new, 600, ModItems.TIDE_ROOT, ModItems.BAKED_TIDE_ROOT, 0.35F);
				smeltOre(ModBlocks.HYMNSTONE_COAL_ORE, Items.COAL, 0.1F, "coal");
				smeltOre(ModBlocks.HYMNSTONE_COPPER_ORE, Items.COPPER_INGOT, 0.7F, "copper_ingot");
				smeltOre(ModBlocks.HYMNSTONE_IRON_ORE, Items.IRON_INGOT, 0.7F, "iron_ingot");
				smeltOre(ModBlocks.HYMNSTONE_GOLD_ORE, Items.GOLD_INGOT, 1.0F, "gold_ingot");
				smeltOre(ModBlocks.HYMNSTONE_REDSTONE_ORE, Items.REDSTONE, 0.7F, "redstone");
				smeltOre(ModBlocks.HYMNSTONE_LAPIS_ORE, Items.LAPIS_LAZULI, 0.2F, "lapis_lazuli");
				smeltOre(ModBlocks.HYMNSTONE_DIAMOND_ORE, Items.DIAMOND, 1.0F, "diamond");
				smeltOre(ModBlocks.HYMNSTONE_EMERALD_ORE, Items.EMERALD, 1.0F, "emerald");
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
