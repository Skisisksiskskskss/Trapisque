package thesift.world;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.registries.Registries;
import net.minecraft.world.level.Level;

import thesift.registry.ModAttributes;

/** The four phases of the Tide cycle on the {@code thesift:tides} clock (systems.md §1). */
public enum Tide {
	THRIVE(0),
	FLOW_RISING(12_000),
	ENDURE(15_000),
	FLOW_FALLING(27_000);

	/** One full cycle: 30 000 ticks, 25 minutes. */
	public static final int PERIOD_TICKS = 30_000;

	private final int startTick;

	Tide(int startTick) {
		this.startTick = startTick;
	}

	/** The tick within the cycle at which this Tide begins. */
	public int startTick() {
		return this.startTick;
	}

	public boolean isFlow() {
		return this == FLOW_RISING || this == FLOW_FALLING;
	}

	/** The Tide at a tick within the cycle. */
	public static Tide atCycleTick(long tick) {
		long t = Math.floorMod(tick, PERIOD_TICKS);
		if (t < FLOW_RISING.startTick) {
			return THRIVE;
		}
		if (t < ENDURE.startTick) {
			return FLOW_RISING;
		}
		if (t < FLOW_FALLING.startTick) {
			return ENDURE;
		}
		return FLOW_FALLING;
	}

	/** The current Tide in {@code level}, or {@code null} outside the Sift. */
	public static @Nullable Tide current(Level level) {
		int value = level.environmentAttributes().getDimensionValue(ModAttributes.TIDE);
		Tide[] values = values();
		return value >= 0 && value < values.length ? values[value] : null;
	}

	/**
	 * The Tide read straight from the {@code thesift:tides} clock. Clocks are server-wide and synced
	 * to every client, so this works from the Overworld too (the membrane shows the far side).
	 */
	public static @Nullable Tide fromClock(Level level) {
		return level.registryAccess().lookupOrThrow(Registries.WORLD_CLOCK).get(SiftKeys.TIDES_CLOCK)
				.map(clock -> atCycleTick(level.clockManager().getInstance(clock).totalTicks()))
				.orElse(null);
	}

	/** Total ticks on the {@code thesift:tides} clock, or 0 if it is missing. */
	public static long clockTicks(Level level) {
		return level.registryAccess().lookupOrThrow(Registries.WORLD_CLOCK).get(SiftKeys.TIDES_CLOCK)
				.map(clock -> level.clockManager().getInstance(clock).totalTicks())
				.orElse(0L);
	}
}
