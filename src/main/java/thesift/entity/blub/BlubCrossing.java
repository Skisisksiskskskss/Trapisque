package thesift.entity.blub;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import net.fabricmc.fabric.api.entity.event.v1.ServerEntityLevelChangeEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.world.SiftKeys;

/**
 * Befriended blubs cross the membrane with their owner (mob_blub.md, tech notes). Blubs never use the
 * membrane themselves ({@code #thesift:cannot_cross}). {@code SiftGates.destination} records where a
 * player entered, stamped with the server tick; Fabric's AFTER_PLAYER_CHANGE_LEVEL (which also fires
 * for other portals, /tp and respawns) consumes the record once, and only an Overworld↔Sift change
 * made within a few ticks of it brings the owner's blubs along.
 */
public final class BlubCrossing {
	/** Blubs this close to where the owner entered come along. */
	public static final double RANGE = 16.0;
	private static final int MAX_AGE_TICKS = 5;
	private static final Map<UUID, Entry> ENTRIES = new HashMap<>();

	private record Entry(ResourceKey<Level> from, Vec3 pos, int tick) {
	}

	private BlubCrossing() {
	}

	public static void init() {
		ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL.register(BlubCrossing::afterChange);
		ServerLifecycleEvents.SERVER_STARTED.register(server -> ENTRIES.clear());
	}

	/** A player is about to cross the membrane in {@code from} (SiftGates.destination). */
	public static void recordEntry(ServerPlayer player, ServerLevel from) {
		ENTRIES.put(player.getUUID(), new Entry(from.dimension(), player.position(), from.getServer().getTickCount()));
	}

	private static void afterChange(ServerPlayer player, ServerLevel origin, ServerLevel destination) {
		Entry entry = ENTRIES.remove(player.getUUID());
		if (entry == null || !entry.from().equals(origin.dimension())
				|| origin.getServer().getTickCount() - entry.tick() > MAX_AGE_TICKS) {
			return;
		}
		boolean siftCrossing = (origin.dimension() == Level.OVERWORLD && SiftKeys.isSift(destination))
				|| (SiftKeys.isSift(origin) && destination.dimension() == Level.OVERWORLD);
		if (siftCrossing) {
			bring(player, origin, entry.pos(), destination, player.position());
		}
	}

	/**
	 * Brings {@code owner}'s blubs near {@code entered} in {@code origin} to {@code arrival}: not
	 * sitting ones, and not ones leashed to anything but the owner (26.3 re-attaches a leash by the
	 * holder's UUID, so a fence knot would reappear as a phantom knot). Towers topple first, so no
	 * untamed rider is carried through. Returns the blubs as they are in the destination.
	 */
	public static List<Entity> bring(Player owner, ServerLevel origin, Vec3 entered, ServerLevel destination, Vec3 arrival) {
		List<Blub> blubs = origin.getEntitiesOfClass(Blub.class, AABB.ofSize(entered, 2 * RANGE, 2 * RANGE, 2 * RANGE),
				b -> b.isAlive() && b.isOwnedBy(owner) && !b.isOrderedToSit() && b.position().distanceToSqr(entered) <= RANGE * RANGE
						&& (!b.isLeashed() || b.getLeashHolder() == owner));
		List<Entity> moved = new java.util.ArrayList<>();
		for (Blub blub : blubs) {
			BlubGoals.Stack.topple(blub.getRootVehicle(), origin);
			blub.stopRiding();
			blub.ejectPassengers();
			blub.setCurled(false);
			Entity arrived = blub.teleport(new TeleportTransition(destination, arrival, Vec3.ZERO, blub.getYRot(), blub.getXRot(), TeleportTransition.DO_NOTHING));
			if (arrived != null) {
				moved.add(arrived);
			}
		}
		return moved;
	}
}
