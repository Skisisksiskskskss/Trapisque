package thesift.block;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;

import thesift.block.entity.GroveHeartBlockEntity;
import thesift.registry.ModBlocks;
import thesift.registry.ModSounds;

/**
 * A grove heart (world.md §3): the centre of a Singer's grove. It listens for music played by hand,
 * keeps the grove's restored state and the players it rewarded, and, as a bloom heart, condenses a
 * player's experience into a soul block (5 levels). Unbreakable in survival and never dropped.
 */
public class GroveHeartBlock extends BaseEntityBlock {
	/** Levels condensed into one soul block (BALANCE.md). */
	public static final int SOUL_COST = 5;

	public GroveHeartBlock(Properties properties) {
		super(properties);
	}

	@Override
	public @Nullable BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
		return new GroveHeartBlockEntity(pos, state);
	}

	@Override
	protected RenderShape getRenderShape(BlockState state) {
		return RenderShape.MODEL;
	}

	@Override
	protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hit) {
		if (!player.hasInfiniteMaterials() && player.experienceLevel < SOUL_COST) {
			return InteractionResult.PASS;
		}
		if (level instanceof ServerLevel server) {
			if (!player.hasInfiniteMaterials()) {
				player.giveExperienceLevels(-SOUL_COST);
			}
			ItemStack soul = new ItemStack(ModBlocks.SOUL_BLOCK);
			if (!player.getInventory().add(soul)) {
				player.spawnAtLocation(server, soul);
			}
			server.playSound(null, pos, ModSounds.GROVE_HEART_CONDENSE, SoundSource.BLOCKS, 1.2F, 1.0F);
			server.sendParticles(ParticleTypes.SOUL, pos.getX() + 0.5, pos.getY() + 1.1, pos.getZ() + 0.5, 16, 0.3, 0.3, 0.3, 0.03);
		}
		return InteractionResult.SUCCESS;
	}

	/** How many chorus stones within {@code radius} of {@code pos} are filled. */
	public static int filledStones(Level level, BlockPos pos, int radius) {
		int filled = 0;
		for (BlockPos p : BlockPos.betweenClosed(pos.offset(-radius, -3, -radius), pos.offset(radius, 3, radius))) {
			BlockState state = level.getBlockState(p);
			if (state.is(ModBlocks.CHORUS_STONE) && state.getValue(ChorusStoneBlock.FILLED)) {
				filled++;
			}
		}
		return filled;
	}
}
