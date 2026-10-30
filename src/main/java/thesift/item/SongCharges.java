package thesift.item;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.player.Player;

import thesift.registry.ModAttachments;
import thesift.world.SiftKeys;
import thesift.world.Tide;

/**
 * Song charges (items.md §1.2): each player has 3, kept on death, shared by every horn they hold.
 * They recharge only in the Sift: Thrive at twice Flow's rate, Endure not at all; one charge takes about
 * half a Thrive (6 000 ticks).
 */
public final class SongCharges {
	public static final int MAX = 3;
	/** Recharge units per charge: half a Thrive at Thrive's 2 units a tick. */
	public static final int UNITS = 12_000;
	private static final int EVERY = 20;

	private SongCharges() {
	}

	public static void init() {
		ServerTickEvents.END_SERVER_TICK.register(SongCharges::tick);
	}

	public static int charges(Player player) {
		return player.getAttachedOrElse(ModAttachments.SONG_CHARGES, MAX);
	}

	/** Spends one charge if there is one. */
	public static boolean spend(Player player) {
		int charges = charges(player);
		if (charges <= 0) {
			return false;
		}
		player.setAttached(ModAttachments.SONG_CHARGES, charges - 1);
		return true;
	}

	private static void tick(MinecraftServer server) {
		if (server.getTickCount() % EVERY != 0) {
			return;
		}
		for (ServerPlayer player : server.getPlayerList().getPlayers()) {
			if (!SiftKeys.isSift(player.level()) || charges(player) >= MAX) {
				continue;
			}
			Tide tide = Tide.current(player.level());
			int rate = tide == Tide.THRIVE ? 2 : tide.isFlow() ? 1 : 0;
			if (rate == 0) {
				continue;
			}
			int progress = player.getAttachedOrElse(ModAttachments.SONG_PROGRESS, 0) + rate * EVERY;
			if (progress >= UNITS) {
				progress -= UNITS;
				player.setAttached(ModAttachments.SONG_CHARGES, charges(player) + 1);
			}
			player.setAttached(ModAttachments.SONG_PROGRESS, progress);
		}
	}
}
