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
 * middle of its floor. The inner pool is 4 deep with a 2-wide terrace around it, so a player can
 * always climb out. It holds up to {@link #MAX_LAYERS} layers of ichor, the top one a block below
 * the rim, so a full basin never spills. Numbers: system_tides.md.
 */
public record TideBasin(BlockPos vent, int inner) {
	public static final int TERRACE = 2;
	public static final int DEPTH = 4;
	public static final int MAX_LAYERS = 3;

	/** Half the basin's width: at most 6, so a basin centred in its chunk never leaves it. */
	public int half() {
		return this.inner + TERRACE;
	}

	public boolean isInner(int dx, int dz) {
		int ax = Math.abs(dx);
		int az = Math.abs(dz);
		return Math.max(ax, az) <= this.inner && !(ax == this.inner && az == this.inner && this.inner > 0);
	}

	/** Inner half-widths worldgen uses (a test may use 0: a 5 x 5 basin). */
	public static boolean validInner(int inner) {
		return inner >= 0 && inner <= 4;
	}

	public boolean isTerrace(int dx, int dz) {
		int ax = Math.abs(dx);
		int az = Math.abs(dz);
		return !this.isInner(dx, dz) && Math.max(ax, az) <= this.half() && ax + az <= 2 * this.half() - 2;
	}

	public boolean inFootprint(int dx, int dz) {
		return this.isInner(dx, dz) || this.isTerrace(dx, dz);
	}

	/** The floor's y under (dx, dz): the vent's level in the pool, two higher on the terrace. */
	public int floorY(int dx, int dz) {
		return this.isInner(dx, dz) ? this.vent.getY() : this.vent.getY() + TERRACE;
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
