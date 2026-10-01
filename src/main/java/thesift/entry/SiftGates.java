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

import thesift.registry.ModBlocks;
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
			SiftFrame gate = link.gate().orElseGet(() -> links.setGate(link.frame(), build(sift, links, link.frame())).gate().orElseThrow());
			FrameMusic.open(sift, gate); // a removed membrane never strands anyone
			return arriveAt(sift, gate, entity);
		}
		if (SiftKeys.isSift(from)) {
			SiftLinks.FrameLink link = links.frameWithGateOpening(pos).orElse(null);
			if (link == null) {
				return null;
			}
			ServerLevel overworld = server.overworld();
			FrameMusic.open(overworld, link.frame());
			return arriveAt(overworld, link.frame(), entity);
		}
		return null;
	}

	private static TeleportTransition arriveAt(ServerLevel level, SiftFrame frame, Entity entity) {
		return new TeleportTransition(level, frame.arrival(), Vec3.ZERO, entity.getYRot(), entity.getXRot(),
				TeleportTransition.PLAY_PORTAL_SOUND.then(TeleportTransition.PLACE_PORTAL_TICKET));
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
				if (link.gate().isPresent()) {
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
		int top = Mth.clamp(ground(sift, cx, cz), sift.getMinY() + 8, sift.getMaxY() - SiftFrame.GATE_HEIGHT - 4);

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

	/** The y of the first free block above the ground at x/z, looking through trees and plants. */
	private static int ground(ServerLevel level, int x, int z) {
		BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos(x, level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x, z), z);
		while (pos.getY() > level.getMinY() + 1 && isLoose(level.getBlockState(pos.below()))) {
			pos.move(Direction.DOWN);
		}
		return pos.getY();
	}

	private static boolean isLoose(BlockState state) {
		return state.isAir() || state.canBeReplaced() || state.is(BlockTags.LOGS) || state.is(BlockTags.LEAVES);
	}

	/** A round hill: a flat top of radius 3 at {@code top}, sloping down to radius 7, cleared above. */
	private static void buildMound(ServerLevel level, int cx, int top, int cz) {
		int clearTo = top + SiftFrame.GATE_HEIGHT + 3;
		BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
		for (int dx = -MOUND_RADIUS; dx <= MOUND_RADIUS; dx++) {
			for (int dz = -MOUND_RADIUS; dz <= MOUND_RADIUS; dz++) {
				double d = Math.sqrt(dx * dx + dz * dz);
				if (d > MOUND_RADIUS + 0.5) {
					continue;
				}
				int columnTop = top - 1 - (int) Math.max(0, (d - PLATEAU_RADIUS) * 0.6);
				pos.set(cx + dx, columnTop, cz + dz);
				level.setBlock(pos, ModBlocks.HEALTHY_SCULK.defaultBlockState(), Block.UPDATE_ALL);
				pos.move(Direction.DOWN);
				while (pos.getY() > level.getMinY() && isLoose(level.getBlockState(pos))) {
					level.setBlock(pos, ModBlocks.HYMNSTONE.defaultBlockState(), Block.UPDATE_ALL);
					pos.move(Direction.DOWN);
				}
				for (int y = columnTop + 1; y <= clearTo; y++) {
					pos.set(cx + dx, y, cz + dz);
					if (!level.getBlockState(pos).isAir()) {
						level.setBlock(pos, Blocks.AIR.defaultBlockState(), Block.UPDATE_ALL);
					}
				}
			}
		}
	}
}
