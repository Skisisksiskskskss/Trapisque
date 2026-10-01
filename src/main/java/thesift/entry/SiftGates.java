package thesift.entry;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.phys.Vec3;

import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.protocol.game.ClientboundSoundPacket;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import thesift.registry.ModSounds;
import thesift.entity.blub.BlubCrossing;
import thesift.registry.ModBlocks;
import thesift.world.TideBasin;
import thesift.world.SiftKeys;

/**
 * Steps 6 and 8 of the entry (entry_path.md): crossing a frame arrives at its Sift-side gate,
 * built on first use at the matching x/z (1:1); crossing the gate returns to the frame.
 */
public final class SiftGates {
	/** Gates keep at least this far apart, so two cities never share one. */
	public static final int SPACING = 64;
	private static final int MOUND_RADIUS = 7;
	private static final int PLATEAU_RADIUS = 3;
	private static final int HILL_RISE = 2;

	private SiftGates() {
	}

	/** Where an entity in the membrane at {@code pos} goes, or null for a membrane we did not make. */
	public static @Nullable TeleportTransition destination(ServerLevel from, Entity entity, BlockPos pos) {
		MinecraftServer server = from.getServer();
		SiftLinks links = SiftLinks.get(server);
		if (from.dimension() == Level.OVERWORLD) {
			SiftLinks.FrameLink link = links.frameWithOpening(pos).orElse(null);
			ServerLevel sift = server.getLevel(SiftKeys.LEVEL);
			if (link == null || sift == null) {
				return null;
			}
			SiftFrame gate = link.gate().orElse(null);
			// Built on the first crossing; rebuilt if it is gone (e.g. the Sift's region files were reset).
			if (gate == null || !sift.getBlockState(gate.origin()).is(ModBlocks.GATESTONE)) {
				gate = links.setGate(link.frame(), build(sift, links, link.frame())).gate().orElseThrow();
			}
			FrameMusic.open(sift, gate); // a removed membrane never strands anyone
			return crossing(from, entity, arrivalClear(sift, gate) ? arriveAt(sift, gate, entity) : null);
		}
		if (SiftKeys.isSift(from)) {
			SiftLinks.FrameLink link = links.frameWithGateOpening(pos).orElse(null);
			if (link == null) {
				return null;
			}
			ServerLevel overworld = server.overworld();
			FrameMusic.open(overworld, link.frame());
			return crossing(from, entity, arrivalClear(overworld, link.frame()) ? arriveAt(overworld, link.frame(), entity) : null);
		}
		return null;
	}

	/** A player about to cross: note where, so their blubs can follow (BlubCrossing). */
	private static @Nullable TeleportTransition crossing(ServerLevel from, Entity entity, @Nullable TeleportTransition transition) {
		if (transition != null && entity instanceof ServerPlayer player) {
			BlubCrossing.recordEntry(player, from);
		}
		return transition;
	}

	private static final TeleportTransition.PostTeleportTransition CROSSING_SOUND = SiftGates::playCrossingSound;

	/** The crossing chime, heard by the traveller only (as vanilla's portal travel sound is). */
	private static void playCrossingSound(Entity entity) {
		if (entity instanceof ServerPlayer player && player.connection != null) {
			player.connection.send(new ClientboundSoundPacket(BuiltInRegistries.SOUND_EVENT.wrapAsHolder(ModSounds.MEMBRANE_TRAVEL),
					SoundSource.BLOCKS, player.getX(), player.getY(), player.getZ(), 0.8F, 1.0F, player.getRandom().nextLong()));
		}
	}

	/** Never send anyone into stone: the arrival's two cells must have no collision. */
	private static boolean arrivalClear(ServerLevel level, SiftFrame frame) {
		BlockPos feet = BlockPos.containing(frame.arrival());
		return level.getBlockState(feet).getCollisionShape(level, feet).isEmpty()
				&& level.getBlockState(feet.above()).getCollisionShape(level, feet.above()).isEmpty();
	}

	private static TeleportTransition arriveAt(ServerLevel level, SiftFrame frame, Entity entity) {
		return new TeleportTransition(level, frame.arrival(), Vec3.ZERO, entity.getYRot(), entity.getXRot(),
				CROSSING_SOUND.then(TeleportTransition.PLACE_PORTAL_TICKET));
	}

