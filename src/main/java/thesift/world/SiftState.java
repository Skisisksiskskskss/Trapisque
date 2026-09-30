package thesift.world;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;

import net.minecraft.world.level.saveddata.SavedData;
import net.minecraft.world.level.saveddata.SavedDataType;

import thesift.TheSift;

/**
 * World-global Sift state, stored with the server's saved data (D-019). The Tide clock stays paused
 * at Thrive until the first player crosses into the Sift (systems.md §1).
 */
public final class SiftState extends SavedData {
	private static final Codec<SiftState> CODEC = RecordCodecBuilder.create(i -> i.group(
			Codec.BOOL.optionalFieldOf("first_crossing_done", false).forGetter(s -> s.firstCrossingDone)
	).apply(i, SiftState::new));

	// A null DataFixTypes is supported by Fabric API for mod data (SavedDataStorageMixin).
	public static final SavedDataType<SiftState> TYPE = new SavedDataType<>(TheSift.id("sift_state"), SiftState::new, CODEC, null);

	private boolean firstCrossingDone;

	public SiftState() {
		this(false);
	}

	private SiftState(boolean firstCrossingDone) {
		this.firstCrossingDone = firstCrossingDone;
	}

	public boolean firstCrossingDone() {
		return this.firstCrossingDone;
	}

	public void markFirstCrossingDone() {
		this.firstCrossingDone = true;
		this.setDirty();
	}
}
