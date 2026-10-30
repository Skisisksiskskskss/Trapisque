package thesift.test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;

import net.fabricmc.fabric.api.entity.event.v1.EntitySleepEvents;
import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.stats.Stat;
import net.minecraft.stats.Stats;
import net.minecraft.world.attribute.EnvironmentAttributes;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.biome.Climate;
import net.minecraft.world.level.gamerules.GameRules;
import net.minecraft.world.level.levelgen.densityfunction.SamplerContext;
import net.minecraft.world.level.saveddata.WeatherData;

import thesift.TheSift;
import thesift.registry.ModAttributes;
import thesift.world.SiftKeys;
import thesift.world.Tide;
import thesift.world.TideClock;

/** WP-040: the Sift dimension follows rules.md (weather, scope, beds, Endure rest, first-crossing clock). */
public final class SiftDimensionTest {
	private static final String SIFT = "thesift:the_sift";

	@GameTest(dimension = SIFT)
	public void siftHasNoWeather(GameTestHelper helper) {
		helper.assertFalse(helper.getLevel().canHaveWeather(), "the Sift must not have weather (D-008)");
		helper.succeed();
	}

	/** An extra open-sky level must not speed up the Overworld's shared weather timers. */
	@GameTest(maxTicks = 60)
	public void overworldWeatherAdvancesOncePerTick(GameTestHelper helper) {
		MinecraftServer server = helper.getLevel().getServer();
		helper.assertTrue(server.getLevel(SiftKeys.LEVEL) != null, "the Sift level is loaded");
		server.getGameRules().set(GameRules.ADVANCE_WEATHER, true, server);
		WeatherData weather = server.getWeatherData();
		weather.setClearWeatherTime(10_000);
		helper.runAfterDelay(20, () -> {
			helper.assertValueEqual(weather.getClearWeatherTime(), 10_000 - 20, "clear weather time after 20 ticks");
			helper.succeed();
		});
	}

	@GameTest(dimension = SIFT)
	public void siftLifeIsTrueInTheSift(GameTestHelper helper) {
		helper.assertTrue(helper.getLevel().environmentAttributes().getDimensionValue(ModAttributes.SIFT_LIFE), "sift_life in the Sift");
		helper.succeed();
	}

