package thesift.entry;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.jspecify.annotations.Nullable;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.protocol.game.ClientboundSoundPacket;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
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
	/** City start chunk → its frame (empty: searched, none found). */
	private static final Map<Long, Optional<SiftFrame>> CITIES = new HashMap<>();

	private FrameCues() {
	}

	public static void init() {
		ServerTickEvents.END_LEVEL_TICK.register(FrameCues::tick);
		ServerLifecycleEvents.SERVER_STARTED.register(server -> CITIES.clear());
	}

	private static void tick(ServerLevel level) {
		if (level.dimension() != Level.OVERWORLD || level.players().isEmpty()) {
			return;
		}
		long now = level.getGameTime();
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
			if (now % 8 == 0) {
				breathe(level, frame, level.getRandom());
			}
			if (frame.distanceTo(player.position()) <= NOTICE_RANGE && SoulPoints.total(player) > 0) {
				notice(level, player, frame, now);
			}
		}
	}

	/** Finds (once) the frame of the Ancient City {@code pos} stands in. Returns it, or null. */
	public static @Nullable SiftFrame discover(ServerLevel level, BlockPos pos) {
		Structure city = level.registryAccess().lookupOrThrow(Registries.STRUCTURE).getValue(BuiltinStructures.ANCIENT_CITY);
		if (city == null) {
			return null;
		}
		StructureStart start = level.structureManager().getStructureAt(pos, city);
		if (!start.isValid()) {
			return null;
		}
		long key = start.getChunkPos().pack();
		Optional<SiftFrame> known = CITIES.get(key);
		if (known != null) {
			return known.orElse(null);
		}
		Optional<SiftFrame> found = findFrame(level, start);
		if (found != null) {
			CITIES.put(key, found);
			return found.orElse(null);
		}
		return null;
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
		for (Optional<SiftFrame> entry : CITIES.values()) {
			if (entry.isEmpty()) {
				continue;
			}
			SiftFrame frame = entry.get();
			double d = frame.distanceTo(pos);
			if (d <= bestDist && links.frameWithBorder(frame.origin()).map(l -> !l.awake()).orElse(true)) {
				bestDist = d;
				best = frame;
			}
		}
		return best;
	}

	/** Rumor: a soul wisp rises from near the frame's foot and drifts into the opening. */
	private static void breathe(ServerLevel level, SiftFrame frame, RandomSource random) {
		Vec3 centre = frame.center();
		BlockPos foot = frame.at(1 + random.nextInt(frame.width() - 2), 0);
		Vec3 from = Vec3.atCenterOf(foot).add(random.nextGaussian() * 1.5, -0.5 + random.nextDouble(), random.nextGaussian() * 1.5);
		Vec3 v = centre.subtract(from).normalize().scale(0.06);
		level.sendParticles(ParticleTypes.SOUL, from.x, from.y, from.z, 0, v.x, v.y, v.z, 1.0);
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
