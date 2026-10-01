package thesift.world;

import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;

import thesift.TheSift;

/** Keys of the Sift's world-generation features (bootstrapped in datagen). */
public final class SiftFeatures {
	public static final ResourceKey<Feature> SONGWOOD_TREE = ResourceKey.create(Registries.FEATURE, TheSift.id("songwood"));
	public static final ResourceKey<Feature> HEALTHY_SCULK_GRASS_PATCH = ResourceKey.create(Registries.FEATURE, TheSift.id("healthy_sculk_grass_patch"));
	public static final ResourceKey<PlacedFeature> SONGWOOD_CHECKED = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("songwood_checked"));
	public static final ResourceKey<PlacedFeature> TREES_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("trees_singers_meadow"));
	public static final ResourceKey<PlacedFeature> GRASS_MEADOW = ResourceKey.create(Registries.PLACED_FEATURE, TheSift.id("grass_singers_meadow"));

	private SiftFeatures() {
	}
}
