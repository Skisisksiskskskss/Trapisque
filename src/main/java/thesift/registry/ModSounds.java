package thesift.registry;

import net.minecraft.core.Holder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.sounds.SoundEvent;

import thesift.TheSift;

/**
 * Sound events (WP-043). Every sound is synthesized by tools/audio/synth.py; sounds.json and the
 * subtitles come from datagen.
 */
public final class ModSounds {
	public static final SoundEvent FRAME_OFFER = register("block.sift_frame.offer");
	public static final SoundEvent FRAME_WAKE = register("block.sift_frame.wake");
	public static final SoundEvent FRAME_OPEN = register("block.sift_frame.open");
	public static final SoundEvent FRAME_HUM = register("block.sift_frame.hum");
	public static final SoundEvent MEMBRANE_AMBIENT = register("block.sift_membrane.ambient");
	public static final SoundEvent MEMBRANE_TRAVEL = register("block.sift_membrane.travel");
	public static final SoundEvent TIDE_THRIVE = register("ambient.tide.thrive");
	public static final SoundEvent TIDE_FLOW = register("ambient.tide.flow");
	public static final SoundEvent TIDE_ENDURE = register("ambient.tide.endure");
	public static final SoundEvent BASIN_FILL = register("block.tide_vent.fill");
	public static final SoundEvent BASIN_DRAIN = register("block.tide_vent.drain");
	public static final SoundEvent ICHOR_WADE = register("block.ichor.wade");
	public static final SoundEvent ICHOR_AMBIENT = register("block.ichor.ambient");
	public static final SoundEvent ICHOR_EVAPORATE = register("block.ichor.evaporate");
	public static final SoundEvent BUCKET_FILL_ICHOR = register("item.bucket.fill_ichor");
	public static final SoundEvent BUCKET_EMPTY_ICHOR = register("item.bucket.empty_ichor");
	public static final Holder<SoundEvent> MEADOW_LOOP = registerHolder("ambient.singers_meadow.loop");
	public static final Holder<SoundEvent> MEADOW_MOOD = registerHolder("ambient.singers_meadow.mood");

	private ModSounds() {
	}

	private static SoundEvent register(String name) {
		return registerHolder(name).value();
	}

	private static Holder<SoundEvent> registerHolder(String name) {
		return Registry.registerForHolder(BuiltInRegistries.SOUND_EVENT, TheSift.id(name), SoundEvent.createVariableRangeEvent(TheSift.id(name)));
	}

	public static void init() {
		// Class loading registers the fields above.
	}
}
