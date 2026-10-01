package thesift.datagen;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.VerticalAnchor;
import net.minecraft.world.level.levelgen.feature.LakeFeature;
import net.minecraft.world.level.levelgen.heightproviders.UniformHeight;
import net.minecraft.world.level.levelgen.placement.EnvironmentScanPlacement;
import net.minecraft.world.level.levelgen.placement.HeightRangePlacement;
import net.minecraft.world.level.levelgen.placement.RarityFilter;
import net.minecraft.world.level.levelgen.placement.SurfaceRelativeThresholdFilter;
import thesift.world.feature.TideBasinFeature;
import java.util.List;
import java.util.Optional;

import net.minecraft.core.HolderGetter;
import net.minecraft.core.Holder;
import net.minecraft.data.worldgen.BlockStateProviders;
import net.minecraft.data.worldgen.placement.PlacementUtils;
import net.minecraft.util.random.WeightedList;
import net.minecraft.util.valueproviders.ConstantInt;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.levelgen.GenerationStep;
import net.minecraft.world.level.levelgen.blockpredicates.BlockPredicate;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.SimpleBlockFeature;
import net.minecraft.world.level.levelgen.feature.TreeFeature;
import net.minecraft.world.level.levelgen.feature.featuresize.TwoLayersFeatureSize;
import net.minecraft.world.level.levelgen.feature.foliageplacers.BlobFoliagePlacer;
import net.minecraft.world.level.levelgen.feature.stateproviders.BlockStateProvider;
import net.minecraft.world.level.levelgen.feature.stateproviders.WeightedStateProvider;
import net.minecraft.world.level.levelgen.feature.trunkplacers.ForkingTrunkPlacer;
import net.minecraft.world.level.levelgen.placement.BiomeFilter;
import net.minecraft.world.level.levelgen.placement.BlockPredicateFilter;
import net.minecraft.world.level.levelgen.placement.CountPlacement;
import net.minecraft.world.level.levelgen.placement.InSquarePlacement;
import net.minecraft.world.level.levelgen.placement.NoiseThresholdCountPlacement;
import net.minecraft.world.level.levelgen.placement.OffsetPlacement;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;
import net.minecraft.core.HolderSet;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.Registries;
import net.minecraft.data.worldgen.BootstrapContext;
import net.minecraft.data.worldgen.material.VanillaMaterialConditions;
import net.minecraft.data.worldgen.material.VanillaMaterialRules;
import net.minecraft.network.chat.Component;
import net.minecraft.util.ARGB;
import net.minecraft.util.EasingType;
import net.minecraft.util.TriState;
import net.minecraft.util.valueproviders.UniformInt;
import net.minecraft.world.attribute.AmbientParticle;
import net.minecraft.world.attribute.BedRule;
import net.minecraft.world.attribute.EnvironmentAttributeMap;
import net.minecraft.world.attribute.EnvironmentAttributes;
import net.minecraft.world.clock.WorldClock;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.biome.BiomeGenerationSettings;
import net.minecraft.world.level.biome.BiomeSpecialEffects;
import net.minecraft.world.level.biome.FixedBiomeSource;
import net.minecraft.world.level.biome.MobSpawnSettings;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.dimension.DimensionType;
import net.minecraft.world.level.dimension.LevelStem;
import net.minecraft.world.level.levelgen.NoiseBasedChunkGenerator;
import net.minecraft.world.level.levelgen.NoiseGeneratorSettings;
import net.minecraft.world.level.levelgen.NoiseRouter;
import net.minecraft.world.level.levelgen.NoiseSettings;
import net.minecraft.world.level.levelgen.Noises;
import net.minecraft.world.level.levelgen.densityfunction.DensityFunction;
import net.minecraft.world.level.levelgen.densityfunction.DensityFunctions;
import net.minecraft.world.level.levelgen.material.MaterialRules;
import net.minecraft.world.level.levelgen.material.condition.MaterialCondition;
import net.minecraft.world.level.levelgen.material.rule.MaterialRule;
import net.minecraft.world.level.levelgen.synth.NormalNoise;
import net.minecraft.world.timeline.Timeline;

import thesift.registry.ModAttributes;
import thesift.registry.ModBlocks;
import thesift.world.SiftFeatures;
import thesift.world.SiftKeys;
import thesift.world.Tide;

