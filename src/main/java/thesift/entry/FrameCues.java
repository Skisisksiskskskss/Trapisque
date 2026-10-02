package thesift.entry;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.jspecify.annotations.Nullable;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.protocol.game.ClientboundSoundPacket;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.ChunkPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.world.level.levelgen.structure.BoundingBox;
import net.minecraft.world.level.levelgen.structure.BuiltinStructures;
import net.minecraft.world.level.levelgen.structure.PoolElementStructurePiece;
import net.minecraft.world.level.levelgen.structure.Structure;
import net.minecraft.world.level.levelgen.structure.StructurePiece;
import net.minecraft.world.level.levelgen.structure.StructureStart;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModSounds;
import thesift.world.SiftAdvancements;
import thesift.world.SoulPoints;

/**
 * Stages 1 and 2 of the entry (entry_path.md): a dormant frame <em>breathes</em> (soul wisps drift
 * into its opening while a player is within 32 blocks), and <em>notices</em> a player with
 * experience within 8 (wisps rise from them toward it, more with an empty hand, and a breathy cue
 * with the subtitle "Your soul stirs toward the frame"). Being noticed grants the tab's root.
 *
 * <p>Frames are found from the Ancient City's structure data, not by scanning around players: when a
 * player stands in a city, its {@code city_center} piece is searched once for the frame (only when
 * all its chunks are loaded) and the result is cached per city for the server's run.
 */
public final class FrameCues {
	public static final double RUMOR_RANGE = 32.0;
	public static final double NOTICE_RANGE = 8.0;
	private static final int DISCOVER_INTERVAL = 40;
	/** A city's frame, or none found; a "none" is searched again after {@link #RETRY_TICKS}. */
	private record City(Optional<SiftFrame> frame, long retryAt) {
	}

	private static final long RETRY_TICKS = 6000;
	/** City start chunk → what was found there. */
	private static final Map<Long, City> CITIES = new HashMap<>();

	private FrameCues() {
	}

	public static void init() {
		ServerTickEvents.END_LEVEL_TICK.register(FrameCues::tick);
		ServerLifecycleEvents.SERVER_STARTED.register(server -> CITIES.clear());
	}

	private static void tick(ServerLevel level) {
		// Game time stands still under /tick freeze, so every "now % n" below would fire each tick.
		if (level.dimension() != Level.OVERWORLD || level.players().isEmpty() || !level.tickRateManager().runsNormally()) {
			return;
		}
		long now = level.getGameTime();
		java.util.Set<SiftFrame> breathing = new java.util.HashSet<>();
		for (ServerPlayer player : level.players()) {
			if (player.isSpectator()) {
				continue;
			}
			if (now % DISCOVER_INTERVAL == 0) {
				discover(level, player.blockPosition());
			}
			SiftFrame frame = nearestDormant(level, player.position());
			if (frame == null) {
				continue;
			}
			breathing.add(frame);
			if (frame.distanceTo(player.position()) <= NOTICE_RANGE && SoulPoints.total(player) > 0) {
				notice(level, player, frame, now);
			}
		}
		if (now % 4 == 0) {
			for (SiftFrame frame : breathing) { // once per frame, however many players are near
				breathe(level, frame, level.getRandom());
			}
		}
	}

	/**
	 * Finds (once) the frame of the Ancient City {@code pos} stands in. Returns it, or null. Never
	 * loads a chunk: the city is read from the structure references stored in {@code pos}'s own
	 * (loaded) chunk, and its start chunk is used only if it is loaded already. A cached frame whose
	 * border is broken is forgotten; a city where none was found is searched again later.
	 */
	public static @Nullable SiftFrame discover(ServerLevel level, BlockPos pos) {
		Structure city = level.registryAccess().lookupOrThrow(Registries.STRUCTURE).getValue(BuiltinStructures.ANCIENT_CITY);
		LevelChunk here = level.getChunkSource().getChunkNow(pos.getX() >> 4, pos.getZ() >> 4);
		if (city == null || here == null) {
			return null;
		}
		for (long ref : here.getReferencesForStructure(city)) {
			LevelChunk startChunk = level.getChunkSource().getChunkNow(ChunkPos.getX(ref), ChunkPos.getZ(ref));
			StructureStart start = startChunk == null ? null : startChunk.getStartForStructure(city);
			if (start == null || !start.isValid() || !start.getBoundingBox().isInside(pos)) {
				continue;
			}
			City known = CITIES.get(ref);
			if (known != null && known.frame().isPresent()) {
				if (borderIntact(level, known.frame().get())) {
					return known.frame().get();
				}
				CITIES.remove(ref); // broken (e.g. in creative): stays dormant, no cues
				return null;
			}
			if (known != null && level.getGameTime() < known.retryAt()) {
				return null;
			}
			Optional<SiftFrame> found = findFrame(level, start);
			if (found != null) {
				CITIES.put(ref, new City(found, level.getGameTime() + RETRY_TICKS));
				return found.orElse(null);
			}
		}
		return null;
	}

