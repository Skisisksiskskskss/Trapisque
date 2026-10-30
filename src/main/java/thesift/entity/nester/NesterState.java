package thesift.entity.nester;

/**
 * The Nester's state (mob_nester.md, tech notes): synced, so the model's clips follow it, and a client
 * that starts tracking a Nester mid-dig still shows the dig.
 */
public enum NesterState {
	/** Wandering; it listens (in Endure). */
	ROAM,
	/** 20 ticks: it stops, turns to the sound, fans its crest. */
	TELL,
	/** Running to the sound's spot, or at its target. The crest stays up. */
	GALLOP,
	/** 60 ticks: sniffing round the spot for something to attack. */
	SEARCH,
	/** 8 ticks: crouched, crest flat, jaw open; the aim is locked. */
	WINDUP,
	/** In the air: the bite is live until it lands. */
	LEAP,
	/** A standing bite: 6 ticks stepping in, then the snap. */
	BITE,
	/** 12 ticks after a bite: it can't dodge. */
	RECOVERY,
	/** 30 ticks after a shield blocked its bite. */
	STAGGER,
	/** Circling its target, guard down. */
	CIRCLE,
	/** Circling with its crest up and rattling: the next hit is dodged. */
	GUARD,
	/** 4 ticks: the dodge's hop. */
	DODGE,
	/** 40 ticks: rising out of the soil. */
	EMERGE,
	/** 60 ticks: digging into the soil at dawn. */
	DIG;

	private static final NesterState[] VALUES = values();

	public static NesterState byId(int id) {
		return id >= 0 && id < VALUES.length ? VALUES[id] : ROAM;
	}

	/** States in which a sound is heard (system_hunt.md §3): roam hears, gallop and search re-aim. */
	public boolean listening() {
		return this == ROAM || this == GALLOP || this == SEARCH;
	}
}
