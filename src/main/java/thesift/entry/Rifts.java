package thesift.entry;

import java.util.List;

import org.jspecify.annotations.Nullable;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.GlobalPos;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.stats.Stats;
import net.minecraft.tags.FluidTags;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.level.storage.LevelData;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.TheSift;
import thesift.entity.rift.RiftEntity;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModGameRules;
import thesift.registry.ModSounds;
import thesift.registry.ModTags;
import thesift.world.SiftKeys;

/**
 * Rifts between the Overworld and the Sift (survival_sift.md §2, §3): where a rift leads, safe ground on
 * the far side, natural rifts near players, and the Sift start for first-time players.
 */
public final class Rifts {
	/** How far a landing may stray from its own column before a platform is built (§2.1). */
	public static final int LANDING_SEARCH = 32;
	/** Natural rifts open 24-48 blocks from a player, never within 16 of another (§2.2). */
	public static final int NATURAL_MIN = 24;
	public static final int NATURAL_MAX = 48;
	public static final int SPACING = 16;
	/** Mean ticks between natural rifts per player: 40 minutes in the Overworld, 10 in the Sift. */
	public static final int OVERWORLD_MEAN = 48_000;
	public static final int SIFT_MEAN = 12_000;
	/** The Sift start looks this far around 0, 0 for dry ground (§3). */
	public static final int START_SEARCH = 64;
	private static final int CHECK_EVERY = 20;

	private Rifts() {
	}