	/** True if the frame's whole border is still reinforced deepslate (true while its chunks are unloaded). */
	static boolean borderIntact(ServerLevel level, SiftFrame frame) {
		for (BlockPos p : frame.border()) {
			if (level.getChunkSource().getChunkNow(p.getX() >> 4, p.getZ() >> 4) == null) {
				return true;
			}
			if (!level.getBlockState(p).is(Blocks.REINFORCED_DEEPSLATE)) {
				return false;
			}
		}
		return true;
	}

	/**
	 * Searches the city's centre piece for the reinforced-deepslate frame. Null if any of the piece's
	 * chunks isn't loaded yet (never loads one); empty if the piece has no frame.
	 */
	static @Nullable Optional<SiftFrame> findFrame(ServerLevel level, StructureStart start) {
		for (StructurePiece piece : start.getPieces()) {
			if (!(piece instanceof PoolElementStructurePiece pool) || !pool.getElement().toString().contains("city_center/city_center")) {
				continue;
			}
			BoundingBox box = piece.getBoundingBox();
			for (int cx = box.minX() >> 4; cx <= box.maxX() >> 4; cx++) {
				for (int cz = box.minZ() >> 4; cz <= box.maxZ() >> 4; cz++) {
					if (level.getChunkSource().getChunkNow(cx, cz) == null) {
						return null;
					}
				}
			}
			BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
			for (int y = box.maxY(); y >= box.minY(); y--) {
				for (int x = box.minX(); x <= box.maxX(); x++) {
					for (int z = box.minZ(); z <= box.maxZ(); z++) {
						if (level.getBlockState(p.set(x, y, z)).is(Blocks.REINFORCED_DEEPSLATE)) {
							Optional<SiftFrame> frame = FrameShapes.find(level, p.immutable(), Blocks.REINFORCED_DEEPSLATE,
									SiftFrame.CITY_WIDTH, SiftFrame.CITY_HEIGHT);
							if (frame.isPresent()) {
								return frame;
							}
						}
					}
				}
			}
			return Optional.empty();
		}
		return Optional.empty();
	}

	/** The nearest known frame within the rumor range that isn't awake yet. */
	static @Nullable SiftFrame nearestDormant(ServerLevel level, Vec3 pos) {
		SiftLinks links = SiftLinks.get(level.getServer());
		SiftFrame best = null;
		double bestDist = RUMOR_RANGE;
		for (City entry : CITIES.values()) {
			if (entry.frame().isEmpty()) {
				continue;
			}
			SiftFrame frame = entry.frame().get();
			double d = frame.distanceTo(pos);
			if (d <= bestDist && links.frameWithBorder(frame.origin()).map(l -> !l.awake()).orElse(true)) {
				bestDist = d;
				best = frame;
			}
		}
		return best;
	}

	/**
	 * Rumor: a soul wisp appears a little in front of (or behind) the opening and drifts into it. A
	 * soul particle travels about 1.5 blocks at this speed (friction 0.96), so it starts 1.2 out.
	 * Sent past the 32-block particle limit, so everyone in the rumor range sees the same wisps.
	 */
	private static void breathe(ServerLevel level, SiftFrame frame, RandomSource random) {
		BlockPos cell = frame.at(1 + random.nextInt(frame.width() - 2), 1 + random.nextInt(frame.height() - 2));
		double side = random.nextBoolean() ? 1.2 : -1.2;
		boolean alongX = frame.axis() == Direction.Axis.X;
		Vec3 from = Vec3.atCenterOf(cell).add(alongX ? 0 : side, random.nextDouble() - 0.5, alongX ? side : 0);
		Vec3 v = new Vec3(alongX ? 0 : -side, 0.02, alongX ? -side : 0).normalize().scale(0.06);
		level.sendParticles(ParticleTypes.SOUL, true, false, from.x, from.y, from.z, 0, v.x, v.y, v.z, 1.0);
	}

	/**
	 * Notice: wisps rise from the player toward the frame (twice as many with an empty hand, which
	 * teaches the verb), a breathy cue now and then, heard by that player only. Nothing is taken.
	 */
	private static void notice(ServerLevel level, ServerPlayer player, SiftFrame frame, long now) {
		boolean emptyHand = player.getMainHandItem().isEmpty();
		if (now % (emptyHand ? 4 : 8) == 0) {
			// From the player's middle, half a block toward the frame: seen drifting away, not in the face.
			Vec3 toward = frame.center().subtract(player.position()).normalize();
			Vec3 from = player.position().add(toward.scale(0.6)).add(0, 0.5 + level.getRandom().nextDouble() * 0.5, 0);
			Vec3 v = frame.center().subtract(from).normalize().scale(0.08);
			level.sendParticles(ParticleTypes.SOUL, from.x, from.y, from.z, 0, v.x, v.y, v.z, 1.0);
		}
		if (now % 80 == 0 && player.connection != null) {
			player.connection.send(new ClientboundSoundPacket(BuiltInRegistries.SOUND_EVENT.wrapAsHolder(ModSounds.FRAME_NOTICE),
					SoundSource.BLOCKS, player.getX(), player.getY() + 1, player.getZ(), 0.7F, 1.0F, level.getRandom().nextLong()));
		}
		if (now % 20 == 0) {
			SiftAdvancements.award(player, SiftAdvancements.ROOT);
		}
	}
}