	/** Builds a gate for {@code cityFrame} in the Sift: a healthy-sculk mound topped by a gatestone frame. */
	public static SiftFrame build(ServerLevel sift, SiftLinks links, SiftFrame cityFrame) {
		Vec3 c = cityFrame.center();
		double x = c.x;
		double z = c.z;
		// Step away from any gate closer than SPACING (a few passes settle even crowded spots).
		for (int pass = 0; pass < 8; pass++) {
			SiftFrame near = null;
			double best = SPACING;
			for (SiftLinks.FrameLink link : links.frames()) {
				if (link.gate().isPresent() && !link.frame().equals(cityFrame)) {
					Vec3 g = link.gate().get().center();
					double d = Math.hypot(g.x - x, g.z - z);
					if (d < best) {
						best = d;
						near = link.gate().get();
					}
				}
			}
			if (near == null) {
				break;
			}
			Vec3 g = near.center();
			double dx = x - g.x;
			double dz = z - g.z;
			double len = Math.hypot(dx, dz);
			if (len < 1.0E-3) {
				dx = 1;
				dz = 0;
				len = 1;
			}
			x = g.x + dx / len * (SPACING + 1);
			z = g.z + dz / len * (SPACING + 1);
		}
		BlockPos clamped = sift.getWorldBorder().clampToBounds(x, 0, z);
		int cx = clamped.getX();
		int cz = clamped.getZ();
		sift.getChunk(cx >> 4, cz >> 4); // generates the terrain if nobody has been here
		// The plateau stands HILL_RISE above the ground, so the slope ends at the natural surface.
		int top = Mth.clamp(ground(sift, cx, cz) + HILL_RISE, sift.getMinY() + 8, sift.getMaxY() - SiftFrame.GATE_HEIGHT - 4);

		buildMound(sift, cx, top, cz);
		Direction.Axis axis = cityFrame.axis();
		int half = SiftFrame.GATE_WIDTH / 2;
		BlockPos origin = axis == Direction.Axis.X ? new BlockPos(cx - half, top, cz) : new BlockPos(cx, top, cz - half);
		SiftFrame gate = new SiftFrame(origin, axis, SiftFrame.GATE_WIDTH, SiftFrame.GATE_HEIGHT);
		for (BlockPos pos : gate.border()) {
			sift.setBlock(pos, ModBlocks.GATESTONE.defaultBlockState(), Block.UPDATE_ALL);
		}
		return gate;
	}

	/** The y of the first free block above the ground at x/z, looking through trees and plants but not liquids. */
	private static int ground(ServerLevel level, int x, int z) {
		BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos(x, level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x, z), z);
		while (pos.getY() > level.getMinY() + 1) {
			BlockState below = level.getBlockState(pos.below());
			if (!isLoose(below) || !below.getFluidState().isEmpty()) {
				break;
			}
			pos.move(Direction.DOWN);
		}
		return pos.getY();
	}

	/**
	 * Sets a block, first touching any block entity there so a freshly generated one (still pending
	 * in its chunk) is removed with the block instead of being promoted onto the new block later.
	 */
	private static void replace(ServerLevel level, BlockPos pos, BlockState state) {
		if (level.getBlockState(pos).hasBlockEntity()) {
			level.getBlockEntity(pos);
		}
		level.setBlock(pos, state, Block.UPDATE_ALL);
	}

	private static boolean isLoose(BlockState state) {
		return state.isAir() || state.canBeReplaced() || state.is(BlockTags.LOGS) || state.is(BlockTags.LEAVES);
	}

	/**
	 * A round hill: a flat top of radius 3 whose surface block is at {@code top - 1}, sloping 0.6 a
	 * block down to the natural ground by radius 7. The gate's own
	 * space (radius 4.5) is cleared; beyond it natural ground higher than the slope is left alone,
	 * so the hill never digs a ditch. Liquids under the hill are filled.
	 */
	private static void buildMound(ServerLevel level, int cx, int top, int cz) {
		int clearTo = top + SiftFrame.GATE_HEIGHT + 3;
		BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
		for (int dx = -MOUND_RADIUS; dx <= MOUND_RADIUS; dx++) {
			for (int dz = -MOUND_RADIUS; dz <= MOUND_RADIUS; dz++) {
				double d = Math.sqrt(dx * dx + dz * dz);
				if (d > MOUND_RADIUS + 0.5) {
					continue;
				}
				int hill = top - 1 - (int) Math.max(0, (d - PLATEAU_RADIUS) * 0.6);
				boolean gateSpace = d <= PLATEAU_RADIUS + 1.5;
				int natural = ground(level, cx + dx, cz + dz) - 1;
				if (!gateSpace && natural >= hill) {
					continue; // the land already stands as high as the hill here
				}
				pos.set(cx + dx, hill, cz + dz);
				replace(level, pos, ModBlocks.HEALTHY_SCULK.defaultBlockState());
				pos.move(Direction.DOWN);
				while (pos.getY() > level.getMinY() && isLoose(level.getBlockState(pos))) {
					replace(level, pos, ModBlocks.HYMNSTONE.defaultBlockState());
					pos.move(Direction.DOWN);
				}
				// A tide basin under the hill is retired: its vent would refill whatever pocket is left.
				for (int y = pos.getY(); y > pos.getY() - TideBasin.DEPTH - 2 && y > level.getMinY(); y--) {
					BlockPos below = new BlockPos(cx + dx, y, cz + dz);
					if (level.getBlockState(below).is(ModBlocks.TIDE_VENT)) {
						replace(level, below, ModBlocks.HYMNSTONE.defaultBlockState());
					}
				}
				for (int y = hill + 1; y <= clearTo; y++) {
					pos.set(cx + dx, y, cz + dz);
					if (!level.getBlockState(pos).isAir()) {
						replace(level, pos, Blocks.AIR.defaultBlockState());
					}
				}
			}
		}
	}
}
