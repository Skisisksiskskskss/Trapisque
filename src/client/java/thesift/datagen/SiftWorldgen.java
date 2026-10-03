package thesift.datagen;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.OptionalInt;

import com.mojang.datafixers.util.Pair;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.Holder;
import net.minecraft.core.HolderGetter;
import net.minecraft.core.HolderSet;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.Registries;
import net.minecraft.data.worldgen.BlockStateProviders;
import net.minecraft.data.worldgen.BootstrapContext;
import net.minecraft.data.worldgen.material.VanillaMaterialConditions;
import net.minecraft.data.worldgen.material.VanillaMaterialRules;
import net.minecraft.data.worldgen.placement.PlacementUtils;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceKey;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.ARGB;
import net.minecraft.util.EasingType;
import net.minecraft.util.TriState;
import net.minecraft.util.random.WeightedList;
import net.minecraft.util.valueproviders.ConstantInt;
import net.minecraft.util.valueproviders.IntProvider;
import net.minecraft.util.valueproviders.UniformInt;
import net.minecraft.util.valueproviders.WeightedListInt;
import net.minecraft.world.attribute.AmbientAdditionsSettings;
import net.minecraft.world.attribute.AmbientParticle;
import net.minecraft.world.attribute.AmbientSounds;
import net.minecraft.world.attribute.BedRule;
import net.minecraft.world.attribute.EnvironmentAttributeMap;
import net.minecraft.world.attribute.EnvironmentAttributes;
import net.minecraft.world.clock.WorldClock;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.biome.BiomeGenerationSettings;
import net.minecraft.world.level.biome.BiomeSpecialEffects;
import net.minecraft.world.level.biome.Climate;
import net.minecraft.world.level.biome.MobSpawnSettings;
import net.minecraft.world.level.biome.MultiNoiseBiomeSource;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.dimension.DimensionType;
import net.minecraft.world.level.dimension.LevelStem;
import net.minecraft.world.level.levelgen.GenerationStep;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.NoiseBasedChunkGenerator;
import net.minecraft.world.level.levelgen.NoiseGeneratorSettings;
import net.minecraft.world.level.levelgen.NoiseRouterData;
import net.minecraft.world.level.levelgen.NoiseSettings;
import net.minecraft.world.level.levelgen.Noises;
import net.minecraft.world.level.levelgen.OverworldFunctionSet;
import net.minecraft.world.level.levelgen.VerticalAnchor;
import net.minecraft.world.level.levelgen.blockpredicates.BlockPredicate;
import net.minecraft.world.level.levelgen.densityfunction.DensityFunction;
import net.minecraft.world.level.levelgen.densityfunction.DensityFunctions;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.LakeFeature;
import net.minecraft.world.level.levelgen.feature.SimpleBlockFeature;
import net.minecraft.world.level.levelgen.feature.TreeFeature;
import net.minecraft.world.level.levelgen.feature.WeightedRandomSelectorFeature;
import net.minecraft.world.level.levelgen.feature.featuresize.TwoLayersFeatureSize;
import net.minecraft.world.level.levelgen.feature.foliageplacers.CherryFoliagePlacer;
import net.minecraft.world.level.levelgen.feature.foliageplacers.FancyFoliagePlacer;
import net.minecraft.world.level.levelgen.feature.stateproviders.BlockStateProvider;
import net.minecraft.world.level.levelgen.feature.stateproviders.SimpleStateProvider;
import net.minecraft.world.level.levelgen.feature.stateproviders.WeightedStateProvider;
import net.minecraft.world.level.levelgen.feature.trunkplacers.CherryTrunkPlacer;
import net.minecraft.world.level.levelgen.feature.trunkplacers.FancyTrunkPlacer;
import net.minecraft.world.level.levelgen.heightproviders.UniformHeight;
import net.minecraft.world.level.levelgen.material.MaterialRules;
import net.minecraft.world.level.levelgen.material.condition.MaterialCondition;
import net.minecraft.world.level.levelgen.material.rule.MaterialRule;
import net.minecraft.world.level.levelgen.placement.BiomeFilter;
import net.minecraft.world.level.levelgen.placement.BlockPredicateFilter;
import net.minecraft.world.level.levelgen.placement.CountPlacement;
import net.minecraft.world.level.levelgen.placement.EnvironmentScanPlacement;
import net.minecraft.world.level.levelgen.placement.HeightRangePlacement;
import net.minecraft.world.level.levelgen.placement.InSquarePlacement;
import net.minecraft.world.level.levelgen.placement.NoiseBasedCountPlacement;
import net.minecraft.world.level.levelgen.placement.NoiseThresholdCountPlacement;
import net.minecraft.world.level.levelgen.placement.OffsetPlacement;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;
import net.minecraft.world.level.levelgen.placement.RarityFilter;
import net.minecraft.world.level.levelgen.placement.SurfaceRelativeThresholdFilter;
import net.minecraft.world.level.levelgen.placement.SurfaceWaterDepthFilter;
import net.minecraft.world.level.levelgen.synth.NormalNoise;
import net.minecraft.world.timeline.Timeline;

