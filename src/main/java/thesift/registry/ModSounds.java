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
	public static final SoundEvent FRAME_NOTICE = register("block.sift_frame.notice");
	public static final SoundEvent MEMBRANE_AMBIENT = register("block.sift_membrane.ambient");
	public static final SoundEvent MEMBRANE_TRAVEL = register("block.sift_membrane.travel");
	public static final SoundEvent TIDE_THRIVE = register("ambient.tide.thrive");
	public static final SoundEvent TIDE_FLOW = register("ambient.tide.flow");
	public static final SoundEvent TIDE_ENDURE = register("ambient.tide.endure");
	public static final SoundEvent BASIN_FILL = register("block.tide_vent.fill");
	public static final SoundEvent BASIN_DRAIN = register("block.tide_vent.drain");
	public static final SoundEvent ICHOR_AMBIENT = register("block.ichor.ambient");
	public static final SoundEvent ICHOR_EVAPORATE = register("block.ichor.evaporate");
	public static final SoundEvent BUCKET_FILL_ICHOR = register("item.bucket.fill_ichor");
	public static final SoundEvent BUCKET_EMPTY_ICHOR = register("item.bucket.empty_ichor");
	public static final SoundEvent BLUB_AMBIENT = register("entity.blub.ambient");
	public static final SoundEvent BLUB_LISTEN = register("entity.blub.listen");
	public static final SoundEvent BLUB_HAPPY = register("entity.blub.happy");
	public static final SoundEvent BLUB_SING = register("entity.blub.sing");
	public static final SoundEvent BLUB_RESTLESS = register("entity.blub.restless");
	public static final SoundEvent BLUB_CURL = register("entity.blub.curl");
	public static final SoundEvent BLUB_SPLASH = register("entity.blub.splash");
	public static final SoundEvent BLUB_TOPPLE = register("entity.blub.topple");
	public static final SoundEvent BLUB_HURT = register("entity.blub.hurt");
	public static final SoundEvent BLUB_DEATH = register("entity.blub.death");
	public static final SoundEvent BLUB_HOP = register("entity.blub.hop");
	public static final SoundEvent BLUB_STEP = register("entity.blub.step");
	// The Nester (mob_nester.md, Audio).
	public static final SoundEvent NESTER_AMBIENT = register("entity.nester.ambient");
	public static final SoundEvent NESTER_AMBIENT_ENDURING = register("entity.nester.ambient_enduring");
	public static final SoundEvent NESTER_HEAR = register("entity.nester.hear");
	public static final SoundEvent NESTER_GALLOP = register("entity.nester.gallop");
	public static final SoundEvent NESTER_SNIFF = register("entity.nester.sniff");
	public static final SoundEvent NESTER_HISS = register("entity.nester.hiss");
	public static final SoundEvent NESTER_BITE = register("entity.nester.bite");
	public static final SoundEvent NESTER_GUARD = register("entity.nester.guard");
	public static final SoundEvent NESTER_DODGE = register("entity.nester.dodge");
	public static final SoundEvent NESTER_STAGGER = register("entity.nester.stagger");
	public static final SoundEvent NESTER_EMERGE = register("entity.nester.emerge");
	public static final SoundEvent NESTER_BURROW = register("entity.nester.burrow");
	public static final SoundEvent NESTER_HURT = register("entity.nester.hurt");
	public static final SoundEvent NESTER_DEATH = register("entity.nester.death");
	public static final SoundEvent NESTER_STEP = register("entity.nester.step");
	public static final SoundEvent TIDEWRACK_OPEN = register("block.tidewrack.open");
	public static final SoundEvent TIDEWRACK_CLOSE = register("block.tidewrack.close");
	public static final SoundEvent ENDURE_BLOOM_OPEN = register("block.endure_bloom.open");
	public static final SoundEvent ENDURE_BLOOM_CLOSE = register("block.endure_bloom.close");
	public static final SoundEvent FLORA_PICK = register("block.flora.pick");
	public static final SoundEvent CHIME_BELL_RING = register("block.chime_bell_flower.ring");
	public static final SoundEvent CHIME_BELL_HUM = register("block.chime_bell_flower.hum");
	// The Singer and its grove (items.md §1.1-1.2): phrases, the whole song, the fade; the stones and the heart; the horn.
	public static final SoundEvent SINGER_HUM = register("entity.singer.hum");
	public static final SoundEvent SINGER_SING = register("entity.singer.sing");
	public static final SoundEvent SINGER_SONG = register("entity.singer.song");
	public static final SoundEvent SINGER_FADE = register("entity.singer.fade");
	public static final SoundEvent SINGER_HURT = register("entity.singer.hurt");
	public static final SoundEvent CHORUS_STONE_FILL = register("block.chorus_stone.fill");
	public static final SoundEvent GROVE_HEART_CONDENSE = register("block.grove_heart.condense");
	public static final SoundEvent SINGERS_HORN_SONG = register("item.singers_horn.song");
	public static final SoundEvent NESTER_LULLED = register("entity.nester.lulled");
	// Rifts (survival_sift.md §2): a hum heard 32 blocks off, opening heard 64, closing; the fork's struck note.
	public static final SoundEvent RIFT_HUM = register("entity.rift.hum");
	public static final SoundEvent RIFT_OPEN = register("entity.rift.open");
	public static final SoundEvent RIFT_CLOSE = register("entity.rift.close");
	public static final SoundEvent RIFT_FORK_STRIKE = register("item.rift_fork.strike");
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
