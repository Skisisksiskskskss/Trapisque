package thesift.test;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.Registries;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.crafting.CraftingInput;
import net.minecraft.world.item.crafting.RecipeType;
import net.minecraft.world.item.crafting.SingleRecipeInput;
import net.minecraft.world.item.enchantment.Enchantments;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkAccess;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;

import thesift.TheSift;
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;
import thesift.registry.ModTags;
import thesift.world.SiftFeatures;
import thesift.world.SiftKeys;

/** WP-081: living in the Sift from nothing (survival_sift.md §1, §4; owner: hymnstone works as stone). */
public final class SiftSurvivalTest {
	private static final String SIFT = "thesift:the_sift";
	private static final BlockPos GROUND = new BlockPos(1, 1, 1);

	private static List<ItemStack> drops(GameTestHelper helper, Block block, ItemStack tool) {
		ServerLevel level = helper.getLevel();
		helper.setBlock(GROUND, block);
		BlockPos pos = helper.absolutePos(GROUND);
		return Block.getDrops(level.getBlockState(pos), level, pos, null, null, tool);
	}

	private static boolean only(List<ItemStack> drops, net.minecraft.world.item.Item item) {
		return !drops.isEmpty() && drops.stream().allMatch(s -> s.is(item));
	}

	@GameTest(dimension = SIFT)
	public void tideRootsGrowOnlyOnSandBesideIchor(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockState roots = ModBlocks.TIDE_ROOTS.defaultBlockState();
		BlockPos above = helper.absolutePos(GROUND.above());
		helper.setBlock(GROUND, ModBlocks.TIDE_SAND);
		helper.assertFalse(roots.canSurvive(level, above), "dry tide sand holds no tide roots");
		helper.setBlock(GROUND.east(), ModBlocks.ICHOR);
		helper.assertTrue(roots.canSurvive(level, above), "tide sand beside ichor holds tide roots");
		helper.setBlock(GROUND, ModBlocks.SIFT_SOIL);
		helper.assertFalse(roots.canSurvive(level, above), "soil beside ichor doesn't");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void hymnstoneBreaksToCobbledAsStoneDoes(GameTestHelper helper) {
		ItemStack pick = new ItemStack(Items.STONE_PICKAXE);
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE, pick), ModBlocks.COBBLED_HYMNSTONE.asItem()), "a pickaxe gets cobbled hymnstone");
		ItemStack silk = new ItemStack(Items.IRON_PICKAXE);
		silk.enchant(helper.getLevel().registryAccess().lookupOrThrow(Registries.ENCHANTMENT).getOrThrow(Enchantments.SILK_TOUCH), 1);
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE, silk), ModBlocks.HYMNSTONE.asItem()), "Silk Touch keeps hymnstone");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void hymnstoneOresDropVanillasItems(GameTestHelper helper) {
		ItemStack pick = new ItemStack(Items.IRON_PICKAXE);
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_COAL_ORE, pick), Items.COAL), "coal");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_IRON_ORE, pick), Items.RAW_IRON), "raw iron");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_COPPER_ORE, pick), Items.RAW_COPPER), "raw copper");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_GOLD_ORE, pick), Items.RAW_GOLD), "raw gold");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_REDSTONE_ORE, pick), Items.REDSTONE), "redstone");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_LAPIS_ORE, pick), Items.LAPIS_LAZULI), "lapis");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_DIAMOND_ORE, pick), Items.DIAMOND), "diamond");
		helper.assertTrue(only(drops(helper, ModBlocks.HYMNSTONE_EMERALD_ORE, pick), Items.EMERALD), "emerald");
		List<ItemStack> echo = drops(helper, ModBlocks.ECHO_ORE, pick);
		int shards = echo.stream().mapToInt(ItemStack::getCount).sum();
		helper.assertTrue(only(echo, Items.ECHO_SHARD) && shards >= 1 && shards <= 2, "echo ore drops 1-2 echo shards: " + echo);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void cobbledHymnstoneMakesStoneTools(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		ItemStack c = new ItemStack(ModBlocks.COBBLED_HYMNSTONE);
		ItemStack s = new ItemStack(Items.STICK);
		List<ItemStack> grid = new ArrayList<>(List.of(c.copy(), c.copy(), c.copy(), ItemStack.EMPTY, s.copy(), ItemStack.EMPTY,
				ItemStack.EMPTY, s.copy(), ItemStack.EMPTY));
		CraftingInput pickaxe = CraftingInput.of(3, 3, grid);
		ItemStack made = level.recipeAccess().getRecipeFor(RecipeType.CRAFTING, pickaxe, level).map(r -> r.value().assemble(pickaxe))
				.orElse(ItemStack.EMPTY);
		helper.assertTrue(made.is(Items.STONE_PICKAXE), "cobbled hymnstone and sticks make a stone pickaxe: " + made);
		List<ItemStack> ring = new ArrayList<>();
		for (int i = 0; i < 9; i++) {
			ring.add(i == 4 ? ItemStack.EMPTY : c.copy());
		}
		CraftingInput furnace = CraftingInput.of(3, 3, ring);
		made = level.recipeAccess().getRecipeFor(RecipeType.CRAFTING, furnace, level).map(r -> r.value().assemble(furnace)).orElse(ItemStack.EMPTY);
		helper.assertTrue(made.is(Items.FURNACE), "eight cobbled hymnstone make a furnace: " + made);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void hymnstoneSmeltsAsStoneDoes(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		Block[][] chain = {{ModBlocks.COBBLED_HYMNSTONE, ModBlocks.HYMNSTONE}, {ModBlocks.HYMNSTONE, ModBlocks.SMOOTH_HYMNSTONE},
				{ModBlocks.HYMNSTONE_BRICKS, ModBlocks.CRACKED_HYMNSTONE_BRICKS}};
		for (Block[] step : chain) {
			SingleRecipeInput in = new SingleRecipeInput(new ItemStack(step[0]));
			ItemStack out = level.recipeAccess().getRecipeFor(RecipeType.SMELTING, in, level).map(r -> r.value().assemble(in)).orElse(ItemStack.EMPTY);
			helper.assertTrue(out.is(step[1].asItem()), step[0] + " smelts to " + step[1] + ", got " + out);
		}
		SingleRecipeInput root = new SingleRecipeInput(new ItemStack(ModItems.TIDE_ROOT));
		ItemStack baked = level.recipeAccess().getRecipeFor(RecipeType.SMELTING, root, level).map(r -> r.value().assemble(root)).orElse(ItemStack.EMPTY);
		helper.assertTrue(baked.is(ModItems.BAKED_TIDE_ROOT), "a tide root bakes");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void everySurfaceBiomeHasTheOres(GameTestHelper helper) {
		var biomes = helper.getLevel().registryAccess().lookupOrThrow(Registries.BIOME);
		var placed = helper.getLevel().registryAccess().lookupOrThrow(Registries.PLACED_FEATURE);
		Holder<PlacedFeature> diamonds = placed.getOrThrow(SiftFeatures.ORE_DIAMOND);
		Holder<PlacedFeature> echo = placed.getOrThrow(SiftFeatures.ORE_ECHO_PLACED);
		for (var key : List.of(SiftKeys.SINGERS_MEADOW, SiftKeys.ICHOR_FLATS, SiftKeys.SIFT_HOLLOWS)) {
			Biome biome = biomes.getOrThrow(key).value();
			boolean hasDiamonds = biome.getGenerationSettings().features().stream().anyMatch(set -> set.contains(diamonds));
			helper.assertTrue(hasDiamonds, key.identifier() + " has diamond ore");
			boolean hasEcho = biome.getGenerationSettings().features().stream().anyMatch(set -> set.contains(echo));
			helper.assertTrue(hasEcho == (key == SiftKeys.SIFT_HOLLOWS), key.identifier() + ": echo ore in the Hollows only");
		}
		helper.succeed();
	}

	/** The ores generate (survival_sift.md §4): counted in the shared sample patches, logged, and each of the common ones present. */
	@GameTest(dimension = SIFT, maxTicks = 400)
	public void oresGenerateInTheHymnstone(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		Block[] ores = {ModBlocks.HYMNSTONE_COAL_ORE, ModBlocks.HYMNSTONE_COPPER_ORE, ModBlocks.HYMNSTONE_IRON_ORE, ModBlocks.HYMNSTONE_GOLD_ORE,
				ModBlocks.HYMNSTONE_REDSTONE_ORE, ModBlocks.HYMNSTONE_LAPIS_ORE, ModBlocks.HYMNSTONE_DIAMOND_ORE, ModBlocks.ECHO_ORE};
		Map<Block, Integer> counts = new LinkedHashMap<>();
		int roots = 0;
		int wet = 0;
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int[] centre : SiftSamples.PATCHES) {
			for (int dx = -SiftSamples.PATCH; dx <= SiftSamples.PATCH; dx++) {
				for (int dz = -SiftSamples.PATCH; dz <= SiftSamples.PATCH; dz++) {
					ChunkAccess chunk = level.getChunk(centre[0] + dx, centre[1] + dz);
					for (int x = 0; x < 16; x++) {
						for (int z = 0; z < 16; z++) {
							int top = chunk.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x, z);
							wet += chunk.getFluidState(p.set(x, top, z)).is(ModTags.ICHOR) ? 1 : 0;
							for (int y = level.getMinY(); y < 200; y++) {
								Block block = chunk.getBlockState(p.set(x, y, z)).getBlock();
								if (block == ModBlocks.TIDE_ROOTS) {
									roots++;
								}
								for (Block ore : ores) {
									if (block == ore) {
										counts.merge(ore, 1, Integer::sum);
									}
								}
							}
						}
					}
				}
			}
		}
		TheSift.LOGGER.info("Ore sample: {}; wild tide roots {} ({} columns topped with ichor)", counts, roots, wet);
		for (Block ore : ores) {
			if (ore != ModBlocks.ECHO_ORE) {
				helper.assertTrue(counts.getOrDefault(ore, 0) > 0, ore + " generates");
			}
		}
		helper.assertTrue(counts.getOrDefault(ModBlocks.HYMNSTONE_IRON_ORE, 0) > counts.getOrDefault(ModBlocks.HYMNSTONE_DIAMOND_ORE, 0),
				"iron is commoner than diamond");
		helper.succeed();
	}
}
