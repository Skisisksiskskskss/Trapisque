package thesift.block.entity;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

import thesift.registry.ModSounds;
import thesift.block.TideVentBlock;
import thesift.registry.ModBlockEntities;
import thesift.registry.ModBlocks;
import thesift.registry.ModFluids;
import thesift.world.Tide;
import thesift.world.TideBasin;

/**
 * Moves its basin's ichor toward what the Tide wants, one layer per update (every second), so the
 * work per tick stays bounded. It keeps no saved data: after any load it snaps straight to the
 * current level (at most 3 layers, under 800 blocks; systems.md §1).
 */
public class TideVentBlockEntity extends BlockEntity {
	public static final int UPDATE_INTERVAL = 20;
	/** Layers filled now; -1 until the first update after a load. */
	private int layers = -1;

	public TideVentBlockEntity(BlockPos pos, BlockState state) {
		super(ModBlockEntities.TIDE_VENT, pos, state);
	}

	public static void serverTick(Level level, BlockPos pos, BlockState state, TideVentBlockEntity vent) {
		// Spread vents over the second by position, so many basins don't all update on one tick.
		if (Math.floorMod(level.getGameTime() + pos.hashCode(), UPDATE_INTERVAL) == 0 && level instanceof ServerLevel serverLevel) {
			vent.update(serverLevel, Tide.clockTicks(level));
		}
	}

	public int layers() {
		return this.layers;
	}

	public TideBasin basin() {
		return new TideBasin(this.worldPosition, TideVentBlock.inner(this.getBlockState()));
	}

	/** One update at Tide clock time {@code cycleTick}. Returns the number of blocks changed. */
	public int update(ServerLevel level, long cycleTick) {
		if (this.getBlockState().getValue(TideVentBlock.BASIN) == 0) {
			return 0;
		}
		TideBasin basin = this.basin();
		int target = TideBasin.targetLayers(cycleTick);
		int changed = 0;
		if (this.layers < 0) {
			for (int k = 0; k < TideBasin.MAX_LAYERS; k++) {
				changed += k < target ? fill(level, basin, k) : drain(level, basin, k);
			}
			this.layers = target;
		} else if (this.layers < target) {
			changed = fill(level, basin, this.layers);
			this.layers++;
			level.playSound(null, this.worldPosition.above(this.layers), ModSounds.BASIN_FILL, SoundSource.BLOCKS, 1.0F, 1.0F);
		} else if (this.layers > target) {
			this.layers--;
			changed = drain(level, basin, this.layers);
			level.playSound(null, this.worldPosition.above(this.layers + 1), ModSounds.BASIN_DRAIN, SoundSource.BLOCKS, 1.0F, 1.0F);
		}
		return changed;
	}

	/** Fills empty cells only: a block a player put in the basin stays. */
	private static int fill(ServerLevel level, TideBasin basin, int k) {
		int changed = 0;
		BlockState ichor = ModBlocks.ICHOR.defaultBlockState();
		for (BlockPos p : basin.layer(k)) {
			BlockState state = level.getBlockState(p);
			if (state.isAir() || (state.is(ModBlocks.ICHOR) && !state.getFluidState().isSource())) {
				level.setBlock(p, ichor, Block.UPDATE_CLIENTS);
				changed++;
			}
		}
		return changed;
	}

	private static int drain(ServerLevel level, TideBasin basin, int k) {
		int changed = 0;
		for (BlockPos p : basin.layer(k)) {
			if (level.getFluidState(p).getType().isSame(ModFluids.ICHOR) && level.getBlockState(p).is(ModBlocks.ICHOR)) {
				level.setBlock(p, Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS);
				changed++;
			}
		}
		return changed;
	}
}
