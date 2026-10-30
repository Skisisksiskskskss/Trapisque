package thesift.world;

import net.fabricmc.fabric.api.entity.event.v1.ServerEntityLevelChangeEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.Registries;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.clock.WorldClock;

import thesift.TheSift;

/**
 * Starts the Tide clock at the first crossing. Vanilla creates every world clock unpaused
 * ({@code ServerClockManager}), so the pause has to come from code (systems.md §1, WP-040).
 */
public final class TideClock {
	private TideClock() {
	}

	public static void init() {
		ServerLifecycleEvents.SERVER_STARTED.register(TideClock::pauseUntilFirstCrossing);
		ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL.register((player, origin, destination) -> onPlayerInLevel(player));
		// A player who logs in already standing in the Sift (e.g. after /execute in) also counts.
		ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> onPlayerInLevel(handler.player));
	}

	public static Holder<WorldClock> clock(MinecraftServer server) {
		return server.registryAccess().lookupOrThrow(Registries.WORLD_CLOCK).getOrThrow(SiftKeys.TIDES_CLOCK);
	}

	public static SiftState state(MinecraftServer server) {
		return server.getDataStorage().computeIfAbsent(SiftState.TYPE);
	}

	private static void pauseUntilFirstCrossing(MinecraftServer server) {
		if (!state(server).firstCrossingDone()) {
			Holder<WorldClock> clock = clock(server);
			server.clockManager().setTotalTicks(clock, Tide.THRIVE.startTick());
			server.clockManager().setPaused(clock, true);
		}
	}

	private static void onPlayerInLevel(ServerPlayer player) {
		if (!SiftKeys.isSift(player.level())) {
			return;
		}
		MinecraftServer server = player.level().getServer();
		SiftState state = state(server);
		if (!state.firstCrossingDone()) {
			state.markFirstCrossingDone();
			server.clockManager().setPaused(clock(server), false);
			TheSift.LOGGER.info("First crossing into the Sift: the Tide clock starts");
		}
	}
}
