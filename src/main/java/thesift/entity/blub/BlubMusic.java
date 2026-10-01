package thesift.entity.blub;

import java.util.Comparator;
import java.util.List;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.block.NoteBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.entry.FrameMusic;
import thesift.registry.ModAttachments;

/**
 * How blubs hear music (mob_blub.md, Befriending and Reactions). A second consumer of the game-event
 * hook ({@code ServerLevelGameEventMixin}): it looks blubs up only for music events, which are rare.
 * Order matters: a hand-played note first befriends the nearest blub that was <em>already</em>
 * listening, then owners' blubs answer it, and only then does the note make blubs listen, so the first
 * note of a tune only gets attention.
 */
public final class BlubMusic {
	/** A note befriends the nearest listening blub within this many blocks of the player. */
	public static final double BEFRIEND_RANGE = 4.0;
	/** The note a goat horn or a mob head on a note block stands for (pitch 1.0). */
	public static final int UNTUNED_NOTE = 12;

	private BlubMusic() {
	}

	public static void onGameEvent(ServerLevel level, Holder<GameEvent> event, Vec3 pos, GameEvent.Context context) {
		int range = FrameMusic.musicRange(event);
		if (range == 0) {
			return;
		}
		List<Blub> blubs = level.getEntitiesOfClass(Blub.class, AABB.ofSize(pos, 2 * range, 2 * range, 2 * range),
				b -> b.isAlive() && b.position().distanceToSqr(pos) <= range * range);
		if (blubs.isEmpty()) {
			return;
		}
		long now = level.getGameTime();
		Player player = handOf(event, context);
		if (player != null) {
			Blub chosen = blubs.stream()
					.filter(b -> !b.isTame() && b.isListening() && b.distanceToSqr(player) <= BEFRIEND_RANGE * BEFRIEND_RANGE && b.hasLineOfSight(player))
					.min(Comparator.comparingDouble(b -> b.distanceToSqr(player)))
					.orElse(null);
			if (chosen != null) {
				chosen.befriend(player, nextInterval(player));
			}
			int note = noteAt(level, event, pos);
			for (Blub blub : blubs) {
				if (blub != chosen && blub.isOwnedBy(player)) {
					blub.queueEcho(note, now);
				}
			}
		}
		for (Blub blub : blubs) {
			blub.hear(pos, now);
		}
	}

	/**
	 * The player whose own hand played this note: a note block they clicked or punched, or a goat horn
	 * they blew (both events name the player). Redstone notes and jukeboxes name no one.
	 */
	static Player handOf(Holder<GameEvent> event, GameEvent.Context context) {
		if (!event.is(GameEvent.NOTE_BLOCK_PLAY.key()) && !event.is(GameEvent.INSTRUMENT_PLAY.key())) {
			return null;
		}
		Entity source = context.sourceEntity();
		return source instanceof Player p && !p.isSpectator() ? p : null;
	}

	/**
	 * The note played, read from the world (a note block's event context carries no block state):
	 * the note block's NOTE if its instrument is tunable, else {@link #UNTUNED_NOTE}.
	 */
	static int noteAt(ServerLevel level, Holder<GameEvent> event, Vec3 pos) {
		if (event.is(GameEvent.NOTE_BLOCK_PLAY.key())) {
			BlockState state = level.getBlockState(BlockPos.containing(pos));
			if (state.getBlock() instanceof NoteBlock && state.getValue(NoteBlock.INSTRUMENT).isTunable()) {
				return state.getValue(NoteBlock.NOTE);
			}
		}
		return UNTUNED_NOTE;
	}

	/** Root, third, fifth, cycling per player, so any three befriended in a row make a chord. */
	static int nextInterval(Player player) {
		int count = player.getAttachedOrElse(ModAttachments.BLUB_CHORD_COUNT, 0);
		player.setAttached(ModAttachments.BLUB_CHORD_COUNT, count + 1);
		return Blub.INTERVALS[Math.floorMod(count, Blub.INTERVALS.length)];
	}
}
