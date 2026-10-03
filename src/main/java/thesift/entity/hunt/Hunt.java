package thesift.entity.hunt;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.WeakHashMap;

import org.jspecify.annotations.Nullable;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerEntityEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.ai.village.poi.PoiManager;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModPoiTypes;
import thesift.registry.ModTags;
import thesift.world.SiftKeys;
import thesift.world.Tide;

/**
 * The hunt's shared rules (system_hunt.md): soil, lumen's repel radius and rim, the return-by tick,
 * each hunter's retreat moment, and the Thrive sweep that guarantees no retreating hunter is ever
 * present in Thrive or rising Flow (§4).
 */
public final class Hunt {
	/** Hearing range in Endure (a warden's 16). */
	public static final int HEAR_RANGE = 16;
	/** Jukeboxes call listeners within 10 (an allay's range). */
	public static final double JUKEBOX_RANGE = 10.0;
	/** No hunter goes within 6 of lumen... */
	public static final double REPEL = 6.0;
	/** ...it stops at the rim, 7 out... */
	public static final double RIM = 7.0;
	/** ...and none spawns within 8. */
	public static final double NO_SPAWN = 8.0;

	private static final Map<ServerLevel, Tide> LAST_TIDE = new WeakHashMap<>();
	private static final Map<ServerLevel, ArrayDeque<Entity>> LOADED = new WeakHashMap<>();

	private Hunt() {
	}

	/** What a hunter is to the shared rules (system_hunt.md §4, §5). */
	public interface Hunter {
		/** Past its return-by: a retreating hunter leaves with the tide, a persistent enduring one reverts. */
		void tideCheck(ServerLevel level);
	}

	public static void init() {
		ServerEntityEvents.ENTITY_LOAD.register((entity, level) -> {
			if (entity instanceof Hunter) {
				// Removing an entity while its section loads can throw: queue it for the end of the tick.
				LOADED.computeIfAbsent(level, l -> new ArrayDeque<>()).add(entity);
			}
		});
		ServerTickEvents.END_LEVEL_TICK.register(Hunt::tick);
	}

	private static void tick(ServerLevel level) {
		ArrayDeque<Entity> queue = LOADED.get(level);
		while (queue != null && !queue.isEmpty()) {
			Entity entity = queue.poll();
			if (entity.isAlive() && entity instanceof Hunter hunter) {
				hunter.tideCheck(level);
			}
		}
		if (!level.dimension().equals(SiftKeys.LEVEL)) {
			return;
		}
		Tide tide = Tide.current(level);
		Tide last = LAST_TIDE.put(level, tide);
		if (tide == Tide.THRIVE && last != Tide.THRIVE && last != null) {
			// Thrive's first tick: every loaded hunter, ticking or not (§4's guarantee).
			List<Hunter> hunters = new ArrayList<>();
			for (Entity entity : level.getAllEntities()) {
				if (entity instanceof Hunter hunter) {
					hunters.add(hunter);
				}
			}
			hunters.forEach(h -> h.tideCheck(level));
		}
	}

	/** Soil (`#thesift:hunter_burrowable`): hunters come up out of it and dig back into it. */
	public static boolean isSoil(BlockState state) {
		return state.is(ModTags.HUNTER_BURROWABLE);
	}

	/** The next Thrive's first clock tick, strictly after now: a hunter's return-by. */
	public static long nextThrive(Level level) {
		long clock = Tide.clockTicks(level);
		return (Math.floorDiv(clock, Tide.PERIOD_TICKS) + 1) * Tide.PERIOD_TICKS;
	}

	/** Where in falling Flow this hunter digs: cycle ticks 27 000 to 29 000, by its UUID, so they stagger. */
	public static int retreatMoment(UUID uuid) {
		return Tide.FLOW_FALLING.startTick() + Math.floorMod(uuid.hashCode(), 2000);
	}

	/** The cycle tick (0 to 29 999). */
	public static int cycleTick(Level level) {
		return (int) Math.floorMod(Tide.clockTicks(level), (long) Tide.PERIOD_TICKS);
	}

	/** The nearest lumen block within {@code radius} (a sphere), or null. */
	public static @Nullable BlockPos lumenWithin(ServerLevel level, Vec3 pos, double radius) {
		BlockPos centre = BlockPos.containing(pos);
		Optional<BlockPos> found = level.getPoiManager().findClosest(holder -> holder.value() == ModPoiTypes.LUMEN, centre,
				(int) Math.ceil(radius), PoiManager.Occupancy.ANY);
		return found.filter(p -> Vec3.atCenterOf(p).distanceToSqr(pos) <= radius * radius).orElse(null);
	}

	public static boolean inLumen(ServerLevel level, Vec3 pos) {
		return lumenWithin(level, pos, REPEL) != null;
	}

	/**
	 * A destination kept out of lumen (§6.1): unchanged when outside every radius; otherwise the rim
	 * point 7 from the lumen on the side facing {@code from}, moved outward a block at a time (to 16)
	 * until it is outside every radius, then snapped to standable ground within 3 up or down. Null if
	 * there is none.
	 */
	public static @Nullable Vec3 keepOut(ServerLevel level, Vec3 dest, Vec3 from) {
		BlockPos lumen = lumenWithin(level, dest, REPEL);
		if (lumen == null) {
			return dest;
		}
		Vec3 centre = Vec3.atCenterOf(lumen);
		Vec3 out = new Vec3(from.x - centre.x, 0, from.z - centre.z);
		if (out.lengthSqr() < 1.0E-4) {
			out = new Vec3(1, 0, 0);
		}
		out = out.normalize();
		for (double r = RIM; r <= 16.0; r += 1.0) {
			Vec3 p = centre.add(out.scale(r));
			BlockPos feet = standable(level, BlockPos.containing(p.x, dest.y, p.z));
			if (feet != null && !inLumen(level, Vec3.atBottomCenterOf(feet))) {
				return Vec3.atBottomCenterOf(feet);
			}
		}
		return null;
	}

	/** The nearest standable cell (sturdy floor, two open cells) within 3 up or down of {@code pos}, or null. */
	public static @Nullable BlockPos standable(Level level, BlockPos pos) {
		for (int dy : new int[] {0, 1, -1, 2, -2, 3, -3}) {
			BlockPos p = pos.above(dy);
			if (level.getBlockState(p.below()).isFaceSturdy(level, p.below(), Direction.UP)
					&& level.getBlockState(p).getCollisionShape(level, p).isEmpty()
					&& level.getBlockState(p.above()).getCollisionShape(level, p.above()).isEmpty()) {
				return p;
			}
		}
		return null;
	}

	/** The soil block under {@code feet}, or the nearest soil with air above within 16 across and 6 up or down, outside lumen. */
	public static @Nullable BlockPos findSoil(ServerLevel level, BlockPos feet) {
		if (isSoil(level.getBlockState(feet.below()))) {
			return feet.below();
		}
		BlockPos best = null;
		double bestDist = Double.MAX_VALUE;
		for (BlockPos p : BlockPos.betweenClosed(feet.offset(-16, -6, -16), feet.offset(16, 6, 16))) {
			if (isSoil(level.getBlockState(p)) && level.getBlockState(p.above()).isAir()) {
				double d = p.distSqr(feet);
				if (d < bestDist && !inLumen(level, Vec3.atCenterOf(p.above()))) {
					bestDist = d;
					best = p.immutable();
				}
			}
		}
		return best;
	}
}
