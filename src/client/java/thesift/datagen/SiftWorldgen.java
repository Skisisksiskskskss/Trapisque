package thesift.datagen;

import thesift.registry.ModEntities;
import thesift.registry.ModSounds;
import net.minecraft.world.attribute.AmbientAdditionsSettings;
import net.minecraft.world.attribute.AmbientSounds;
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
import net.minecraft.world.level.levelgen.placement.SurfaceWaterDepthFilter;
import thesift.world.feature.DrapesDecorator;
import thesift.world.feature.HymnstoneSpireFeature;
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
import net.minecraft.world.level.biome.Climate;
import net.minecraft.world.level.biome.MultiNoiseBiomeSource;
import com.mojang.datafixers.util.Pair;
import net.minecraft.world.level.levelgen.NoiseRouterData;
import net.minecraft.world.level.levelgen.OverworldFunctionSet;
import net.minecraft.resources.ResourceKey;
import thesift.TheSift;
import net.minecraft.world.level.biome.MobSpawnSettings;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.dimension.DimensionType;
import net.minecraft.world.level.dimension.LevelStem;
import net.minecraft.world.level.levelgen.NoiseBasedChunkGenerator;
import net.minecraft.world.level.levelgen.NoiseGeneratorSettings;
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
import thesift.registry.ModParticles;
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
	private static final int THRIVE_SKY = 0x60D5C8; // sampled from the first look (owner rework)
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

	static final int SEA_LEVEL = 63;
	/** Added to vanilla's continentalness: oceans become lakes and inland seas, the rest is land. */
	private static final float CONTINENTS_SHIFT = 0.3F;
	/** The biome source's depth (vanilla's: 0 at the surface) at which the Hollows begin, as caves biomes. */
	static final float HOLLOWS_DEPTH = 0.2F;
	/** Hollows floors are healthy sculk where the patch noise is at least this; elsewhere hymnstone. */
	private static final double HOLLOWS_SOIL_PATCH = 0.05;
	/** Vanilla's terrain functions under our names; temperature, vegetation and erosion are vanilla's own. */
	static final OverworldFunctionSet<ResourceKey<DensityFunction>> SIFT_FUNCTIONS = new OverworldFunctionSet<>(
			NoiseRouterData.OVERWORLD_FUNCTIONS.temperature(),
			NoiseRouterData.OVERWORLD_FUNCTIONS.vegetation(),
			function("continents"),
			NoiseRouterData.OVERWORLD_FUNCTIONS.erosion(),
			function("offset"),
			function("factor"),
			function("jaggedness"),
			function("depth"),
			function("sloped_cheese"),
			function("preliminary_surface_level"),
			function("chunk_surface_level"),
			function("final_density"));

	private static ResourceKey<DensityFunction> function(String name) {
		return ResourceKey.create(Registries.DENSITY_FUNCTION, TheSift.id("sift/" + name));
	}

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
				// Ambient motes (rules.md): Trills drift up through Thrive, glow petals fall through Endure.
				.addTrack(EnvironmentAttributes.AMBIENT_PARTICLES, t -> t.setEasing(EasingType.CONSTANT)
						.addKeyframe(THRIVE, AmbientParticle.of(ModParticles.TRILL, 0.002F))
						.addKeyframe(RISING, List.of())
						.addKeyframe(ENDURE, AmbientParticle.of(ModParticles.GLOW_PETAL, 0.0012F))
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
				// Under ichor, the Sift's water (D-024): a clear turquoise haze, a little shorter than water's.
				.set(EnvironmentAttributes.WATER_FOG_COLOR, ARGB.vector3fFromRGB24(0x1F8FA8))
				.set(EnvironmentAttributes.WATER_FOG_END_DISTANCE, 64.0F)
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
				-64, // min_y: the Overworld's, so vanilla's terrain functions fit (owner playtest rework)
				384, // height
				384, // logical_height
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
		MaterialCondition notUnderwater = MaterialRules.getCondition(conditions, VanillaMaterialConditions.NOT_UNDERWATER);
		BlockState hymnstone = ModBlocks.HYMNSTONE.defaultBlockState();
		BlockState grass = ModBlocks.HEALTHY_SCULK.defaultBlockState();
		BlockState sand = ModBlocks.TIDE_SAND.defaultBlockState();
		// The Meadow (owner playtest rework): healthy sculk over hymnstone, as grass over stone and
		// nylium over netherrack (world.md §2–3); bare hymnstone on steep slopes; tide sand on the
		// shores and under ichor, as sand and gravel under water. In the Hollows the floors are
		// hymnstone with patches of healthy sculk: hunters spawn on soil only (system_hunt.md §7).
		MaterialCondition underFloor = MaterialRules.getCondition(conditions, VanillaMaterialConditions.UNDER_FLOOR);
		MaterialCondition shore = MaterialRules.not(MaterialRules.yBlockCheck(VerticalAnchor.absolute(SEA_LEVEL + 1), 0));
		MaterialRule surface = MaterialRules.sequence(
				MaterialRules.ifTrue(onFloor, MaterialRules.sequence(
						MaterialRules.ifTrue(MaterialRules.not(notUnderwater), MaterialRules.state(sand)),
						MaterialRules.ifTrue(shore, MaterialRules.state(sand)),
						MaterialRules.ifTrue(MaterialRules.steep(), MaterialRules.state(hymnstone)),
						MaterialRules.state(grass))),
				// A few blocks of soil under the grass and sand under the shores, as dirt and sand in vanilla.
				MaterialRules.ifTrue(underFloor, MaterialRules.sequence(
						MaterialRules.ifTrue(MaterialRules.not(notUnderwater), MaterialRules.state(sand)),
						MaterialRules.ifTrue(shore, MaterialRules.state(sand)),
						MaterialRules.ifTrue(MaterialRules.steep(), MaterialRules.state(hymnstone)),
						MaterialRules.state(ModBlocks.SIFT_SOIL.defaultBlockState()))));
		MaterialRule hollowsFloor = MaterialRules.ifTrue(MaterialRules.isBiome(context.lookup(Registries.BIOME), SiftKeys.SIFT_HOLLOWS),
				MaterialRules.ifTrue(onFloor, MaterialRules.ifTrue(MaterialRules.noiseCondition2d(Noises.PATCH, HOLLOWS_SOIL_PATCH), MaterialRules.state(grass))));
		context.register(SiftKeys.MATERIAL_RULE, MaterialRules.sequence(
				MaterialRules.getRule(rules, VanillaMaterialRules.BEDROCK_FLOOR),
				hollowsFloor,
				MaterialRules.ifTrue(MaterialRules.abovePreliminarySurface(), surface),
				MaterialRules.state(hymnstone)));
	}

	/**
	 * The terrain (owner playtest rework): vanilla's own Overworld terrain functions, registered again
	 * under our names with continentalness raised, so the Sift is land with lakes and rivers rather
	 * than half ocean. Hills, valleys, plateaus, caves and aquifers are vanilla's, so it reads as
	 * Minecraft; the teasers' rose spires stand on it as features.
	 */
	static void densityFunctions(BootstrapContext<DensityFunction> context) {
		HolderGetter<DensityFunction> functions = context.lookup(Registries.DENSITY_FUNCTION);
		HolderGetter<NormalNoise> noises = context.lookup(Registries.NOISE);
		DensityFunction continents = NoiseRouterData.registerAndWrap(context, SIFT_FUNCTIONS.continents(), DensityFunctions.cache(
				DensityFunctions.add(NoiseRouterData.getFunction(functions, NoiseRouterData.OVERWORLD_FUNCTIONS.continents()),
						DensityFunctions.constant(CONTINENTS_SHIFT))));
		DensityFunction jagged = DensityFunctions.noise(noises.getOrThrow(Noises.JAGGED), 1500.0, 0.0);
		NoiseRouterData.registerTerrainNoises(context, functions, noises, jagged, continents,
				NoiseRouterData.getFunction(functions, SIFT_FUNCTIONS.erosion()), SIFT_FUNCTIONS, false);
	}

	static void noiseSettings(BootstrapContext<NoiseGeneratorSettings> context) {
		HolderGetter<DensityFunction> functions = context.lookup(Registries.DENSITY_FUNCTION);
		HolderGetter<NormalNoise> noises = context.lookup(Registries.NOISE);
		context.register(SiftKeys.NOISE, new NoiseGeneratorSettings(
				NoiseSettings.create(-64, 384), // the Overworld's: y -64 to 320
				ModBlocks.HYMNSTONE.defaultBlockState(),
				ModBlocks.ICHOR.defaultBlockState(), // the Sift's water fills its seas, lakes and rivers (D-024)
				NoiseRouterData.overworld(functions, SIFT_FUNCTIONS),
				context.lookup(Registries.MATERIAL_RULE).getOrThrow(SiftKeys.MATERIAL_RULE),
				List.of(),
				SEA_LEVEL,
				false,
				Optional.of(NoiseRouterData.overworldAquifers(functions, noises, SIFT_FUNCTIONS)),
				false,
				NoiseGeneratorSettings.DebugFunctions.EMPTY));
	}

	static void biomes(BootstrapContext<Biome> context) {
		HolderGetter<PlacedFeature> placed = context.lookup(Registries.PLACED_FEATURE);
		BiomeGenerationSettings.Builder generation = new BiomeGenerationSettings.Builder(placed, context.lookup(Registries.CARVER));
		// Underground pools before basins, so a basin sees any pool that would open its wall and moves
		// on (the surface pools went with D-025: the Sift has lakes and rivers now).
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.ICHOR_POOLS_UNDERGROUND);
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.TIDE_BASINS_MEADOW);
		generation.addFeature(GenerationStep.Decoration.SURFACE_STRUCTURES, SiftFeatures.SPIRES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.TREES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.LONE_TREES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.GRASS_MEADOW);
		context.register(SiftKeys.SINGERS_MEADOW, new Biome.BiomeBuilder()
				.hasPrecipitation(false)
				.temperature(0.7F)
				.downfall(0.5F)
				.specialEffects(new BiomeSpecialEffects.Builder().waterColor(0x3FB8C8).build())
				// Wind through the songwood's flute holes, and now and then a far-off flute (items.md §6).
				// The flute is an "addition" (random, anywhere), not a "mood" (which needs darkness).
				.setAttribute(EnvironmentAttributes.AMBIENT_SOUNDS, new AmbientSounds(
						Optional.of(ModSounds.MEADOW_LOOP),
						Optional.empty(),
						List.of(new AmbientAdditionsSettings(ModSounds.MEADOW_MOOD, 0.0006))))
				// Blubs: about one group per 30 chunks at generation (vanilla's default is 0.1), mob_blub.md.
				.setAttribute(EnvironmentAttributes.CREATURE_WORLD_GEN_SPAWN_PROBABILITY, 0.03F)
				.mobSpawnSettings(new MobSpawnSettings.Builder().addSpawn(ModEntities.BLUB, 10, 2, 5).build())
				.generationSettings(generation.build())
				.build());
		// The Hollows: dark hymnstone caverns with ichor pools on their floors. No creatures; its hunters
		// and its drips-and-echoes ambience come with the rest of M2 (WP-064, WP-070).
		BiomeGenerationSettings.Builder hollows = new BiomeGenerationSettings.Builder(placed, context.lookup(Registries.CARVER));
		hollows.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.ICHOR_POOLS_UNDERGROUND);
		context.register(SiftKeys.SIFT_HOLLOWS, new Biome.BiomeBuilder()
				.hasPrecipitation(false)
				.temperature(0.7F)
				.downfall(0.5F)
				.specialEffects(new BiomeSpecialEffects.Builder().waterColor(0x3FB8C8).build())
				.mobSpawnSettings(new MobSpawnSettings.Builder().build())
				.generationSettings(hollows.build())
				.build());
	}

	@SuppressWarnings("deprecation") // LakeFeature: deprecated, yet still what vanilla's lava lakes use in 26.3
	static void features(BootstrapContext<Feature> context) {
		HolderGetter<BlockStateProvider> providers = context.lookup(Registries.BLOCK_STATE_PROVIDER);
		// Songwood, after the teasers' trees (owner rework): a tall dark trunk that forks into big,
		// cloud-like canopies of pale leaves, with drapes hanging from their undersides.
		context.register(SiftFeatures.SONGWOOD_TREE, new TreeFeature.Builder(
				BlockStateProvider.of(ModBlocks.SONGWOOD_LOG),
				new ForkingTrunkPlacer(6, 3, 2),
				BlockStateProvider.of(ModBlocks.SONGWOOD_LEAVES),
				new BlobFoliagePlacer(ConstantInt.of(3), ConstantInt.of(0), 3),
				new TwoLayersFeatureSize(1, 0, 2),
				Holder.direct(BlockStateProvider.of(ModBlocks.SIFT_SOIL)))
				.decorators(List.of(new DrapesDecorator(0.3F)))
				.ignoreVines()
				.build());
		context.register(SiftFeatures.HEALTHY_SCULK_GRASS_PATCH, new SimpleBlockFeature(new WeightedStateProvider(
				WeightedList.<BlockState>builder()
						.add(ModBlocks.HEALTHY_SCULK_GRASS.defaultBlockState(), 3)
						.add(ModBlocks.TALL_HEALTHY_SCULK_GRASS.defaultBlockState(), 2)
						.build())));
		context.register(SiftFeatures.TIDE_BASIN, TideBasinFeature.INSTANCE);
		context.register(SiftFeatures.HYMNSTONE_SPIRE, HymnstoneSpireFeature.INSTANCE);
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
		// Groves and open meadow (owner rework, after the first look's open grass and trees on a rise):
		// where the noise is high a chunk holds 4 trees, elsewhere none. Vanilla's treePlacement: never
		// under ichor (D-024).
		PlacementUtils.register(context, SiftFeatures.TREES_MEADOW, tree,
				NoiseThresholdCountPlacement.of(0.25, 0, 4),
				InSquarePlacement.spread(),
				SurfaceWaterDepthFilter.forMaxDepth(0),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome(),
				BlockPredicateFilter.forPredicate(BlockPredicate.wouldSurvive(ModBlocks.SONGWOOD_SAPLING)));
		// And now and then a lone tree out on the open grass.
		PlacementUtils.register(context, SiftFeatures.LONE_TREES_MEADOW, tree,
				RarityFilter.onAverageOnceEvery(6),
				InSquarePlacement.spread(),
				SurfaceWaterDepthFilter.forMaxDepth(0),
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
		// The teasers' rose spires: about one in five chunks, on the grass.
		PlacementUtils.register(context, SiftFeatures.SPIRES_MEADOW, features.getOrThrow(SiftFeatures.HYMNSTONE_SPIRE),
				RarityFilter.onAverageOnceEvery(5),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP,
				BiomeFilter.biome());
		placedBasinsAndPools(context);
	}

	static void placedBasinsAndPools(BootstrapContext<PlacedFeature> context) {
		HolderGetter<Feature> features = context.lookup(Registries.FEATURE);
		// One chance in two per chunk; the feature itself keeps only dry lows (lakes and rivers take the rest).
		// At the surface before the biome check: underground is the Hollows (WP-063).
		PlacementUtils.register(context, SiftFeatures.TIDE_BASINS_MEADOW, features.getOrThrow(SiftFeatures.TIDE_BASIN),
				RarityFilter.onAverageOnceEvery(2),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome());
		Holder<Feature> pool = features.getOrThrow(SiftFeatures.ICHOR_POOL);
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
				new NoiseBasedChunkGenerator(MultiNoiseBiomeSource.createFromList(new Climate.ParameterList<>(List.of(
						byDepth(-2.0F, HOLLOWS_DEPTH, biomes.getOrThrow(SiftKeys.SINGERS_MEADOW)),
						byDepth(HOLLOWS_DEPTH, 2.0F, biomes.getOrThrow(SiftKeys.SIFT_HOLLOWS))))),
						noise.getOrThrow(SiftKeys.NOISE))));
	}

	/** A biome chosen by depth below the surface alone (the other climate noises are zero in the Sift). */
	private static Pair<Climate.ParameterPoint, Holder<Biome>> byDepth(float from, float to, Holder<Biome> biome) {
		Climate.Parameter any = Climate.Parameter.span(-1.0F, 1.0F);
		return Pair.of(Climate.parameters(any, any, any, any, Climate.Parameter.span(from, to), any, 0.0F), biome);
	}
}
