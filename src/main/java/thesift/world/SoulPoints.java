package thesift.world;

import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.player.Player;

/**
 * Experience as souls (rules.md E): reading and taking a player's XP in points. Vanilla only
 * takes whole levels (enchanting, anvils); the frame offering and ichor take points.
 */
public final class SoulPoints {
	private SoulPoints() {
	}

	/** XP needed to go from {@code level} to the next one (vanilla's {@code Player#getXpNeededForNextLevel}). */
	public static int xpNeeded(int level) {
		return level >= 30 ? 112 + (level - 30) * 9 : level >= 15 ? 37 + (level - 15) * 5 : 7 + level * 2;
	}

	/** Total XP from zero to {@code level}: the closed forms of summing {@link #xpNeeded}. */
	public static long pointsForLevel(int level) {
		long l = level;
		if (l <= 16) {
			return l * l + 6 * l;
		}
		if (l <= 31) {
			return (5 * l * l - 81 * l + 720) / 2;
		}
		return (9 * l * l - 325 * l + 4440) / 2;
	}

	/** The player's XP in points, exactly, at any level. */
	public static long totalLong(Player player) {
		return pointsForLevel(player.experienceLevel) + Math.round(player.experienceProgress * xpNeeded(player.experienceLevel));
	}

	/** {@link #totalLong}, clamped for display and tests. */
	public static int total(Player player) {
		return (int) Math.min(Integer.MAX_VALUE, totalLong(player));
	}

	/** Takes up to {@code points}, recomputing level and progress so it works across level boundaries. Returns what was taken. */
	public static int take(ServerPlayer player, int points) {
		long before = totalLong(player);
		int taken = (int) Math.min(points, before);
		if (taken <= 0) {
			return 0;
		}
		long remaining = before - taken;
		// The highest level whose total fits in what remains (binary search: levels can be huge with commands).
		int lo = 0;
		int hi = player.experienceLevel;
		while (lo < hi) {
			int mid = (int) (((long) lo + hi + 1) / 2);
			if (pointsForLevel(mid) <= remaining) {
				lo = mid;
			} else {
				hi = mid - 1;
			}
		}
		player.setExperienceLevels(lo);
		player.setExperiencePoints((int) Math.min(Integer.MAX_VALUE, remaining - pointsForLevel(lo)));
		player.totalExperience = Math.max(0, player.totalExperience - taken);
		return taken;
	}
}