/**
 * Bootstraps for the Sift's data-driven registries (D-019): the Tide clock and timeline (rules.md,
 * systems.md §1), the dimension type, the Singer's Meadow biome, and the terrain.
 *
 * <p>WP-040 terrain is a placeholder with vanilla blocks; WP-042 replaces the material rule with block
 * set I and tunes the noise.
 */
final class SiftWorldgen {
	// Tide colours (rules.md: Thrive teal sky and pale fog, Flow peach-gold, Endure deep indigo).
	private static final int THRIVE_SKY = 0x5ACBC2;
	private static final int THRIVE_FOG = 0xBDE8E0;
	private static final int FLOW_SKY = 0xF0B47A;
	private static final int FLOW_FOG = 0xF3CFA5;
	private static final int ENDURE_SKY = 0x1E1B4B;
	private static final int ENDURE_FOG = 0x2B2758;

	private static final int THRIVE = Tide.THRIVE.startTick();
	private static final int RISING = Tide.FLOW_RISING.startTick();
	private static final int ENDURE = Tide.ENDURE.startTick();
	private static final int FALLING = Tide.FLOW_FALLING.startTick();
	private static final int MID_RISING = (RISING + ENDURE) / 2;
	private static final int MID_FALLING = (FALLING + Tide.PERIOD_TICKS) / 2;

	private SiftWorldgen() {
	}

	static void clocks(BootstrapContext<WorldClock> context) {
		context.register(SiftKeys.TIDES_CLOCK, new WorldClock());
	}

