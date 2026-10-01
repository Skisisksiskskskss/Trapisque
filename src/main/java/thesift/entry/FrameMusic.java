package thesift.entry;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.MultifaceBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.Vec3;

import thesift.block.SiftMembraneBlock;
import thesift.registry.ModBlocks;
import thesift.world.SiftKeys;

/**
 * Step 5 of the entry (entry_path.md): music played near an awake frame opens it. Note blocks and
 * goat horns are heard at a warden's 16 blocks; a jukebox at vanilla's jukebox radius of 10 (allays
 * hear it the same way, VANILLA_ANALOGS E4). The same music reopens a gate whose membrane is gone.
 */
public final class FrameMusic {
	public static final int VIBRATION_RANGE = 16;
	public static final int JUKEBOX_RANGE = 10;

	private FrameMusic() {
	}

	public static void init() {
		ServerTickEvents.END_LEVEL_TICK.register(FrameMusic::hintAwakeFrames);
	}

	/** How far {@code event} carries as music, or 0 if it is not music. */
	public static int musicRange(Holder<GameEvent> event) {
		if (event.is(GameEvent.NOTE_BLOCK_PLAY.key()) || event.is(GameEvent.INSTRUMENT_PLAY.key())) {
			return VIBRATION_RANGE;
		}
		return event.is(GameEvent.JUKEBOX_PLAY.key()) ? JUKEBOX_RANGE : 0;
	}

	/** Called for every game event in a server level (ServerLevelMixin); cheap unless it is music. */
	public static void onGameEvent(ServerLevel level, Holder<GameEvent> event, Vec3 pos) {
		int range = musicRange(event);
		if (range == 0) {
			return;
		}
		SiftLinks links = SiftLinks.get(level.getServer());
		if (level.dimension() == Level.OVERWORLD) {
			for (SiftLinks.FrameLink link : links.frames()) {
				if (link.awake() && link.frame().distanceTo(pos) <= range) {
					open(level, link.frame());
				}
			}
		} else if (SiftKeys.isSift(level)) {
			for (SiftLinks.FrameLink link : links.frames()) {
				if (link.gate().isPresent() && link.gate().get().distanceTo(pos) <= range) {
					open(level, link.gate().get());
				}
			}
		}
	}

	public static boolean isOpen(Level level, SiftFrame frame) {
		return level.getBlockState(frame.at(1, 1)).is(ModBlocks.SIFT_MEMBRANE);
	}

	/**
	 * What the membrane may replace: air, replaceable blocks, and thin growths on the frame's faces
	 * (natural Ancient City frames grow sculk veins into the opening; found by the client GameTest).
	 */
	public static boolean isClearable(BlockState state) {
		return state.is(ModBlocks.SIFT_MEMBRANE) || state.canBeReplaced() || state.getBlock() instanceof MultifaceBlock;
	}

	/**
	 * Fills the opening with membrane. Refuses if anything else is inside, so another mod's portal
	 * already filling the frame wins (entry_path.md).
	 */
	public static boolean open(ServerLevel level, SiftFrame frame) {
		for (BlockPos pos : frame.opening()) {
			if (!isClearable(level.getBlockState(pos))) {
				return false;
			}
		}
		BlockState membrane = ModBlocks.SIFT_MEMBRANE.defaultBlockState().setValue(SiftMembraneBlock.AXIS, frame.axis());
		boolean changed = false;
		for (BlockPos pos : frame.opening()) {
			if (!level.getBlockState(pos).is(ModBlocks.SIFT_MEMBRANE)) {
				level.setBlock(pos, membrane, Block.UPDATE_CLIENTS);
				changed = true;
			}
		}
		if (changed) {
			Vec3 c = frame.center();
			level.playSound(null, BlockPos.containing(c), SoundEvents.AMETHYST_BLOCK_RESONATE, SoundSource.BLOCKS, 2.0F, 0.6F);
			level.playSound(null, BlockPos.containing(c), SoundEvents.PORTAL_TRIGGER, SoundSource.BLOCKS, 0.4F, 1.6F);
			level.sendParticles(ParticleTypes.GLOW, c.x, c.y, c.z, 40, frame.width() / 4.0, frame.height() / 4.0, frame.width() / 4.0, 0.0);
		}
		return changed;
	}

	/** Awake but closed frames drift note particles: the hint that they now want music. */
	private static void hintAwakeFrames(ServerLevel level) {
		if (level.dimension() != Level.OVERWORLD || level.getGameTime() % 20 != 0) {
			return;
		}
		for (SiftLinks.FrameLink link : SiftLinks.get(level.getServer()).frames()) {
			SiftFrame frame = link.frame();
			Vec3 c = frame.center();
			// Cheapest checks first, and never read a block in a chunk that isn't loaded.
			if (link.awake() && level.getNearestPlayer(c.x, c.y, c.z, 32, false) != null
					&& level.isLoaded(frame.at(1, 1)) && !isOpen(level, frame)) {
				level.sendParticles(ParticleTypes.NOTE, c.x, c.y, c.z, 3, frame.width() / 4.0, frame.height() / 4.0, frame.width() / 4.0, 0.0);
			}
		}
	}
}
