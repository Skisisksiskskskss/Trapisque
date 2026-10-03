package thesift.world;

import java.util.List;

import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;

import thesift.TheSift;

/** Keys of the Sift's world-generation features (bootstrapped in datagen). */
public final class SiftFeatures {
	public static final ResourceKey<Feature> SONGWOOD_TREE = ResourceKey.create(Registries.FEATURE, TheSift.id("songwood"));
	/** Owner playtest 2 (D-026): a tall songwood whose trunk scatters into many small canopies, as a big oak. */
	public static final ResourceKey<Feature> TALL_SONGWOOD_TREE = ResourceKey.create(Registries.FEATURE, TheSift.id("tall_songwood"));
	public static final ResourceKey<Feature> MEADOW_TREES = ResourceKey.create(Registries.FEATURE, TheSift.id("meadow_trees"));
	public static final ResourceKey<Feature> ICHOR_FLATS_POOLS = ResourceKey.create(Registries.FEATURE, TheSift.id("ichor_flats_pools"));
	public static final ResourceKey<PlacedFeature> TALL_SONGWOOD_CHECKED = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("tall_songwood_checked"));
	public static final ResourceKey<PlacedFeature> TREES_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("trees_ichor_flats"));
	public static final ResourceKey<PlacedFeature> POOLS_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("pools_ichor_flats"));
	public static final ResourceKey<PlacedFeature> PONDS_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("ichor_ponds"));
	public static final ResourceKey<PlacedFeature> SPIRES_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("hymnstone_spires_ichor_flats"));
	// Flora II (block_flora_ii.md).
	public static final ResourceKey<Feature> ENDURE_BLOOMS = ResourceKey.create(Registries.FEATURE, TheSift.id("endure_blooms"));
	public static final ResourceKey<Feature> LUMEN_BLOOM = ResourceKey.create(Registries.FEATURE, TheSift.id("lumen_bloom"));
	public static final ResourceKey<Feature> CHIME_BELL_PATCH = ResourceKey.create(Registries.FEATURE, TheSift.id("chime_bell_patch"));
	public static final ResourceKey<Feature> GLOWCAP_PATCH = ResourceKey.create(Registries.FEATURE, TheSift.id("glowcap_patch"));
	public static final ResourceKey<PlacedFeature> ENDURE_BLOOMS_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("endure_blooms_singers_meadow"));
	public static final ResourceKey<PlacedFeature> ENDURE_BLOOMS_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("endure_blooms_ichor_flats"));
	public static final ResourceKey<PlacedFeature> LUMEN_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("lumen_bloom_singers_meadow"));
	public static final ResourceKey<PlacedFeature> LUMEN_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("lumen_bloom_ichor_flats"));
	public static final ResourceKey<PlacedFeature> LUMEN_HOLLOWS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("lumen_bloom_sift_hollows"));
	public static final ResourceKey<PlacedFeature> CHIME_BELLS_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("chime_bells_singers_meadow"));
	public static final ResourceKey<PlacedFeature> CHIME_BELLS_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("chime_bells_ichor_flats"));
	public static final ResourceKey<PlacedFeature> GLOWCAPS_HOLLOWS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("glowcaps_sift_hollows"));
	// Owner playtest 3 (D-029): the Flats' lights, and their own plant.
	public static final ResourceKey<Feature> ICHOR_LILY_PATCH = ResourceKey.create(Registries.FEATURE, TheSift.id("ichor_lily_patch"));
	public static final ResourceKey<PlacedFeature> ICHOR_LILIES_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("ichor_lilies_ichor_flats"));
	public static final ResourceKey<PlacedFeature> GLOWCAPS_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("glowcaps_ichor_flats"));
	public static final ResourceKey<PlacedFeature> GRASS_FLATS = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("grass_ichor_flats"));
	public static final ResourceKey<Feature> HEALTHY_SCULK_GRASS_PATCH = ResourceKey.create(Registries.FEATURE, TheSift.id("healthy_sculk_grass_patch"));
	public static final ResourceKey<Feature> TIDE_BASIN = ResourceKey.create(Registries.FEATURE, TheSift.id("tide_basin"));
	public static final ResourceKey<Feature> HYMNSTONE_SPIRE = ResourceKey.create(Registries.FEATURE, TheSift.id("hymnstone_spire"));
	public static final ResourceKey<PlacedFeature> SPIRES_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("hymnstone_spires_singers_meadow"));
	public static final ResourceKey<Feature> ICHOR_POOL = ResourceKey.create(Registries.FEATURE, TheSift.id("ichor_pool"));
	/** A surface pond: the lake feature with a sandy rim (owner playtest 2: "the max it should be is like a pond"). */
	public static final ResourceKey<Feature> ICHOR_POND = ResourceKey.create(Registries.FEATURE, TheSift.id("ichor_pond"));
	public static final ResourceKey<PlacedFeature> SONGWOOD_CHECKED = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("songwood_checked"));
	public static final ResourceKey<PlacedFeature> TREES_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("trees_singers_meadow"));
	public static final ResourceKey<PlacedFeature> LONE_TREES_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("lone_trees_singers_meadow"));
	public static final ResourceKey<PlacedFeature> GRASS_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("grass_singers_meadow"));

	public static final ResourceKey<PlacedFeature> TIDE_BASINS_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("tide_basins_singers_meadow"));
	public static final ResourceKey<PlacedFeature> ICHOR_POOLS_UNDERGROUND = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("ichor_pools_underground"));

	private SiftFeatures() {
	}

	// Ores (survival_sift.md §4): the Overworld's veins, in hymnstone; echo ore in the Hollows only.
	public static final ResourceKey<Feature> ORE_COAL = feature("ore_hymnstone_coal");
	public static final ResourceKey<Feature> ORE_COAL_BURIED = feature("ore_hymnstone_coal_buried");
	public static final ResourceKey<Feature> ORE_COPPER = feature("ore_hymnstone_copper");
	public static final ResourceKey<Feature> ORE_IRON = feature("ore_hymnstone_iron");
	public static final ResourceKey<Feature> ORE_IRON_SMALL = feature("ore_hymnstone_iron_small");
	public static final ResourceKey<Feature> ORE_GOLD_BURIED = feature("ore_hymnstone_gold_buried");
	public static final ResourceKey<Feature> ORE_REDSTONE = feature("ore_hymnstone_redstone");
	public static final ResourceKey<Feature> ORE_LAPIS = feature("ore_hymnstone_lapis");
	public static final ResourceKey<Feature> ORE_LAPIS_BURIED = feature("ore_hymnstone_lapis_buried");
	public static final ResourceKey<Feature> ORE_DIAMOND_SMALL = feature("ore_hymnstone_diamond_small");
	public static final ResourceKey<Feature> ORE_DIAMOND_LARGE = feature("ore_hymnstone_diamond_large");
	public static final ResourceKey<Feature> ORE_DIAMOND_BURIED = feature("ore_hymnstone_diamond_buried");
	public static final ResourceKey<Feature> ORE_EMERALD = feature("ore_hymnstone_emerald");
	public static final ResourceKey<Feature> ORE_ECHO = feature("ore_echo");
	public static final ResourceKey<PlacedFeature> ORE_COAL_UPPER = placed("ore_hymnstone_coal_upper");
	public static final ResourceKey<PlacedFeature> ORE_COAL_LOWER = placed("ore_hymnstone_coal_lower");
	public static final ResourceKey<PlacedFeature> ORE_IRON_UPPER = placed("ore_hymnstone_iron_upper");
	public static final ResourceKey<PlacedFeature> ORE_IRON_MIDDLE = placed("ore_hymnstone_iron_middle");
	public static final ResourceKey<PlacedFeature> ORE_IRON_SMALL_PLACED = placed("ore_hymnstone_iron_small");
	public static final ResourceKey<PlacedFeature> ORE_GOLD = placed("ore_hymnstone_gold");
	public static final ResourceKey<PlacedFeature> ORE_REDSTONE_PLACED = placed("ore_hymnstone_redstone");
	public static final ResourceKey<PlacedFeature> ORE_REDSTONE_LOWER = placed("ore_hymnstone_redstone_lower");
	public static final ResourceKey<PlacedFeature> ORE_DIAMOND = placed("ore_hymnstone_diamond");
	public static final ResourceKey<PlacedFeature> ORE_DIAMOND_LARGE_PLACED = placed("ore_hymnstone_diamond_large");
	public static final ResourceKey<PlacedFeature> ORE_DIAMOND_BURIED_PLACED = placed("ore_hymnstone_diamond_buried");
	public static final ResourceKey<PlacedFeature> ORE_LAPIS_PLACED = placed("ore_hymnstone_lapis");
	public static final ResourceKey<PlacedFeature> ORE_LAPIS_BURIED_PLACED = placed("ore_hymnstone_lapis_buried");
	public static final ResourceKey<PlacedFeature> ORE_COPPER_PLACED = placed("ore_hymnstone_copper");
	public static final ResourceKey<PlacedFeature> ORE_EMERALD_PLACED = placed("ore_hymnstone_emerald");
	public static final ResourceKey<PlacedFeature> ORE_ECHO_PLACED = placed("ore_echo");
	/** Every biome's ores, in one order (feature order must agree across biomes); emerald and echo are added where they belong. */
	public static final List<ResourceKey<PlacedFeature>> ORES = List.of(ORE_COAL_UPPER, ORE_COAL_LOWER, ORE_IRON_UPPER, ORE_IRON_MIDDLE,
			ORE_IRON_SMALL_PLACED, ORE_GOLD, ORE_REDSTONE_PLACED, ORE_REDSTONE_LOWER, ORE_DIAMOND, ORE_DIAMOND_LARGE_PLACED,
			ORE_DIAMOND_BURIED_PLACED, ORE_LAPIS_PLACED, ORE_LAPIS_BURIED_PLACED, ORE_COPPER_PLACED);
	// Wild tide roots, grown, on the sand at the ichor's edge (survival_sift.md §1).
	public static final ResourceKey<Feature> TIDE_ROOTS_PATCH = feature("tide_roots");
	public static final ResourceKey<PlacedFeature> TIDE_ROOTS_SHORES = placed("tide_roots_shores");

	// The Carapace and Lullaby Hills (D-035).
	public static final ResourceKey<Feature> HUSK_FOSSIL = feature("husk_fossil");
	public static final ResourceKey<PlacedFeature> HUSK_FOSSILS_CARAPACE = placed("husk_fossils_carapace");
	public static final ResourceKey<Feature> CARAPACE_GRASS = feature("carapace_grass");
	public static final ResourceKey<PlacedFeature> CARAPACE_GRASS_PATCHES = placed("carapace_grass_patches");
	public static final ResourceKey<PlacedFeature> CHIME_BELLS_HILLS = placed("chime_bells_lullaby_hills");
	public static final ResourceKey<PlacedFeature> LUMEN_HILLS = placed("lumen_lullaby_hills");

	private static ResourceKey<Feature> feature(String name) {
		return ResourceKey.create(Registries.FEATURE, TheSift.id(name));
	}

	private static ResourceKey<PlacedFeature> placed(String name) {
		return ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id(name));
	}
}