	static void timelines(BootstrapContext<Timeline> context) {
		HolderGetter<WorldClock> clocks = context.lookup(Registries.WORLD_CLOCK);
		context.register(SiftKeys.TIDES_TIMELINE, Timeline.builder(clocks.getOrThrow(SiftKeys.TIDES_CLOCK))
				.setPeriodTicks(Tide.PERIOD_TICKS)
				.addTimeMarker(SiftKeys.THRIVE, THRIVE, true)
				.addTimeMarker(SiftKeys.FLOW_RISING, RISING, true)
				.addTimeMarker(SiftKeys.ENDURE, ENDURE, true)
				.addTimeMarker(SiftKeys.FLOW_FALLING, FALLING, true)
				// Our gameplay values: steps, not blends.
				.addTrack(ModAttributes.TIDE, t -> t.setEasing(EasingType.CONSTANT)
						.addKeyframe(THRIVE, Tide.THRIVE.ordinal()).addKeyframe(RISING, Tide.FLOW_RISING.ordinal())
						.addKeyframe(ENDURE, Tide.ENDURE.ordinal()).addKeyframe(FALLING, Tide.FLOW_FALLING.ordinal()))
				.addTrack(ModAttributes.SOUL_FLOW, t -> t.setEasing(EasingType.CONSTANT)
						.addKeyframe(THRIVE, 1.0F).addKeyframe(RISING, 0.25F).addKeyframe(ENDURE, 0.0F).addKeyframe(FALLING, 0.25F))
				// Light: bright in Thrive, dark in Endure; Flow is the ramp.
				.addTrack(EnvironmentAttributes.SKY_LIGHT_LEVEL, t -> t
						.addKeyframe(THRIVE, 15.0F).addKeyframe(RISING, 15.0F).addKeyframe(ENDURE, 4.0F).addKeyframe(FALLING, 4.0F))
				.addTrack(EnvironmentAttributes.SKY_LIGHT_FACTOR, t -> t
						.addKeyframe(THRIVE, 1.0F).addKeyframe(RISING, 1.0F).addKeyframe(ENDURE, 0.24F).addKeyframe(FALLING, 0.24F))
				.addTrack(EnvironmentAttributes.SKY_COLOR, t -> t
						.addKeyframe(THRIVE, ARGB.vector3fFromRGB24(THRIVE_SKY)).addKeyframe(RISING, ARGB.vector3fFromRGB24(THRIVE_SKY))
						.addKeyframe(MID_RISING, ARGB.vector3fFromRGB24(FLOW_SKY)).addKeyframe(ENDURE, ARGB.vector3fFromRGB24(ENDURE_SKY))
						.addKeyframe(FALLING, ARGB.vector3fFromRGB24(ENDURE_SKY)).addKeyframe(MID_FALLING, ARGB.vector3fFromRGB24(FLOW_SKY)))
				.addTrack(EnvironmentAttributes.FOG_COLOR, t -> t
						.addKeyframe(THRIVE, ARGB.vector3fFromRGB24(THRIVE_FOG)).addKeyframe(RISING, ARGB.vector3fFromRGB24(THRIVE_FOG))
						.addKeyframe(MID_RISING, ARGB.vector3fFromRGB24(FLOW_FOG)).addKeyframe(ENDURE, ARGB.vector3fFromRGB24(ENDURE_FOG))
						.addKeyframe(FALLING, ARGB.vector3fFromRGB24(ENDURE_FOG)).addKeyframe(MID_FALLING, ARGB.vector3fFromRGB24(FLOW_FOG)))
				.addTrack(EnvironmentAttributes.CLOUD_COLOR, t -> t
						.addKeyframe(THRIVE, ARGB.vector4fFromARGB32(0xCCFFFFFF)).addKeyframe(RISING, ARGB.vector4fFromARGB32(0xCCFFFFFF))
						.addKeyframe(ENDURE, ARGB.vector4fFromARGB32(0xCC3A3570)).addKeyframe(FALLING, ARGB.vector4fFromARGB32(0xCC3A3570)))
				// Stars only in Endure; they wheel across the sky to show how much of Endure is left.
				.addTrack(EnvironmentAttributes.STAR_BRIGHTNESS, t -> t
						.addKeyframe(THRIVE, 0.0F).addKeyframe(MID_RISING, 0.0F).addKeyframe(ENDURE, 0.5F)
						.addKeyframe(FALLING, 0.5F).addKeyframe(MID_FALLING, 0.0F))
				.addTrack(EnvironmentAttributes.STAR_ANGLE, t -> t
						.addKeyframe(THRIVE, 0.0F).addKeyframe(ENDURE, 0.0F).addKeyframe(FALLING, 180.0F).addKeyframe(MID_FALLING, 180.0F))
				// Ambient motes: Thrive drifting motes, Endure soul motes (vanilla particles until the
				// WP-041 Trill art lands).
				.addTrack(EnvironmentAttributes.AMBIENT_PARTICLES, t -> t.setEasing(EasingType.CONSTANT)
						.addKeyframe(THRIVE, AmbientParticle.of(ParticleTypes.SPORE_BLOSSOM_AIR, 0.002F))
						.addKeyframe(RISING, List.of())
						.addKeyframe(ENDURE, AmbientParticle.of(ParticleTypes.SOUL, 0.0008F))
						.addKeyframe(FALLING, List.of()))
				// Night-bound vanilla behaviour follows Endure (rules.md).
				.addTrack(EnvironmentAttributes.BEES_STAY_IN_HIVE, t -> t
						.addKeyframe(THRIVE, false).addKeyframe(ENDURE, true).addKeyframe(FALLING, false))
				.addTrack(EnvironmentAttributes.EYEBLOSSOM_OPEN, t -> t
						.addKeyframe(THRIVE, TriState.FALSE).addKeyframe(ENDURE, TriState.TRUE).addKeyframe(FALLING, TriState.FALSE))
				.build());
	}

