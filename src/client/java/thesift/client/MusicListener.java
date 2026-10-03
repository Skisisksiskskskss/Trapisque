package thesift.client;

import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.sounds.SoundInstance;
import net.minecraft.client.sounds.SoundEventListener;
import net.minecraft.client.sounds.WeighedSoundEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Util;

import thesift.block.MusicNearby;

/**
 * Remembers where music played lately (world.md §3.2): note blocks, goat horns and jukebox songs.
 * Vanilla notifies sound listeners before its zero-volume check, so muted players see the
 * reactions too. A jukebox song is notified once, so its entry stays live while it plays.
 */
public final class MusicListener implements SoundEventListener {
	private static final int SIZE = 16;
	private static final long FRESH_MS = 3_000;
	private static final double RANGE = 12.0;

	private record Entry(double x, double y, double z, long at, SoundInstance sound, boolean song) {
	}

	private final Entry[] ring = new Entry[SIZE];
	private int next;

	public static void install() {
		MusicListener listener = new MusicListener();
		Minecraft.getInstance().getSoundManager().addListener(listener);
		MusicNearby.set(listener::near);
	}

	public static boolean isMusic(SoundInstance sound) {
		String path = sound.getIdentifier().getPath();
		return sound.getSource() == SoundSource.RECORDS
				|| path.startsWith("block.note_block.")
				|| path.startsWith("item.goat_horn.");
	}

	@Override
	public void onPlaySound(SoundInstance sound, WeighedSoundEvents soundEvent, float range) {
		if (sound.isRelative() || !isMusic(sound)) {
			return;
		}
		this.ring[this.next] = new Entry(sound.getX(), sound.getY(), sound.getZ(), Util.getMillis(), sound, sound.getSource() == SoundSource.RECORDS);
		this.next = (this.next + 1) % SIZE;
	}

	private boolean near(BlockPos pos) {
		long now = Util.getMillis();
		double cx = pos.getX() + 0.5;
		double cy = pos.getY() + 0.5;
		double cz = pos.getZ() + 0.5;
		for (Entry e : this.ring) {
			if (e == null) {
				continue;
			}
			boolean live = now - e.at() < FRESH_MS || (e.song() && Minecraft.getInstance().getSoundManager().isActive(e.sound()));
			double dx = e.x() - cx;
			double dy = e.y() - cy;
			double dz = e.z() - cz;
			if (live && dx * dx + dy * dy + dz * dz <= RANGE * RANGE) {
				return true;
			}
		}
		return false;
	}
}
