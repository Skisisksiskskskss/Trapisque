package thesift.world;

import java.util.ArrayList;
import java.util.List;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;

import thesift.block.TideVentBlock;
import thesift.registry.ModBlocks;

/**
 * A tide basin (world.md, rules.md "the tide is literal"): a sunken flat with a tide vent in the
 * middle of its floor. The inner pool is 4 below the ground and climbs out in three one-block steps
 * (rings), so a player can always walk or jump out, full or empty. It holds up to
 * {@link #MAX_LAYERS} layers of ichor, the top one a block below the rim, so a full basin never
 * spills. Numbers: system_tides.md.
 */
public record TideBasin(BlockPos vent, int inner) {
	/** One-block steps from the pool floor up toward the rim. */
	public static final int RINGS = 3;
	public static final int DEPTH = 4;
	public static final int MAX_LAYERS = 3;

	/** Half the basin's width: at most 6, so a basin centred in its chunk never leaves it. */
	public int half() {
		return this.inner + RINGS;
	}

	public boolean isInner(int dx, int dz) {
		int ax = Math.abs(dx);
		int az = Math.abs(dz);
		return Math.max(ax, az) <= this.inner && !(ax == this.inner && az == this.inner && this.inner > 0);
	}

	/** Inner half-widths worldgen uses (2–3); a test may use 0. */
	public static boolean validInner(int inner) {
		return inner >= 0 && inner <= 3;
	}

	public boolean inFootprint(int dx, int dz) {
		int ax = Math.abs(dx);
		int az = Math.abs(dz);
		return Math.max(ax, az) <= this.half() && ax + az <= 2 * this.half() - 2;
	}

	/** Which step (0 = the pool, 1..RINGS = the rings outward) the cell (dx, dz) belongs to. */
	public int ring(int dx, int dz) {
		if (this.isInner(dx, dz)) {
			return 0;
		}
		// Distance that follows the rounded corners, so the rings step up evenly there too.
		int ax = Math.abs(dx);
		int az = Math.abs(dz);
		int dist = Math.max(Math.max(ax, az), ax + az - (this.half() - 2));
		return Math.max(1, Math.min(RINGS, dist - this.inner));
	}

	/** The floor's y under (dx, dz): the vent's level in the pool, one higher per ring outward. */
	public int floorY(int dx, int dz) {
		return this.vent.getY() + this.ring(dx, dz);
	}

	/** The cells of fill layer {@code k} (0 = just above the pool floor). */
	public List<BlockPos> layer(int k) {
		int y = this.vent.getY() + 1 + k;
		List<BlockPos> out = new ArrayList<>();
		for (int dx = -this.half(); dx <= this.half(); dx++) {
			for (int dz = -this.half(); dz <= this.half(); dz++) {
				if (this.inFootprint(dx, dz) && y > this.floorY(dx, dz)) {
					out.add(this.vent.offset(dx, y - this.vent.getY(), dz));
				}
			}
		}
		return out;
	}

	/**
	 * How many layers the Tide wants at {@code cycleTick}: none in Thrive, all in Endure, and one
	 * layer per step through each Flow (systems.md §1).
	 */
	public static int targetLayers(long cycleTick) {
		long t = Math.floorMod(cycleTick, Tide.PERIOD_TICKS);
		Tide tide = Tide.atCycleTick(t);
		return switch (tide) {
			case THRIVE -> 0;
			case ENDURE -> MAX_LAYERS;
			case FLOW_RISING -> Math.min(MAX_LAYERS, 1 + (int) ((t - Tide.FLOW_RISING.startTick()) * MAX_LAYERS / flowLength(Tide.FLOW_RISING)));
			case FLOW_FALLING -> Math.max(0, MAX_LAYERS - 1 - (int) ((t - Tide.FLOW_FALLING.startTick()) * MAX_LAYERS / flowLength(Tide.FLOW_FALLING)));
		};
	}

	private static long flowLength(Tide flow) {
		return flow == Tide.FLOW_RISING ? Tide.ENDURE.startTick() - Tide.FLOW_RISING.startTick() : Tide.PERIOD_TICKS - Tide.FLOW_FALLING.startTick();
	}

	/** Digs the basin into the ground (worldgen, or a test) and sets the vent. Returns blocks changed. */
	public int carve(LevelAccessor level) {
		int changed = 0;
		int ground = this.vent.getY() + DEPTH;
		for (int dx = -this.half(); dx <= this.half(); dx++) {
			for (int dz = -this.half(); dz <= this.half(); dz++) {
				if (!this.inFootprint(dx, dz)) {
					continue;
				}
				int floor = this.floorY(dx, dz);
				BlockPos floorPos = this.vent.offset(dx, floor - this.vent.getY(), dz);
				level.setBlock(floorPos, ModBlocks.TIDE_SAND.defaultBlockState(), Block.UPDATE_CLIENTS);
				if (level.getBlockState(floorPos.below()).isAir()) {
					level.setBlock(floorPos.below(), ModBlocks.HYMNSTONE.defaultBlockState(), Block.UPDATE_CLIENTS);
				}
				// Clear to two above the ground, and on through any higher terrain or trees in the way.
				for (int y = floor + 1; y <= ground + 2 || (y <= ground + 10 && !level.getBlockState(floorPos.atY(y)).isAir()); y++) {
					BlockPos p = floorPos.atY(y);
					if (!level.getBlockState(p).isAir()) {
						level.setBlock(p, Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS);
						changed++;
					}
				}
			}
		}
		BlockState vent = ModBlocks.TIDE_VENT.defaultBlockState().setValue(TideVentBlock.BASIN, TideVentBlock.basinValue(this.inner));
		level.setBlock(this.vent, vent, Block.UPDATE_CLIENTS);
		return changed;
	}
}