	public static void init() {
		ServerTickEvents.END_SERVER_TICK.register(Rifts::tick);
		ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> startInSift(handler.player));
	}

	/** Whether rifts open in this level: the Overworld and the Sift only. */
	public static boolean riftsOpenIn(Level level) {
		return level.dimension() == Level.OVERWORLD || SiftKeys.isSift(level);
	}

	/** Opens a rift standing at {@code feet} for {@code lifetime} ticks, with its sound (heard 64 blocks off). */
	public static RiftEntity open(ServerLevel level, Vec3 feet, int lifetime) {
		RiftEntity rift = ModEntities.RIFT.create(level, EntitySpawnReason.TRIGGERED);
		rift.setPos(feet);
		rift.open(level.getGameTime(), lifetime);
		level.addFreshEntity(rift);
		level.playSound(null, feet.x, feet.y + 1.5, feet.z, ModSounds.RIFT_OPEN, SoundSource.AMBIENT, 4.0F, 1.0F);
		return rift;
	}

	/** Where a player walking into a rift in {@code from} arrives: the other world, same x and z, on safe ground. */
	public static @Nullable TeleportTransition destination(ServerLevel from, ServerPlayer player) {
		MinecraftServer server = from.getServer();
		ServerLevel to = SiftKeys.isSift(from) ? server.overworld() : from.dimension() == Level.OVERWORLD ? server.getLevel(SiftKeys.LEVEL) : null;
		if (to == null) {
			return null;
		}
		BlockPos feet = landing(to, player.getBlockX(), player.getBlockZ());
		return new TeleportTransition(to, Vec3.atBottomCenterOf(feet), Vec3.ZERO, player.getYRot(), player.getXRot(),
				SiftGates.CROSSING_SOUND.then(TeleportTransition.PLACE_PORTAL_TICKET));
	}

	/**
	 * Safe ground for a traveller at x, z (§2.1): the column's highest standable ground; else the nearest
	 * within {@link #LANDING_SEARCH}, ring by ring; else a 3 × 3 platform of the world's stone at its surface.
	 */
	public static BlockPos landing(ServerLevel level, int x, int z) {
		BlockPos found = standable(level, x, z, false);
		for (int r = 4; found == null && r <= LANDING_SEARCH; r += 4) {
			found = ring(level, x, z, r, false);
		}
		return found != null ? found : platform(level, x, z);
	}

	private static @Nullable BlockPos ring(ServerLevel level, int x, int z, int r, boolean dry) {
		for (int d = -r; d < r; d += 4) {
			for (int[] p : new int[][] {{x + d, z - r}, {x + r, z + d}, {x - d, z + r}, {x - r, z - d}}) {
				BlockPos found = standable(level, p[0], p[1], dry);
				if (found != null) {
					return found;
				}
			}
		}
		return null;
	}

	/**
	 * The feet position on the column's highest ground, if one can stand there: solid footing (or, in the
	 * Sift, ichor one deep over it unless {@code dry}), two free cells, no water or lava.
	 */
	public static @Nullable BlockPos standable(ServerLevel level, int x, int z, boolean dry) {
		level.getChunk(x >> 4, z >> 4); // generated in full, so the heightmap is the real ground
		int y = level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x, z);
		if (y <= level.getMinY() + 1 || y >= level.getMaxY() - 2) {
			return null;
		}
		BlockPos feet = new BlockPos(x, y, z);
		BlockPos under = feet.below();
		if (!level.getFluidState(under).isEmpty()) {
			// Shallow ichor in the Sift is no hazard: stand in it, on its floor.
			boolean shallow = SiftKeys.isSift(level) && !dry && level.getFluidState(under).is(ModTags.ICHOR)
					&& level.getFluidState(under.below()).isEmpty() && level.getBlockState(under.below()).isFaceSturdy(level, under.below(), Direction.UP);
			if (!shallow) {
				return null;
			}
			feet = under;
			under = under.below();
		}
		return level.getBlockState(under).isFaceSturdy(level, under, Direction.UP) && free(level, feet) && free(level, feet.above()) ? feet : null;
	}

	private static boolean free(ServerLevel level, BlockPos pos) {
		BlockState state = level.getBlockState(pos);
		return state.getCollisionShape(level, pos).isEmpty() && !level.getFluidState(pos).is(FluidTags.LAVA)
				&& (SiftKeys.isSift(level) || level.getFluidState(pos).isEmpty());
	}

	/** A 3 × 3 floor of the world's stone at the column's surface, two cells cleared above it (§2.1). */
	private static BlockPos platform(ServerLevel level, int x, int z) {
		int y = Math.max(level.getHeight(Heightmap.Types.WORLD_SURFACE, x, z), level.getSeaLevel() + 1);
		y = Math.min(y, level.getMaxY() - 3);
		BlockState stone = SiftKeys.isSift(level) ? ModBlocks.HYMNSTONE.defaultBlockState() : Blocks.COBBLESTONE.defaultBlockState();
		for (int dx = -1; dx <= 1; dx++) {
			for (int dz = -1; dz <= 1; dz++) {
				level.setBlock(new BlockPos(x + dx, y - 1, z + dz), stone, Block.UPDATE_ALL);
				for (int up = 0; up < 2; up++) {
					level.setBlock(new BlockPos(x + dx, y + up, z + dz), Blocks.AIR.defaultBlockState(), Block.UPDATE_ALL);
				}
			}
		}
		return new BlockPos(x, y, z);
	}

	private static void tick(MinecraftServer server) {
		if (server.getTickCount() % CHECK_EVERY != 0) {
			return;
		}
		for (ServerPlayer player : server.getPlayerList().getPlayers()) {
			ServerLevel level = player.level();
			if (player.isSpectator() || !riftsOpenIn(level) || !level.getGameRules().get(ModGameRules.SPAWN_RIFTS)) {
				continue;
			}
			int mean = SiftKeys.isSift(level) ? SIFT_MEAN : OVERWORLD_MEAN;
			if (player.getRandom().nextInt(mean / CHECK_EVERY) == 0) {
				BlockPos spot = naturalSpot(level, player.blockPosition(), player.getRandom());
				if (spot != null) {
					open(level, Vec3.atBottomCenterOf(spot), RiftEntity.NATURAL_LIFE);
				}
			}
		}
	}

	/**
	 * A spot for a natural rift (§2.2): 24-48 blocks from {@code around}, on the surface or in a cave, where
	 * a rift's 2 × 3 space stands on solid ground in loaded chunks, and no rift within 16. Null if none of
	 * a few tries fits.
	 */
	public static @Nullable BlockPos naturalSpot(ServerLevel level, BlockPos around, RandomSource random) {
		for (int attempt = 0; attempt < 16; attempt++) {
			double angle = random.nextDouble() * Math.PI * 2.0;
			double dist = NATURAL_MIN + random.nextDouble() * (NATURAL_MAX - NATURAL_MIN);
			int x = around.getX() + (int) Math.round(Math.cos(angle) * dist);
			int z = around.getZ() + (int) Math.round(Math.sin(angle) * dist);
			if (!level.isLoaded(new BlockPos(x, around.getY(), z)) || !level.isLoaded(new BlockPos(x + 1, around.getY(), z))) {
				continue;
			}
			for (int y = around.getY() + 12; y >= around.getY() - 12; y--) {
				BlockPos feet = new BlockPos(x, y, z);
				if (riftFits(level, feet)) {
					List<RiftEntity> near = level.getEntitiesOfClass(RiftEntity.class, new AABB(feet).inflate(SPACING));
					if (near.isEmpty()) {
						return feet;
					}
					break;
				}
			}
		}
		return null;
	}

	/** Two columns of three free, dry cells on sturdy ground. */
	public static boolean riftFits(ServerLevel level, BlockPos feet) {
		for (BlockPos column : new BlockPos[] {feet, feet.east()}) {
			if (!level.getBlockState(column.below()).isFaceSturdy(level, column.below(), Direction.UP)) {
				return false;
			}
			for (int up = 0; up < 3; up++) {
				BlockPos cell = column.above(up);
				if (!level.getBlockState(cell).getCollisionShape(level, cell).isEmpty() || !level.getFluidState(cell).isEmpty()) {
					return false;
				}
			}
		}
		return true;
	}

	/** §3: with the game rule on, a player joining for the first time starts on the Sift's dry surface near 0, 0, their respawn point there. */
	private static void startInSift(ServerPlayer player) {
		ServerLevel overworld = player.level().getServer().overworld();
		ServerLevel sift = player.level().getServer().getLevel(SiftKeys.LEVEL);
		if (sift == null || !overworld.getGameRules().get(ModGameRules.START_IN_SIFT)
				|| player.getStats().getValue(Stats.CUSTOM.get(Stats.PLAY_TIME)) > 0) {
			return;
		}
		BlockPos feet = startSpot(sift);
		player.teleport(new TeleportTransition(sift, Vec3.atBottomCenterOf(feet), Vec3.ZERO, 0.0F, 0.0F, TeleportTransition.PLACE_PORTAL_TICKET));
		player.setRespawnPosition(new ServerPlayer.RespawnConfig(new LevelData.RespawnData(GlobalPos.of(SiftKeys.LEVEL, feet), 0.0F, 0.0F), true), false);
		TheSift.LOGGER.info("{} starts in the Sift at {}", player.getName().getString(), feet);
	}

	/** Dry, standable ground nearest 0, 0 in the Sift, ring by ring out to {@link #START_SEARCH}; else a platform there. */
	public static BlockPos startSpot(ServerLevel sift) {
		BlockPos found = standable(sift, 0, 0, true);
		for (int r = 4; found == null && r <= START_SEARCH; r += 4) {
			found = ring(sift, 0, 0, r, true);
		}
		return found != null ? found : platform(sift, 0, 0);
	}
}