	static void dimensionTypes(BootstrapContext<DimensionType> context) {
		HolderGetter<net.minecraft.world.level.block.Block> blocks = context.lookup(Registries.BLOCK);
		HolderGetter<Timeline> timelines = context.lookup(Registries.TIMELINE);
		HolderGetter<WorldClock> clocks = context.lookup(Registries.WORLD_CLOCK);
		EnvironmentAttributeMap attributes = EnvironmentAttributeMap.builder()
				.set(ModAttributes.SIFT_LIFE, true)
				// No sun or moon: parked below the horizon (rules.md; a normal daylight detector reads 0).
				.set(EnvironmentAttributes.SUN_ANGLE, 180.0F)
				.set(EnvironmentAttributes.MOON_ANGLE, 180.0F)
				.set(EnvironmentAttributes.SUNRISE_SUNSET_COLOR, ARGB.vector4fFromARGB32(0))
				.set(EnvironmentAttributes.SKY_COLOR, ARGB.vector3fFromRGB24(THRIVE_SKY))
				.set(EnvironmentAttributes.FOG_COLOR, ARGB.vector3fFromRGB24(THRIVE_FOG))
				.set(EnvironmentAttributes.AMBIENT_LIGHT_COLOR, ARGB.vector3fFromRGB24(0xFF0A0A1A))
				// Beds set spawn; nobody sleeps (both bed kinds, or straw beds would sleep "when dark").
				.set(EnvironmentAttributes.BED_RULE, new BedRule(BedRule.Rule.NEVER, BedRule.Rule.ALWAYS, false, false,
						Optional.of(Component.translatable("thesift.bed.no_sleep"))))
				.set(EnvironmentAttributes.STRAW_BED_RULE, new BedRule(BedRule.Rule.NEVER, BedRule.Rule.NEVER, false, true,
						Optional.of(Component.translatable("thesift.bed.no_sleep"))))
				.set(EnvironmentAttributes.RESPAWN_ANCHOR_WORKS, false)
				.set(EnvironmentAttributes.CAN_START_RAID, false)
				.set(EnvironmentAttributes.CREAKING_ACTIVE, false)
				.set(EnvironmentAttributes.CAT_WAKING_UP_GIFT_CHANCE, 0.0F)
				.set(EnvironmentAttributes.SURFACE_SLIME_SPAWN_CHANCE, 0.0F)
				.set(EnvironmentAttributes.MONSTERS_BURN, false)
				.build();
		context.register(SiftKeys.DIMENSION_TYPE, new DimensionType(
				false, // has_fixed_time: the Tides are a clock
				true, // has_skylight
				false, // has_ceiling (weather is handled by the D-008 mixin)
				false, // has_ender_dragon_fight
				1.0, // coordinate_scale: no travel shortcut
				0, // min_y
				256, // height
				256, // logical_height
				blocks.getOrThrow(BlockTags.INFINIBURN_OVERWORLD),
				0.05F, // ambient_light: Endure is dark but readable
				new DimensionType.MonsterSettings(UniformInt.of(0, 7), 0),
				DimensionType.Skybox.OVERWORLD,
				net.minecraft.world.level.CardinalLighting.Type.DEFAULT,
				attributes,
				HolderSet.direct(timelines.getOrThrow(SiftKeys.TIDES_TIMELINE)),
				Optional.of(clocks.getOrThrow(SiftKeys.TIDES_CLOCK))));
	}

	static void materialRules(BootstrapContext<MaterialRule> context) {
		HolderGetter<MaterialRule> rules = context.lookup(Registries.MATERIAL_RULE);
		HolderGetter<MaterialCondition> conditions = context.lookup(Registries.MATERIAL_CONDITION);
		MaterialCondition onFloor = MaterialRules.getCondition(conditions, VanillaMaterialConditions.ON_FLOOR);
		// Healthy sculk over hymnstone, like nylium over netherrack (world.md §2–3).
		context.register(SiftKeys.MATERIAL_RULE, MaterialRules.sequence(
				MaterialRules.getRule(rules, VanillaMaterialRules.BEDROCK_FLOOR),
				MaterialRules.ifTrue(onFloor, MaterialRules.state(ModBlocks.HEALTHY_SCULK.defaultBlockState())),
				MaterialRules.state(ModBlocks.HYMNSTONE.defaultBlockState())));
	}

