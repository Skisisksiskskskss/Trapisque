package thesift.world;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.protocol.game.ClientboundSoundPacket;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;

import thesift.registry.ModSounds;

/**
 * The Tide turning is heard by everyone in the Sift (WP-043): bells as Thrive returns, a swell as
 * Flow begins, a gong as Endure falls. Checked once a second; each player hears it at their own
 * position, so nobody hears a crowd's copies.
 */
public final class TideCues {
	private static Tide last;

	private TideCues() {
	}

	public static void init() {
		ServerTickEvents.END_LEVEL_TICK.register(TideCues::tick);
		// A new world (singleplayer switches worlds in one JVM) starts with no remembered Tide.
		ServerLifecycleEvents.SERVER_STARTED.register(server -> last = null);
	}

	private static void tick(ServerLevel level) {
		if (!SiftKeys.isSift(level) || level.getGameTime() % 20 != 0) {
			return;
		}
		Tide now = Tide.current(level);
		Tide before = last;
		last = now;
		if (before == null || now == null || now == before) {
			return;
		}
		SoundEvent cue = switch (now) {
			case THRIVE -> ModSounds.TIDE_THRIVE;
			case FLOW_RISING, FLOW_FALLING -> ModSounds.TIDE_FLOW;
			case ENDURE -> ModSounds.TIDE_ENDURE;
		};
		for (ServerPlayer player : level.players()) {
			if (player.connection == null) {
				continue;
			}
			player.connection.send(new ClientboundSoundPacket(BuiltInRegistries.SOUND_EVENT.wrapAsHolder(cue), SoundSource.AMBIENT,
					player.getX(), player.getY(), player.getZ(), 1.0F, 1.0F, level.getRandom().nextLong()));
		}
	}
}
