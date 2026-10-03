package thesift.registry;

import com.mojang.serialization.Codec;

import net.fabricmc.fabric.api.attachment.v1.AttachmentRegistry;
import net.fabricmc.fabric.api.attachment.v1.AttachmentType;

import thesift.TheSift;

/** Data attached to vanilla objects through Fabric's attachment API. */
public final class ModAttachments {
	/**
	 * How many blubs a player has befriended: picks each new blub's echo interval (root, third,
	 * fifth in turn; mob_blub.md, Befriending). Saved with the player and kept through death.
	 */
	/** Song charges (items.md §1.2): the player's, kept on death, shared by every horn. */
	public static final AttachmentType<Integer> SONG_CHARGES = AttachmentRegistry.create(TheSift.id("song_charges"),
			builder -> builder.persistent(Codec.INT).copyOnDeath());
	public static final AttachmentType<Integer> SONG_PROGRESS = AttachmentRegistry.create(TheSift.id("song_progress"),
			builder -> builder.persistent(Codec.INT).copyOnDeath());
	public static final AttachmentType<Integer> BLUB_CHORD_COUNT = AttachmentRegistry.create(TheSift.id("blub_chord_count"),
			builder -> builder.persistent(Codec.INT).copyOnDeath());

	private ModAttachments() {
	}

	public static void init() {
		// Class loading registers the fields above.
	}
}
