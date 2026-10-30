package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import org.jspecify.annotations.Nullable;

import net.fabricmc.fabric.api.client.datagen.v1.builder.SoundTypeBuilder;
import net.fabricmc.fabric.api.client.datagen.v1.provider.FabricSoundsProvider;
import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.minecraft.core.HolderLookup;
import net.minecraft.sounds.SoundEvent;

import thesift.TheSift;
import thesift.registry.ModSounds;

/** sounds.json (WP-043): each event, its synthesized files (tools/audio/synth.py) and its subtitle. */
final class ModSoundsProvider extends FabricSoundsProvider {
	ModSoundsProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries);
	}

	@Override
	public String getName() {
		return "The Sift sounds";
	}

	private static void add(SoundExporter exporter, SoundEvent event, String file, int variants, @Nullable String subtitle) {
		// of(event) pre-fills a subtitle key; a null subtitle clears it (steps have none, as in vanilla).
		SoundTypeBuilder builder = SoundTypeBuilder.of(event).subtitle(subtitle);
		for (int i = 1; i <= variants; i++) {
			String path = variants == 1 ? file : file + i;
			builder.sound(SoundTypeBuilder.RegistrationBuilder.ofFile(TheSift.id(path)));
		}
		exporter.add(event, builder);
	}

	@Override
	protected void configure(HolderLookup.Provider registries, SoundExporter exporter) {
		add(exporter, ModSounds.FRAME_OFFER, "entry/offer", 3, "subtitles.thesift.frame.offer");
		add(exporter, ModSounds.FRAME_WAKE, "entry/wake", 1, "subtitles.thesift.frame.wake");
		add(exporter, ModSounds.FRAME_OPEN, "entry/open", 1, "subtitles.thesift.frame.open");
		add(exporter, ModSounds.FRAME_HUM, "entry/hum", 2, "subtitles.thesift.frame.hum");
		add(exporter, ModSounds.FRAME_NOTICE, "entry/notice", 2, "subtitles.thesift.frame.notice");
		add(exporter, ModSounds.MEMBRANE_AMBIENT, "entry/membrane", 3, "subtitles.thesift.membrane.ambient");
		add(exporter, ModSounds.MEMBRANE_TRAVEL, "entry/travel", 1, "subtitles.thesift.membrane.travel");
		add(exporter, ModSounds.TIDE_THRIVE, "tide/thrive", 1, "subtitles.thesift.tide.thrive");
		add(exporter, ModSounds.TIDE_FLOW, "tide/flow", 1, "subtitles.thesift.tide.flow");
		add(exporter, ModSounds.TIDE_ENDURE, "tide/endure", 1, "subtitles.thesift.tide.endure");
		add(exporter, ModSounds.BASIN_FILL, "tide/basin_fill", 3, "subtitles.thesift.basin.fill");
		add(exporter, ModSounds.BASIN_DRAIN, "tide/basin_drain", 2, "subtitles.thesift.basin.drain");
		add(exporter, ModSounds.ICHOR_AMBIENT, "ichor/ambient", 3, "subtitles.thesift.ichor.ambient");
		add(exporter, ModSounds.ICHOR_EVAPORATE, "ichor/evaporate", 1, "subtitles.thesift.ichor.evaporate");
		add(exporter, ModSounds.BUCKET_FILL_ICHOR, "ichor/bucket_fill", 2, "subtitles.thesift.bucket.fill_ichor");
		add(exporter, ModSounds.BUCKET_EMPTY_ICHOR, "ichor/bucket_empty", 2, "subtitles.thesift.bucket.empty_ichor");
		add(exporter, ModSounds.TIDEWRACK_OPEN, "flora/tidewrack_open", 2, "subtitles.thesift.tidewrack.open");
		add(exporter, ModSounds.TIDEWRACK_CLOSE, "flora/tidewrack_close", 2, "subtitles.thesift.tidewrack.close");
		add(exporter, ModSounds.ENDURE_BLOOM_OPEN, "flora/endure_bloom_open", 2, "subtitles.thesift.endure_bloom.open");
		add(exporter, ModSounds.ENDURE_BLOOM_CLOSE, "flora/endure_bloom_close", 2, "subtitles.thesift.endure_bloom.close");
		add(exporter, ModSounds.FLORA_PICK, "flora/pick", 3, "subtitles.thesift.flora.pick");
		add(exporter, ModSounds.CHIME_BELL_RING, "flora/chime_ring", 4, "subtitles.thesift.chime_bell.ring");
		add(exporter, ModSounds.CHIME_BELL_HUM, "flora/chime_hum", 2, "subtitles.thesift.chime_bell.hum");
		add(exporter, ModSounds.BLUB_AMBIENT, "blub/ambient", 4, "subtitles.thesift.blub.ambient");
		add(exporter, ModSounds.BLUB_LISTEN, "blub/listen", 2, "subtitles.thesift.blub.listen");
		add(exporter, ModSounds.BLUB_HAPPY, "blub/happy", 2, "subtitles.thesift.blub.happy");
		add(exporter, ModSounds.BLUB_SING, "blub/sing", 1, "subtitles.thesift.blub.sing");
		add(exporter, ModSounds.BLUB_RESTLESS, "blub/restless", 2, "subtitles.thesift.blub.restless");
		add(exporter, ModSounds.BLUB_CURL, "blub/curl", 2, "subtitles.thesift.blub.curl");
		add(exporter, ModSounds.BLUB_SPLASH, "blub/splash", 2, "subtitles.thesift.blub.splash");
		add(exporter, ModSounds.BLUB_TOPPLE, "blub/topple", 2, "subtitles.thesift.blub.topple");
		add(exporter, ModSounds.BLUB_HURT, "blub/hurt", 2, "subtitles.thesift.blub.hurt");
		add(exporter, ModSounds.BLUB_DEATH, "blub/death", 1, "subtitles.thesift.blub.death");
		add(exporter, ModSounds.BLUB_HOP, "blub/hop", 3, "subtitles.thesift.blub.hop");
		add(exporter, ModSounds.BLUB_STEP, "blub/step", 4, null); // steps have no subtitle, as in vanilla
		// The Nester: its steps have a subtitle, as "Warden steps" does, so a roaming one can be noticed.
		add(exporter, ModSounds.NESTER_AMBIENT, "nester/ambient", 4, "subtitles.thesift.nester.ambient");
		add(exporter, ModSounds.NESTER_AMBIENT_ENDURING, "nester/ambient_enduring", 3, "subtitles.thesift.nester.ambient_enduring");
		add(exporter, ModSounds.NESTER_HEAR, "nester/hear", 3, "subtitles.thesift.nester.hear");
		add(exporter, ModSounds.NESTER_GALLOP, "nester/gallop", 4, "subtitles.thesift.nester.gallop");
		add(exporter, ModSounds.NESTER_SNIFF, "nester/sniff", 3, "subtitles.thesift.nester.sniff");
		add(exporter, ModSounds.NESTER_HISS, "nester/hiss", 3, "subtitles.thesift.nester.hiss");
		add(exporter, ModSounds.NESTER_BITE, "nester/bite", 3, "subtitles.thesift.nester.bite");
		add(exporter, ModSounds.NESTER_GUARD, "nester/guard", 2, "subtitles.thesift.nester.guard");
		add(exporter, ModSounds.NESTER_DODGE, "nester/dodge", 2, "subtitles.thesift.nester.dodge");
		add(exporter, ModSounds.NESTER_STAGGER, "nester/stagger", 2, "subtitles.thesift.nester.stagger");
		add(exporter, ModSounds.SINGER_HUM, "singer/hum", 3, "subtitles.thesift.singer.hum");
		add(exporter, ModSounds.SINGER_SING, "singer/sing", 3, "subtitles.thesift.singer.sing");
		add(exporter, ModSounds.SINGER_SONG, "singer/song", 1, "subtitles.thesift.singer.song");
		add(exporter, ModSounds.SINGER_FADE, "singer/fade", 1, "subtitles.thesift.singer.fade");
		add(exporter, ModSounds.SINGER_HURT, "singer/hurt", 2, "subtitles.thesift.singer.hurt");
		add(exporter, ModSounds.CHORUS_STONE_FILL, "singer/chorus_fill", 1, "subtitles.thesift.chorus_stone.fill");
		add(exporter, ModSounds.GROVE_HEART_CONDENSE, "singer/condense", 1, "subtitles.thesift.grove_heart.condense");
		add(exporter, ModSounds.SINGERS_HORN_SONG, "singer/horn", 3, "subtitles.thesift.singers_horn.song");
		add(exporter, ModSounds.NESTER_LULLED, "nester/lulled", 1, "subtitles.thesift.nester.lulled");
		add(exporter, ModSounds.RIFT_HUM, "rift/hum", 1, "subtitles.thesift.rift.hum");
		add(exporter, ModSounds.RIFT_OPEN, "rift/open", 1, "subtitles.thesift.rift.open");
		add(exporter, ModSounds.RIFT_CLOSE, "rift/close", 1, "subtitles.thesift.rift.close");
		add(exporter, ModSounds.RIFT_FORK_STRIKE, "rift/fork_strike", 1, "subtitles.thesift.rift_fork.strike");
		add(exporter, ModSounds.NESTER_EMERGE, "nester/emerge", 2, "subtitles.thesift.nester.emerge");
		add(exporter, ModSounds.NESTER_BURROW, "nester/burrow", 2, "subtitles.thesift.nester.burrow");
		add(exporter, ModSounds.NESTER_HURT, "nester/hurt", 3, "subtitles.thesift.nester.hurt");
		add(exporter, ModSounds.NESTER_DEATH, "nester/death", 2, "subtitles.thesift.nester.death");
		add(exporter, ModSounds.NESTER_STEP, "nester/step", 4, "subtitles.thesift.nester.step");
		add(exporter, ModSounds.MEADOW_LOOP.value(), "ambient/meadow_loop", 1, "subtitles.thesift.meadow.loop");
		add(exporter, ModSounds.MEADOW_MOOD.value(), "ambient/meadow_mood", 4, "subtitles.thesift.meadow.mood");
	}
}
