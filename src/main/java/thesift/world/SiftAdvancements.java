package thesift.world;

import net.minecraft.advancements.AdvancementHolder;
import net.minecraft.resources.Identifier;
import net.minecraft.server.level.ServerPlayer;

import thesift.TheSift;

/**
 * The Sift advancement tab (items.md §5). The root and "Where Souls Drift" use vanilla triggers
 * (location, changed dimension); the two moments vanilla can't see are awarded here, through each
 * advancement's single {@code minecraft:impossible} criterion, as vanilla does for code-granted ones.
 */
public final class SiftAdvancements {
	public static final Identifier ROOT = TheSift.id("sift/root");
	public static final Identifier OFFERING = TheSift.id("sift/an_offering");
	public static final Identifier ENTER = TheSift.id("sift/where_souls_drift");
	public static final Identifier TIDE_TURNS = TheSift.id("sift/the_tide_turns");
	public static final Identifier LOW_TIDE = TheSift.id("sift/low_tide");
	public static final Identifier HEARD_YOU = TheSift.id("sift/heard_you");
	public static final Identifier THROUGH_THE_RIFT = TheSift.id("sift/through_the_rift");
	public static final Identifier TUNED_IN = TheSift.id("sift/tuned_in");
	public static final Identifier SIFT_BORN = TheSift.id("sift/sift_born");
	/** The criterion name of the code-awarded advancements. */
	public static final String AWARDED = "awarded";

	private SiftAdvancements() {
	}

	/** Grants {@code id} to {@code player}; a no-op if it is missing (e.g. a data pack removed it). */
	public static void award(ServerPlayer player, Identifier id) {
		AdvancementHolder holder = player.level().getServer().getAdvancements().get(id);
		if (holder != null) {
			player.getAdvancements().award(holder, AWARDED);
		}
	}

	public static boolean has(ServerPlayer player, Identifier id) {
		AdvancementHolder holder = player.level().getServer().getAdvancements().get(id);
		return holder != null && player.getAdvancements().getOrStartProgress(holder).isDone();
	}
}