	static void noiseSettings(BootstrapContext<NoiseGeneratorSettings> context) {
		HolderGetter<NormalNoise> noises = context.lookup(Registries.NOISE);
		// Rolling hills: a height gradient around y 64–100 plus a broad 2D hill noise and a little 3D
		// variation. No sea and no aquifers (world.md §2).
		DensityFunction gradient = DensityFunctions.yClampedGradient(40, 136, 1.0F, -1.0F);
		// Rolling hills: a broad 2D swell, a closer 2D ripple, and a little 3D variation for overhangs.
		DensityFunction swell = DensityFunctions.mul(DensityFunctions.constant(0.40F),
				DensityFunctions.noise(noises.getOrThrow(Noises.SURFACE), 2.0, 0.0));
		DensityFunction ripple = DensityFunctions.mul(DensityFunctions.constant(0.10F),
				DensityFunctions.noise(noises.getOrThrow(Noises.SURFACE_SECONDARY), 3.5, 0.0));
		DensityFunction detail = DensityFunctions.mul(DensityFunctions.constant(0.03F),
				DensityFunctions.noise(noises.getOrThrow(Noises.SURFACE_SECONDARY), 8.0, 2.0));
		DensityFunction finalDensity = DensityFunctions.interpolated(
				DensityFunctions.add(gradient, DensityFunctions.add(swell, DensityFunctions.add(ripple, detail))), 4, 8);
		NoiseRouter router = new NoiseRouter(
				DensityFunctions.zero(), DensityFunctions.zero(), DensityFunctions.zero(), DensityFunctions.zero(),
				DensityFunctions.zero(), DensityFunctions.zero(), DensityFunctions.zero(), finalDensity);
		context.register(SiftKeys.NOISE, new NoiseGeneratorSettings(
				NoiseSettings.create(0, 256),
				ModBlocks.HYMNSTONE.defaultBlockState(),
				Blocks.AIR.defaultBlockState(),
				router,
				context.lookup(Registries.MATERIAL_RULE).getOrThrow(SiftKeys.MATERIAL_RULE),
				List.of(),
				-64, // sea_level below the world: no sea
				false,
				Optional.empty(), // no aquifers
				false,
				NoiseGeneratorSettings.DebugFunctions.EMPTY));
	}