	@GameTest
	public void siftLifeIsFalseInTheOverworld(GameTestHelper helper) {
		helper.assertFalse(helper.getLevel().environmentAttributes().getDimensionValue(ModAttributes.SIFT_LIFE), "sift_life in the Overworld");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void nobodySleepsInTheSift(GameTestHelper helper) {
		Level level = helper.getLevel();
		helper.assertFalse(level.environmentAttributes().getDimensionValue(EnvironmentAttributes.BED_RULE).canSleep(level), "beds refuse sleep");
		helper.assertTrue(level.environmentAttributes().getDimensionValue(EnvironmentAttributes.BED_RULE).canSetSpawn(level), "beds set spawn");
		helper.assertFalse(level.environmentAttributes().getDimensionValue(EnvironmentAttributes.STRAW_BED_RULE).canSleep(level), "straw beds refuse sleep");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void tideClockIsPausedBeforeTheFirstCrossing(GameTestHelper helper) {
		MinecraftServer server = helper.getLevel().getServer();
		helper.assertFalse(TideClock.state(server).firstCrossingDone(), "no player has crossed in the test server");
		helper.assertTrue(server.clockManager().getInstance(TideClock.clock(server)).isPaused(), "the Tide clock is paused");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void tideFollowsTheClock(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		MinecraftServer server = level.getServer();
		for (Tide tide : Tide.values()) {
			server.clockManager().setTotalTicks(TideClock.clock(server), tide.startTick() + 10);
			helper.assertValueEqual(Tide.current(level), tide, "Tide at tick " + (tide.startTick() + 10));
		}
		server.clockManager().setTotalTicks(TideClock.clock(server), Tide.THRIVE.startTick());
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void restingInEndureResetsThePhantomTimer(GameTestHelper helper) {
		ServerPlayer player = restingPlayer(helper);
		Stat<?> stat = Stats.CUSTOM.get(Stats.TIME_SINCE_REST);
		helper.assertValueEqual(player.getStats().getValue(stat), 0, "time since rest after resting in Endure");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void noRestWithMonstersNear(GameTestHelper helper) {
		helper.spawn(EntityTypes.ZOMBIE, new BlockPos(2, 1, 2));
		ServerPlayer player = restingPlayer(helper);
		Stat<?> stat = Stats.CUSTOM.get(Stats.TIME_SINCE_REST);
		helper.assertValueEqual(player.getStats().getValue(stat), 100_000, "time since rest with a monster near");
		helper.succeed();
	}

	/** A survival player with a high phantom timer uses a bed during Endure. */
	private static ServerPlayer restingPlayer(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		MinecraftServer server = level.getServer();
		server.clockManager().setTotalTicks(TideClock.clock(server), Tide.ENDURE.startTick() + 100);
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		BlockPos bed = helper.absolutePos(new BlockPos(1, 1, 1));
		player.setPos(bed.getX() + 0.5, bed.getY(), bed.getZ() + 0.5);
		player.getStats().setValue(player, Stats.CUSTOM.get(Stats.TIME_SINCE_REST), 100_000);
		EntitySleepEvents.ALLOW_SETTING_SPAWN.invoker().allowSettingSpawn(player, bed);
		server.clockManager().setTotalTicks(TideClock.clock(server), Tide.THRIVE.startTick());
		return player;
	}

	/**
	 * Owner playtest 6: Singer's Meadow took far too much of the Sift. Each surface biome's share of a
	 * 16 384-block square, from the biome source alone (one sample per 64 blocks, high enough that none is
	 * the Hollows): no biome over two fifths, none under a seventh. The climate samples are written to
	 * biome_climate.csv (humidity, erosion) for tuning the layout.
	 */
	@GameTest(dimension = SIFT)
	public void surfaceBiomesShareTheSift(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		var randomState = level.getChunkSource().randomState();
		var resolver = level.getChunkSource().getGenerator().getBiomeSource().createUncachedResolver(randomState);
		Climate.Sampler sampler = randomState.createClimateSampler(SamplerContext.EMPTY_UNCACHED);
		Map<String, Integer> counts = new TreeMap<>();
		StringBuilder climate = new StringBuilder("humidity,erosion\n");
		int samples = 0;
		for (int i = 0; i < 256; i++) {
			for (int j = 0; j < 256; j++) {
				int qx = (i - 128) * 16;
				int qz = (j - 128) * 16;
				String name = resolver.getNoiseBiome(qx, 75, qz).unwrapKey().map(k -> k.identifier().getPath()).orElse("?");
				counts.merge(name, 1, Integer::sum);
				Climate.TargetPoint point = sampler.sample(qx, 75, qz);
				climate.append(Climate.unquantizeCoord(point.humidity())).append(',').append(Climate.unquantizeCoord(point.erosion())).append('\n');
				samples++;
			}
		}
		StringBuilder shares = new StringBuilder();
		for (Map.Entry<String, Integer> e : counts.entrySet()) {
			shares.append(String.format(Locale.ROOT, "%s %.1f%%  ", e.getKey(), 100.0 * e.getValue() / samples));
		}
		TheSift.LOGGER.info("Surface biome shares: {}", shares);
		try {
			Files.writeString(Path.of("biome_climate.csv"), climate);
		} catch (IOException e) {
			TheSift.LOGGER.warn("Couldn't write the climate samples", e);
		}
		for (String biome : new String[] {"singers_meadow", "ichor_flats", "carapace", "lullaby_hills"}) {
			double share = counts.getOrDefault(biome, 0) / (double) samples;
			helper.assertTrue(share <= 0.4 && share >= 1.0 / 7, biome + " has " + Math.round(share * 100) + "% of the surface");
		}
		helper.succeed();
	}
}
