package thesift.block;

import java.util.function.Consumer;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.TrailParticleOption;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.VegetationBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModSounds;
import thesift.world.Tide;

/**
 * A plant that keeps time with the Tide (block_flora_ii.md, D-027): tidewrack opens in Thrive, the
 * Endure bloom in Endure. It switches as vanilla's eyeblossom does (a random tick reads the Tide; a
 * switch ripples to the same plants nearby on short scheduled delays) and is picked as a sweet berry
 * bush is (use drops a harvest table and leaves the plant), only when it is ready: open, not picked
 * this cycle, and the logical Tide its own. Picked is a cycle stamp, so a plant left in an unloaded
 * chunk is fresh again in its next window. No tool gives the plant itself, and it never grows.
 */
public abstract class TideFloraBlock extends VegetationBlock {
	public static final BooleanProperty OPEN = BooleanProperty.create("open");
	/** 0 = unpicked; otherwise the cycle it was picked in, as {@link #stamp(Level)}. */
	public static final IntegerProperty PICKED_CYCLE = IntegerProperty.create("picked_cycle", 0, 15);
	private static final int RIPPLE_XZ = 3;
	private static final int RIPPLE_Y = 2;

	@SuppressWarnings("this-escape") // vanilla blocks register their default state the same way
	protected TideFloraBlock(Properties properties) {
		super(properties);
		this.registerDefaultState(this.stateDefinition.any().setValue(OPEN, false).setValue(PICKED_CYCLE, 0));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		builder.add(OPEN, PICKED_CYCLE);
	}

	/** The Tide in which this plant is open. */
	protected abstract Tide openTide();

	/** The loot table a pick drops. */
	protected abstract ResourceKey<LootTable> harvestTable();

	protected abstract SoundEvent openSound();

	protected abstract SoundEvent closeSound();

	/** The trail particle's colour as the plant switches. */
	protected abstract int switchColour(boolean opening);

	/** This cycle's stamp: (Tide clock ticks / one cycle, mod 15) + 1, never 0. */
	public static int stamp(Level level) {
		return Math.floorMod(Math.floorDiv(Tide.clockTicks(level), Tide.PERIOD_TICKS), 15) + 1;
	}

	/** Picked in the current cycle. A stamp from an older cycle counts as unpicked. */
	public static boolean isPicked(BlockState state, Level level) {
		int picked = state.getValue(PICKED_CYCLE);
		return picked != 0 && picked == stamp(level);
	}

	/** Open, unpicked this cycle, and in its own Tide: a pick or a break yields. */
	public boolean isReady(BlockState state, Level level) {
		return state.getValue(OPEN) && !isPicked(state, level) && Tide.current(level) == this.openTide();
	}

	/** Whether the plant should be open now, or null outside the Sift (where it never switches). */
	private @Nullable Boolean shouldBeOpen(Level level) {
		Tide tide = Tide.current(level);
		return tide == null ? null : tide == this.openTide();
	}

	@Override
	protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
		int picked = state.getValue(PICKED_CYCLE);
		if (picked != 0 && picked != stamp(level)) {
			state = state.setValue(PICKED_CYCLE, 0);
			level.setBlock(pos, state, Block.UPDATE_CLIENTS);
		}
		this.trySwitch(state, level, pos, random, 1.0F);
	}

	@Override
	protected void tick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
		this.trySwitch(state, level, pos, random, 0.4F);
	}

	/** Switches if the Tide calls for it, then ripples the switch to the same plants nearby. */
	private boolean trySwitch(BlockState state, ServerLevel level, BlockPos pos, RandomSource random, float volume) {
		Boolean open = this.shouldBeOpen(level);
		if (open == null || open == state.getValue(OPEN)) {
			return false;
		}
		this.switchTo(state, level, pos, random, open, volume);
		boolean wasOpen = state.getValue(OPEN);
		level.findBlocksIn(pos.offset(-RIPPLE_XZ, -RIPPLE_Y, -RIPPLE_XZ), pos.offset(RIPPLE_XZ, RIPPLE_Y, RIPPLE_XZ))
				.filterState(near -> near.is(this) && near.getValue(OPEN) == wasOpen)
				.forEach((nearPos, near) -> {
					double distance = Math.sqrt(pos.distSqr(nearPos));
					level.scheduleTick(nearPos, this, random.nextIntBetweenInclusive((int) (distance * 5.0), (int) (distance * 10.0)));
				});
		return true;
	}

	private void switchTo(BlockState state, ServerLevel level, BlockPos pos, RandomSource random, boolean open, float volume) {
		BlockState switched = state.setValue(OPEN, open);
		if (!open) {
			switched = switched.setValue(PICKED_CYCLE, 0);
		}
		level.setBlockAndUpdate(pos, switched);
		// As the eyeblossom: an ownerless block change, so listeners nearby turn toward it.
		level.gameEvent(GameEvent.BLOCK_CHANGE, pos, GameEvent.Context.of(switched));
		level.playSound(null, pos, open ? this.openSound() : this.closeSound(), SoundSource.BLOCKS, volume,
				0.9F + random.nextFloat() * 0.2F);
		Vec3 start = Vec3.atCenterOf(pos);
		double lifetime = 0.5 + random.nextDouble();
		Vec3 target = start.add(new Vec3(random.nextDouble() - 0.5, random.nextDouble() + 1.0, random.nextDouble() - 0.5).scale(lifetime));
		level.sendParticles(new TrailParticleOption(target, this.switchColour(open), (int) (20.0 * lifetime)),
				start.x, start.y, start.z, 1, 0.0, 0.0, 0.0, 0.0);
	}

	@Override
	protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hitResult) {
		Boolean open = this.shouldBeOpen(level);
		boolean stale = open == null ? state.getValue(OPEN) : open != state.getValue(OPEN);
		if (stale) {
			// A plant showing the wrong state (a chunk loaded mid-window, or one carried out of the
			// Sift) switches at once instead of yielding.
			if (level instanceof ServerLevel serverLevel) {
				this.switchTo(state, serverLevel, pos, serverLevel.getRandom(), open != null && open, 0.4F);
			}
			return InteractionResult.SUCCESS;
		}
		if (!this.isReady(state, level)) {
			return InteractionResult.PASS;
		}
		if (level instanceof ServerLevel serverLevel) {
			this.pick(serverLevel, pos, state, player, stack -> Block.popResource(serverLevel, pos, stack));
		}
		return InteractionResult.SUCCESS;
	}

	/**
	 * Picks a ready plant for {@code picker}, a player's use or a befriended blub foraging (D-029): the
	 * harvest goes to {@code out}, the cycle is stamped, and the pick is heard.
	 */
	public void pick(ServerLevel level, BlockPos pos, BlockState state, Entity picker, Consumer<ItemStack> out) {
		Block.dropFromBlockInteractLootTable(level, this.harvestTable(), pos, state, null, null, picker, (l, stack) -> out.accept(stack));
		level.playSound(null, pos, ModSounds.FLORA_PICK, SoundSource.BLOCKS, 1.0F, 0.8F + level.getRandom().nextFloat() * 0.4F);
		BlockState picked = state.setValue(PICKED_CYCLE, stamp(level));
		level.setBlock(pos, picked, Block.UPDATE_CLIENTS);
		// As the sweet berry bush: a block change with the picker as its source (heard in Endure).
		level.gameEvent(GameEvent.BLOCK_CHANGE, pos, GameEvent.Context.of(picker, picked));
	}
}