import thesift.TheSift;
import thesift.registry.ModAttributes;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModParticles;
import thesift.registry.ModSounds;
import thesift.world.SiftFeatures;
import thesift.world.SiftKeys;
import thesift.world.Tide;
import thesift.world.feature.DrapesDecorator;
import thesift.world.feature.HymnstoneSpireFeature;
import thesift.world.feature.IchorFlatsFeature;
import thesift.world.feature.LumenBloomFeature;
import thesift.world.feature.EndureBloomsFeature;
import thesift.world.feature.TideBasinFeature;

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

	/**
	 * No sea (owner playtest 2, D-026): "the max it should be is like a pond". With the sea level at the
	 * world's floor no ocean or river fills; the Sift's ichor is ponds, the Ichor Flats' pools, tide
	 * basins and the aquifers' cave pools.
	 */
	static final int SEA_LEVEL = -64;
	/** The Ichor Flats: wet lowlands where vegetation (humidity) is high and erosion flattens the land. */
	private static final float FLATS_HUMIDITY = 0.15F;
	private static final float FLATS_EROSION = -0.2F;
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
				// D-028 (owner: shaders went pitch black with both bodies parked below the horizon): the sun
				// crosses the sky through Thrive and sets in rising Flow; the moon rides through Endure. One turn
				// per cycle, so shader packs light Thrive as day and Endure as a moonlit night.
				.addTrack(EnvironmentAttributes.SUN_ANGLE, t -> t
						.addKeyframe(THRIVE, 300.0F).addKeyframe(5_000, 360.0F).addKeyframe(5_000, 0.0F))
				.addTrack(EnvironmentAttributes.MOON_ANGLE, t -> t
						.addKeyframe(THRIVE, 120.0F).addKeyframe(20_000, 360.0F).addKeyframe(20_000, 0.0F))
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
				ModBlocks.ICHOR.defaultBlockState(), // the Sift's water, in the aquifers' cave pools (D-024, D-026)
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
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.PONDS_MEADOW);
		generation.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.TIDE_BASINS_MEADOW);
		generation.addFeature(GenerationStep.Decoration.SURFACE_STRUCTURES, SiftFeatures.SPIRES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.TREES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.LONE_TREES_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.LUMEN_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.ENDURE_BLOOMS_MEADOW);
		generation.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.CHIME_BELLS_MEADOW);
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
				// Nesters (mob_nester.md, Spawning): monsters, 1-2, Endure only by their spawn rule.
				.mobSpawnSettings(new MobSpawnSettings.Builder().addSpawn(ModEntities.BLUB, 10, 2, 5).addSpawn(ModEntities.NESTER, 60, 1, 2).build())
				.generationSettings(generation.build())
				.build());
		// The Ichor Flats (owner playtest 2, D-026): the Meadow's wet lowlands, where shallow, blotchy
		// ichor lies among the grass as a mangrove swamp's water lies among its roots, with more trees
		// and fewer spires. No tide basins: the flats are already wet.
		BiomeGenerationSettings.Builder flats = new BiomeGenerationSettings.Builder(placed, context.lookup(Registries.CARVER));
		flats.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.POOLS_FLATS);
		flats.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.ICHOR_POOLS_UNDERGROUND);
		flats.addFeature(GenerationStep.Decoration.SURFACE_STRUCTURES, SiftFeatures.SPIRES_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.TREES_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.LUMEN_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.ENDURE_BLOOMS_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.CHIME_BELLS_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.ICHOR_LILIES_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.GLOWCAPS_FLATS);
		flats.addFeature(GenerationStep.Decoration.VEGETAL_DECORATION, SiftFeatures.GRASS_FLATS);
		context.register(SiftKeys.ICHOR_FLATS, new Biome.BiomeBuilder()
				.hasPrecipitation(false)
				.temperature(0.7F)
				.downfall(0.8F)
				.specialEffects(new BiomeSpecialEffects.Builder().waterColor(0x3FB8C8).build())
				.setAttribute(EnvironmentAttributes.AMBIENT_SOUNDS, new AmbientSounds(
						Optional.of(ModSounds.MEADOW_LOOP),
						Optional.empty(),
						List.of(new AmbientAdditionsSettings(ModSounds.MEADOW_MOOD, 0.0006))))
				.setAttribute(EnvironmentAttributes.CREATURE_WORLD_GEN_SPAWN_PROBABILITY, 0.03F)
				.mobSpawnSettings(new MobSpawnSettings.Builder().addSpawn(ModEntities.BLUB, 10, 2, 5).build())
				.generationSettings(flats.build())
				.build());
		// The Hollows: dark hymnstone caverns with ichor pools on their floors. No creatures; its hunters
		// and its drips-and-echoes ambience come with the rest of M2 (WP-064, WP-070).
		BiomeGenerationSettings.Builder hollows = new BiomeGenerationSettings.Builder(placed, context.lookup(Registries.CARVER));
		hollows.addFeature(GenerationStep.Decoration.LAKES, SiftFeatures.ICHOR_POOLS_UNDERGROUND);
		hollows.addFeature(GenerationStep.Decoration.UNDERGROUND_DECORATION, SiftFeatures.GLOWCAPS_HOLLOWS);
		hollows.addFeature(GenerationStep.Decoration.UNDERGROUND_DECORATION, SiftFeatures.LUMEN_HOLLOWS);
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
		// Songwood, after the teasers' trees (owner playtest 2, D-026: "more complex shapes and
		// canopies"): a tall dark trunk that branches into one to three rounded canopies of pale leaves,
		// as a cherry tree branches, with drapes hanging from their undersides.
		Holder<BlockStateProvider> soil = Holder.direct(BlockStateProvider.of(ModBlocks.SIFT_SOIL));
		context.register(SiftFeatures.SONGWOOD_TREE, new TreeFeature.Builder(
				BlockStateProvider.of(ModBlocks.SONGWOOD_LOG),
				new CherryTrunkPlacer(8, 2, 1,
						new WeightedListInt(WeightedList.<IntProvider>builder().add(ConstantInt.of(1), 1).add(ConstantInt.of(2), 2).add(ConstantInt.of(3), 2).build()),
						UniformInt.of(2, 5),
						UniformInt.of(-5, -3),
						UniformInt.of(-1, 1)),
				BlockStateProvider.of(ModBlocks.SONGWOOD_LEAVES),
				new CherryFoliagePlacer(ConstantInt.of(4), ConstantInt.of(0), ConstantInt.of(5), 0.25F, 0.5F, 0.2F, 0.33F),
				new TwoLayersFeatureSize(1, 0, 2),
				soil)
				.decorators(List.of(new DrapesDecorator(0.3F)))
				.ignoreVines()
				.build());
		// And the tall kind: a trunk that scatters into many small canopies on its branches, as a big
		// oak does, so a grove has more than one silhouette.
		context.register(SiftFeatures.TALL_SONGWOOD_TREE, new TreeFeature.Builder(
				BlockStateProvider.of(ModBlocks.SONGWOOD_LOG),
				new FancyTrunkPlacer(9, 7, 0),
				BlockStateProvider.of(ModBlocks.SONGWOOD_LEAVES),
				new FancyFoliagePlacer(ConstantInt.of(2), ConstantInt.of(4), 4),
				new TwoLayersFeatureSize(0, 0, 0, OptionalInt.of(4)),
				soil)
				.decorators(List.of(new DrapesDecorator(0.25F)))
				.ignoreVines()
				.build());
		HolderGetter<PlacedFeature> placed = context.lookup(Registries.PLACED_FEATURE);
		context.register(SiftFeatures.MEADOW_TREES, new WeightedRandomSelectorFeature(WeightedList.<Holder<PlacedFeature>>builder()
				.add(placed.getOrThrow(SiftFeatures.SONGWOOD_CHECKED), 3)
				.add(placed.getOrThrow(SiftFeatures.TALL_SONGWOOD_CHECKED), 2)
				.build()));
		context.register(SiftFeatures.ICHOR_FLATS_POOLS, IchorFlatsFeature.INSTANCE);
		context.register(SiftFeatures.HEALTHY_SCULK_GRASS_PATCH, new SimpleBlockFeature(new WeightedStateProvider(
				WeightedList.<BlockState>builder()
						.add(ModBlocks.HEALTHY_SCULK_GRASS.defaultBlockState(), 3)
						.add(ModBlocks.TALL_HEALTHY_SCULK_GRASS.defaultBlockState(), 2)
						.build())));
		context.register(SiftFeatures.TIDE_BASIN, TideBasinFeature.INSTANCE);
		// Flora II (block_flora_ii.md).
		context.register(SiftFeatures.ENDURE_BLOOMS, EndureBloomsFeature.INSTANCE);
		context.register(SiftFeatures.LUMEN_BLOOM, LumenBloomFeature.INSTANCE);
		context.register(SiftFeatures.CHIME_BELL_PATCH, new SimpleBlockFeature(new SimpleStateProvider(ModBlocks.CHIME_BELL_FLOWER.defaultBlockState())));
		context.register(SiftFeatures.GLOWCAP_PATCH, new SimpleBlockFeature(new SimpleStateProvider(ModBlocks.GLOWCAP.defaultBlockState())));
		context.register(SiftFeatures.ICHOR_LILY_PATCH, new SimpleBlockFeature(new SimpleStateProvider(ModBlocks.ICHOR_LILY.defaultBlockState())));
		context.register(SiftFeatures.HYMNSTONE_SPIRE, HymnstoneSpireFeature.INSTANCE);
		// Ponds on the surface (D-026): the same lake with a rim of tide sand where its walls are open.
		context.register(SiftFeatures.ICHOR_POND, new LakeFeature(
				BlockStateProvider.holderOf(ModBlocks.ICHOR),
				BlockStateProvider.holderOf(ModBlocks.TIDE_SAND),
				BlockPredicate.alwaysTrue(),
				BlockPredicate.not(BlockPredicate.matchesTag(BlockTags.FEATURES_CANNOT_REPLACE)),
				BlockPredicate.not(BlockPredicate.matchesTag(BlockTags.LAVA_POOL_STONE_CANNOT_REPLACE))));
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
		PlacementUtils.register(context, SiftFeatures.TALL_SONGWOOD_CHECKED, features.getOrThrow(SiftFeatures.TALL_SONGWOOD_TREE),
				PlacementUtils.filteredByBlockSurvival(ModBlocks.SONGWOOD_SAPLING));
		Holder<Feature> trees = features.getOrThrow(SiftFeatures.MEADOW_TREES);
		// Woods that thicken and thin out across the land (owner playtest 2: the groves looked
		// synthetic): vanilla's flower noise sets each chunk's count, 0 to 5, so a wood fades into
		// open meadow instead of stopping at a hard edge. Never under ichor (D-024).
		PlacementUtils.register(context, SiftFeatures.TREES_MEADOW, trees,
				NoiseBasedCountPlacement.of(5, 90.0, -0.3),
				InSquarePlacement.spread(),
				SurfaceWaterDepthFilter.forMaxDepth(0),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome());
		// The flats are wooded more evenly, with trees standing among the pools.
		PlacementUtils.register(context, SiftFeatures.TREES_FLATS, trees,
				NoiseBasedCountPlacement.of(4, 60.0, 0.4),
				InSquarePlacement.spread(),
				SurfaceWaterDepthFilter.forMaxDepth(0),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome());
		// And now and then a lone tree out on the open grass.
		PlacementUtils.register(context, SiftFeatures.LONE_TREES_MEADOW, trees,
				RarityFilter.onAverageOnceEvery(6),
				InSquarePlacement.spread(),
				SurfaceWaterDepthFilter.forMaxDepth(0),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome(),
				BlockPredicateFilter.forPredicate(BlockPredicate.wouldSurvive(ModBlocks.SONGWOOD_SAPLING)));
		for (ResourceKey<PlacedFeature> grass : List.of(SiftFeatures.GRASS_MEADOW, SiftFeatures.GRASS_FLATS)) {
			PlacementUtils.register(context, grass, features.getOrThrow(SiftFeatures.HEALTHY_SCULK_GRASS_PATCH),
					NoiseThresholdCountPlacement.of(-0.8, 5, 10),
					InSquarePlacement.spread(),
					PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
					BiomeFilter.biome(),
					CountPlacement.of(32),
					OffsetPlacement.ofTriangle(7, 3),
					BlockPredicateFilter.forPredicate(BlockPredicate.ONLY_IN_AIR_PREDICATE));
		}
		// Flora II (block_flora_ii.md, BALANCE "Flora II"): bells in patches, blooms on shores, lumen rare.
		for (var bells : List.of(Map.entry(SiftFeatures.CHIME_BELLS_MEADOW, 4), Map.entry(SiftFeatures.CHIME_BELLS_FLATS, 6))) {
			PlacementUtils.register(context, bells.getKey(), features.getOrThrow(SiftFeatures.CHIME_BELL_PATCH),
					RarityFilter.onAverageOnceEvery(bells.getValue()),
					InSquarePlacement.spread(),
					PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
					BiomeFilter.biome(),
					CountPlacement.of(12),
					OffsetPlacement.ofTriangle(6, 2),
					BlockPredicateFilter.forPredicate(BlockPredicate.ONLY_IN_AIR_PREDICATE));
		}
		for (var blooms : List.of(SiftFeatures.ENDURE_BLOOMS_MEADOW, SiftFeatures.ENDURE_BLOOMS_FLATS)) {
			PlacementUtils.register(context, blooms, features.getOrThrow(SiftFeatures.ENDURE_BLOOMS),
					RarityFilter.onAverageOnceEvery(16),
					InSquarePlacement.spread(),
					PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
					BiomeFilter.biome());
		}
		// The Flats are lit twice as often (owner playtest 3, D-029).
		for (var lumen : List.of(Map.entry(SiftFeatures.LUMEN_MEADOW, 12), Map.entry(SiftFeatures.LUMEN_FLATS, 6))) {
			PlacementUtils.register(context, lumen.getKey(), features.getOrThrow(SiftFeatures.LUMEN_BLOOM),
					RarityFilter.onAverageOnceEvery(lumen.getValue()),
					InSquarePlacement.spread(),
					PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
					BiomeFilter.biome());
		}
		// Ichor lilies on the Flats' blots (as lily pads on a swamp's water: the patch only takes where
		// the lily survives, on an ichor source), and glowcaps in the Flats' grass, as a swamp's mushrooms.
		PlacementUtils.register(context, SiftFeatures.ICHOR_LILIES_FLATS, features.getOrThrow(SiftFeatures.ICHOR_LILY_PATCH),
				CountPlacement.of(2),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
				BiomeFilter.biome(),
				CountPlacement.of(14),
				OffsetPlacement.ofTriangle(6, 1),
				BlockPredicateFilter.forPredicate(BlockPredicate.ONLY_IN_AIR_PREDICATE));
		PlacementUtils.register(context, SiftFeatures.GLOWCAPS_FLATS, features.getOrThrow(SiftFeatures.GLOWCAP_PATCH),
				RarityFilter.onAverageOnceEvery(3),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
				BiomeFilter.biome(),
				CountPlacement.of(10),
				OffsetPlacement.ofTriangle(4, 1),
				BlockPredicateFilter.forPredicate(BlockPredicate.ONLY_IN_AIR_PREDICATE));
		// Cave floors: scan down to solid ground, then step up into the air above it.
		PlacementUtils.register(context, SiftFeatures.LUMEN_HOLLOWS, features.getOrThrow(SiftFeatures.LUMEN_BLOOM),
				RarityFilter.onAverageOnceEvery(24),
				InSquarePlacement.spread(),
				HeightRangePlacement.uniform(VerticalAnchor.absolute(-56), VerticalAnchor.absolute(40)),
				EnvironmentScanPlacement.scanningFor(Direction.DOWN, BlockPredicate.solid(), BlockPredicate.ONLY_IN_AIR_PREDICATE, 12),
				OffsetPlacement.vertical(ConstantInt.of(1)),
				BiomeFilter.biome());
		PlacementUtils.register(context, SiftFeatures.GLOWCAPS_HOLLOWS, features.getOrThrow(SiftFeatures.GLOWCAP_PATCH),
				CountPlacement.of(16),
				InSquarePlacement.spread(),
				HeightRangePlacement.uniform(VerticalAnchor.absolute(-56), VerticalAnchor.absolute(40)),
				EnvironmentScanPlacement.scanningFor(Direction.DOWN, BlockPredicate.solid(), BlockPredicate.ONLY_IN_AIR_PREDICATE, 12),
				OffsetPlacement.vertical(ConstantInt.of(1)),
				BiomeFilter.biome());
		// The teasers' rose spires: about one in five chunks, on the grass.
		PlacementUtils.register(context, SiftFeatures.SPIRES_MEADOW, features.getOrThrow(SiftFeatures.HYMNSTONE_SPIRE),
				RarityFilter.onAverageOnceEvery(5),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP,
				BiomeFilter.biome());
		PlacementUtils.register(context, SiftFeatures.SPIRES_FLATS, features.getOrThrow(SiftFeatures.HYMNSTONE_SPIRE),
				RarityFilter.onAverageOnceEvery(14),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP,
				BiomeFilter.biome());
		placedBasinsAndPools(context);
	}

	static void placedBasinsAndPools(BootstrapContext<PlacedFeature> context) {
		HolderGetter<Feature> features = context.lookup(Registries.FEATURE);
		// One chance in five per chunk (owner playtest 2: more made a grid); the feature itself keeps only
		// dry lows. At the surface before the biome check: underground is the Hollows (WP-063).
		PlacementUtils.register(context, SiftFeatures.TIDE_BASINS_MEADOW, features.getOrThrow(SiftFeatures.TIDE_BASIN),
				RarityFilter.onAverageOnceEvery(5),
				PlacementUtils.HEIGHTMAP_OCEAN_FLOOR,
				BiomeFilter.biome());
		// Ponds (D-026): about one chunk in six, at the surface.
		PlacementUtils.register(context, SiftFeatures.PONDS_MEADOW, features.getOrThrow(SiftFeatures.ICHOR_POND),
				RarityFilter.onAverageOnceEvery(6),
				InSquarePlacement.spread(),
				PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
				BiomeFilter.biome());
		// The flats' pools: one pass per chunk, from its corner's surface (the biome check needs the
		// surface: underground is the Hollows); the feature checks each column's biome itself.
		PlacementUtils.register(context, SiftFeatures.POOLS_FLATS, features.getOrThrow(SiftFeatures.ICHOR_FLATS_POOLS),
				PlacementUtils.HEIGHTMAP_WORLD_SURFACE,
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
						surface(-2.0F, FLATS_HUMIDITY, -2.0F, 2.0F, biomes.getOrThrow(SiftKeys.SINGERS_MEADOW)),
						surface(FLATS_HUMIDITY, 2.0F, -2.0F, FLATS_EROSION, biomes.getOrThrow(SiftKeys.SINGERS_MEADOW)),
						surface(FLATS_HUMIDITY, 2.0F, FLATS_EROSION, 2.0F, biomes.getOrThrow(SiftKeys.ICHOR_FLATS)),
						byDepth(HOLLOWS_DEPTH, 2.0F, biomes.getOrThrow(SiftKeys.SIFT_HOLLOWS))))),
						noise.getOrThrow(SiftKeys.NOISE))));
	}

	/** A biome chosen by depth below the surface alone. */
	private static Pair<Climate.ParameterPoint, Holder<Biome>> byDepth(float from, float to, Holder<Biome> biome) {
		Climate.Parameter any = Climate.Parameter.span(-2.0F, 2.0F);
		return Pair.of(Climate.parameters(any, any, any, any, Climate.Parameter.span(from, to), any, 0.0F), biome);
	}

	/** A surface biome (above the Hollows) chosen by humidity (vegetation) and erosion. */
	private static Pair<Climate.ParameterPoint, Holder<Biome>> surface(float humidityFrom, float humidityTo,
			float erosionFrom, float erosionTo, Holder<Biome> biome) {
		Climate.Parameter any = Climate.Parameter.span(-2.0F, 2.0F);
		return Pair.of(Climate.parameters(any, Climate.Parameter.span(humidityFrom, humidityTo), any,
				Climate.Parameter.span(erosionFrom, erosionTo), Climate.Parameter.span(-2.0F, HOLLOWS_DEPTH), any, 0.0F), biome);
	}
}
