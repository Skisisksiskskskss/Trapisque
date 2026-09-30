package thesift.world;

import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.clock.ClockTimeMarker;
import net.minecraft.world.clock.ClockTimeMarkers;
import net.minecraft.world.clock.WorldClock;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.dimension.DimensionType;
import net.minecraft.world.level.dimension.LevelStem;
import net.minecraft.world.level.levelgen.NoiseGeneratorSettings;
import net.minecraft.world.level.levelgen.material.rule.MaterialRule;
import net.minecraft.world.timeline.Timeline;

import thesift.TheSift;

/** Resource keys for the Sift dimension and its data-driven parts (D-019). */
public final class SiftKeys {
	public static final ResourceKey<Level> LEVEL = ResourceKey.create(Registries.DIMENSION, TheSift.id("the_sift"));
	public static final ResourceKey<LevelStem> LEVEL_STEM = ResourceKey.create(Registries.LEVEL_STEM, TheSift.id("the_sift"));
	public static final ResourceKey<DimensionType> DIMENSION_TYPE = ResourceKey.create(Registries.DIMENSION_TYPE, TheSift.id("the_sift"));
	public static final ResourceKey<NoiseGeneratorSettings> NOISE = ResourceKey.create(Registries.NOISE_SETTINGS, TheSift.id("sift"));
	public static final ResourceKey<MaterialRule> MATERIAL_RULE = ResourceKey.create(Registries.MATERIAL_RULE, TheSift.id("sift"));
	public static final ResourceKey<Biome> SINGERS_MEADOW = ResourceKey.create(Registries.BIOME, TheSift.id("singers_meadow"));

	public static final ResourceKey<WorldClock> TIDES_CLOCK = ResourceKey.create(Registries.WORLD_CLOCK, TheSift.id("tides"));
	public static final ResourceKey<Timeline> TIDES_TIMELINE = ResourceKey.create(Registries.TIMELINE, TheSift.id("tides"));

	public static final ResourceKey<ClockTimeMarker> THRIVE = marker("thrive");
	public static final ResourceKey<ClockTimeMarker> FLOW_RISING = marker("flow_rising");
	public static final ResourceKey<ClockTimeMarker> ENDURE = marker("endure");
	public static final ResourceKey<ClockTimeMarker> FLOW_FALLING = marker("flow_falling");

	private SiftKeys() {
	}

	private static ResourceKey<ClockTimeMarker> marker(String name) {
		return ResourceKey.create(ClockTimeMarkers.ROOT_ID, TheSift.id(name));
	}

	public static boolean isSift(Level level) {
		return level.dimension() == LEVEL;
	}
}
