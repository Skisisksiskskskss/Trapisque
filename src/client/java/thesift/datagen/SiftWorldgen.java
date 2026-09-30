package thesift.datagen;

import java.util.List;
import java.util.Optional;

import net.minecraft.core.HolderGetter;
import net.minecraft.core.HolderSet;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.Registries;
import net.minecraft.data.worldgen.BootstrapContext;
import net.minecraft.data.worldgen.material.VanillaMaterialConditions;
import net.minecraft.data.worldgen.material.VanillaMaterialRules;
import net.minecraft.network.chat.Component;
import net.minecraft.tags.BlockTags;
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
		MaterialCondition underFloor = MaterialRules.getCondition(conditions, VanillaMaterialConditions.UNDER_FLOOR);
		// Placeholder blocks until block set I (WP-042).
		context.register(SiftKeys.MATERIAL_RULE, MaterialRules.sequence(
				MaterialRules.getRule(rules, VanillaMaterialRules.BEDROCK_FLOOR),
				MaterialRules.ifTrue(onFloor, MaterialRules.state(Blocks.MOSS_BLOCK.defaultBlockState())),
				MaterialRules.ifTrue(underFloor, MaterialRules.state(Blocks.DIRT.defaultBlockState())),
				MaterialRules.state(Blocks.STONE.defaultBlockState())));
	}

	static void noiseSettings(BootstrapContext<NoiseGeneratorSettings> context) {
		HolderGetter<NormalNoise> noises = context.lookup(Registries.NOISE);
		// Rolling hills: a height gradient around y 64–100 plus a broad 2D hill noise and a little 3D
		// variation. No sea and no aquifers (world.md §2).
		DensityFunction gradient = DensityFunctions.yClampedGradient(48, 128, 1.0F, -1.0F);
		DensityFunction hills = DensityFunctions.mul(DensityFunctions.constant(0.45F),
				DensityFunctions.noise(noises.getOrThrow(Noises.SURFACE), 0.6, 0.0));
		DensityFunction detail = DensityFunctions.mul(DensityFunctions.constant(0.12F),
				DensityFunctions.noise(noises.getOrThrow(Noises.SURFACE_SECONDARY), 2.0, 1.0));
		DensityFunction finalDensity = DensityFunctions.interpolated(DensityFunctions.add(gradient, DensityFunctions.add(hills, detail)), 4, 8);
		NoiseRouter router = new NoiseRouter(
				DensityFunctions.zero(), DensityFunctions.zero(), DensityFunctions.zero(), DensityFunctions.zero(),
				DensityFunctions.zero(), DensityFunctions.zero(), DensityFunctions.zero(), finalDensity);
		context.register(SiftKeys.NOISE, new NoiseGeneratorSettings(
				NoiseSettings.create(0, 256),
				Blocks.STONE.defaultBlockState(),
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
		BiomeGenerationSettings.Builder generation = new BiomeGenerationSettings.Builder(
				context.lookup(Registries.PLACED_FEATURE), context.lookup(Registries.CARVER));
		context.register(SiftKeys.SINGERS_MEADOW, new Biome.BiomeBuilder()
				.hasPrecipitation(false)
				.temperature(0.7F)
				.downfall(0.5F)
				.specialEffects(new BiomeSpecialEffects.Builder().waterColor(0x3FB8C8).build())
				.mobSpawnSettings(MobSpawnSettings.EMPTY)
				.generationSettings(generation.build())
				.build());
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