	static void biomes(BootstrapContext<Biome> context) {
		HolderGetter<PlacedFeature> placed = context.lookup(Registries.PLACED_FEATURE);
		BiomeGenerationSettings.Builder generation = new BiomeGenerationSettings.Builder(placed, context.lookup(Registries.CARVER));
		// Basins first, so pools and trees grow around them rather than being cut in half.
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.TIDE_BASINS_MEADOW);
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.ICHOR_POOLS_SURFACE);
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.ICHOR_POOLS_UNDERGROUND);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.TREES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.GRASS_MEADOW);
		context.register(SiftKeys.SINGERS_MEADOW, new Biome.BiomeBuilder()
				.hasPrecipitation(false)
				.temperature(0.7F)
				.downfall(0.5F)
				.specialEffects(new BiomeSpecialEffects.Builder().waterColor(0x3FB8C8).build())
				.mobSpawnSettings(MobSpawnSettings.EMPTY)
				.generationSettings(generation.build())
				.build());
	}

	@SuppressWarnings("deprecation") // LakeFeature: deprecated, yet still what vanilla's lava lakes use in 26.3
	static void features(BootstrapContext<Feature> context) {
		HolderGetter<BlockStateProvider> providers = context.lookup(Registries.BLOCK_STATE_PROVIDER);
		// Songwood: a forked trunk with puffy white crowns, so it reads apart from cherry and pale oak.
		context.register(SiftFeatures.SONGWOOD_TREE, new TreeFeature.Builder(
				BlockStateProvider.of(ModBlocks.SONGWOOD_LOG),
				new ForkingTrunkPlacer(5, 2, 2),
				BlockStateProvider.of(ModBlocks.SONGWOOD_LEAVES),
				new BlobFoliagePlacer(ConstantInt.of(2), ConstantInt.of(0), 3),
				new TwoLayersFeatureSize(1, 0, 2),
				providers.getOrThrow(BlockStateProviders.SOIL_BENEATH_TREE))
				.ignoreVines()
				.build());
		context.register(SiftFeatures.HEALTHY_SCULK_GRASS_PATCH, new SimpleBlockFeature(new WeightedStateProvider(
				WeightedList.<BlockState>builder()
						.add(ModBlocks.HEALTHY_SCULK_GRASS.defaultBlockState(), 6)
						.add(ModBlocks.TALL_HEALTHY_SCULK_GRASS.defaultBlockState(), 1)
						.build())));
		context.register(SiftFeatures.TIDE_BASIN, TideBasinFeature.INSTANCE);
		// Static pools that don't follow the tide: vanilla's lava lake with ichor in hymnstone.
		context.register(SiftFeatures.ICHOR_POOL, new LakeFeature(
				BlockStateProvider.holderOf(ModBlocks.ICHOR),
				BlockStateProvider.holderOf(ModBlocks.HYMNSTONE),
				BlockPredicate.alwaysTrue(),
				BlockPredicate.not(BlockPredicate.matchesTag(BlockTags.FEATURES_CANNOT_REPLACE)),
				BlockPredicate.not(BlockPredicate.matchesTag(BlockTags.LAVA_POOL_STONE_CANNOT_REPLACE))));
	}

	static void placedFeatures(BootstrapContext<PlacedFeature> context) {
		HolderGetter<Feature> features = context.lookup(Registries.FEATURE);
		Holder<Feature> tree = features.getOrThrow(SiftFeatures.SONGWOOD_TREE);
		PlacementUtils.register(context, SiftFeatures.SONGWOOD_CHECKED, tree, PlacementUtils.filteredByBlockSurvival(ModBlocks.SONGWOOD_SAPLING));
		// Groves, not forest: about one tree per chunk on average, clumped by chance.
		// Vanilla's treePlacement minus its water-depth filter: the Sift has no water.
		PlacementUtils.register(context, SiftFeatures.TREES_MEADOW, tree,
				PlacementUtils.countExtra(0, 0.5F, 2),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome(),
				BlockPredicateFilter.forPredicate(BlockPredicate.wouldSurvive(ModBlocks.SONGWOOD_SAPLING)));
		PlacementUtils.register(context, SiftFeatures.GRASS_MEADOW, features.getOrThrow(SiftFeatures.HEALTHY_SCULK_GRASS_PATCH),
				NoiseThresholdCountPlacement.of(-0.8, 5, 10),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
				BiomeFilter.biome(),
				CountPlacement.of(32),
				OffsetPlacement.ofTriangle(7, 3),
				BlockPredicateFilter.forPredicate(BlockPredicate.ONLY_IN_AIR_PREDICATE));
		placedBasinsAndPools(context);
	}

	static void placedBasinsAndPools(BootstrapContext<PlacedFeature> context) {
		HolderGetter<Feature> features = context.lookup(Registries.FEATURE);
		// One chance in three per chunk; the feature itself keeps only the lows.
		PlacementUtils.register(context, SiftFeatures.TIDE_BASINS_MEADOW, features.getOrThrow(SiftFeatures.TIDE_BASIN),
				RarityFilter.onAverageOnceEvery(3),
				BiomeFilter.biome());
		Holder<Feature> pool = features.getOrThrow(SiftFeatures.ICHOR_POOL);
		// "Many pools of ichor, fracturing the terrain": far commoner than vanilla's surface lava lakes (1 in 200).
		PlacementUtils.register(context, SiftFeatures.ICHOR_POOLS_SURFACE, pool,
				RarityFilter.onAverageOnceEvery(8),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
				BiomeFilter.biome());
		PlacementUtils.register(context, SiftFeatures.ICHOR_POOLS_UNDERGROUND, pool,
				RarityFilter.onAverageOnceEvery(5),
				InSquarePlacement.spread(),
				HeightRangePlacement.of(UniformHeight.of(VerticalAnchor.absolute(8), VerticalAnchor.absolute(90))),
				EnvironmentScanPlacement.scanningFor(Direction.DOWN,
						BlockPredicate.allOf(BlockPredicate.not(BlockPredicate.ONLY_IN_AIR_PREDICATE), BlockPredicate.insideWorld(new BlockPos(0, -5, 0))), 32),
				SurfaceRelativeThresholdFilter.of(Heightmap.Types.OCEAN_FLOOR_WG, Integer.MIN_VALUE, -5),
				BiomeFilter.biome());
	}

	static void levelStems(BootstrapContext<LevelStem> context) {
		HolderGetter<DimensionType> types = context.lookup(Registries.DIMENSION_TYPE);
		HolderGetter<Biome> biomes = context.lookup(Registries.BIOME);
		HolderGetter<NoiseGeneratorSettings> noise = context.lookup(Registries.NOISE_SETTINGS);
		context.register(SiftKeys.LEVEL_STEM, new LevelStem(types.getOrThrow(SiftKeys.DIMENSION_TYPE),
				new NoiseBasedChunkGenerator(new FixedBiomeSource(biomes.getOrThrow(SiftKeys.SINGERS_MEADOW)),
						noise.getOrThrow(SiftKeys.NOISE))));
	}
}
