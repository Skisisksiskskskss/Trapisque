package thesift.item;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.stats.Stats;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.BucketItem;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.ItemUtils;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;

import thesift.block.TidewrackBlock;
import thesift.registry.ModAttributes;
import thesift.registry.ModFluids;
import thesift.registry.ModSounds;

/**
 * Ichor evaporates outside the Sift (rules.md): emptying the bucket where {@code sift_life} is
 * false leaves only soul smoke, like water emptied in the Nether.
 */
public class IchorBucketItem extends BucketItem {
	public IchorBucketItem(Fluid content, Properties properties) {
		super(content, properties);
	}

	public static boolean evaporatesAt(Level level, BlockPos pos) {
		return !level.environmentAttributes().getValue(ModAttributes.SIFT_LIFE, pos);
	}

	/**
	 * Vanilla's bucket aims at the clicked block only when it holds water; ours aims at a dry
	 * tidewrack too, which holds ichor as a waterloggable block holds water (block_flora_ii.md §1).
	 */
	@Override
	public InteractionResult use(Level level, Player player, InteractionHand hand) {
		BlockHitResult hit = getPlayerPOVHitResult(level, player, ClipContext.Fluid.NONE);
		if (hit.getType() == HitResult.Type.BLOCK && level.mayInteract(player, hit.getBlockPos())
				&& player.mayUseItemAt(hit.getBlockPos(), hit.getDirection(), player.getItemInHand(hand))
				&& fillsTidewrack(level, hit.getBlockPos(), player)) {
			if (this.emptyContents(player, level, hit.getBlockPos(), hit)) {
				player.awardStat(Stats.ITEM_USED.get(this));
				ItemStack empty = ItemUtils.createFilledResult(player.getItemInHand(hand), player, getEmptySuccessItem(player.getItemInHand(hand), player));
				return InteractionResult.SUCCESS.heldItemTransformedTo(empty);
			}
		}
		return super.use(level, player, hand);
	}

	private static boolean fillsTidewrack(Level level, BlockPos pos, @Nullable LivingEntity user) {
		BlockState state = level.getBlockState(pos);
		return state.getBlock() instanceof TidewrackBlock tidewrack && tidewrack.canPlaceLiquid(user, level, pos, state, ModFluids.ICHOR);
	}

	@Override
	public boolean emptyContents(@Nullable LivingEntity user, Level level, BlockPos pos, @Nullable BlockHitResult hitResult) {
		if (fillsTidewrack(level, pos, user) && !evaporatesAt(level, pos)) {
			// Clicked, or a dispenser facing it: the tidewrack takes the ichor (vanilla would replace it).
			BlockState state = level.getBlockState(pos);
			((TidewrackBlock) state.getBlock()).placeLiquid(level, pos, state, ModFluids.ICHOR.getSource(false));
			this.playEmptySound(user, level, pos);
			return true;
		}
		if (!evaporatesAt(level, pos)) {
			return super.emptyContents(user, level, pos, hitResult);
		}
		if (!level.getBlockState(pos).isAir() && !level.getBlockState(pos).canBeReplaced()) {
			return hitResult != null && this.emptyContents(user, level, hitResult.getBlockPos().relative(hitResult.getDirection()), null);
		}
		level.playSound(user, pos, ModSounds.ICHOR_EVAPORATE, SoundSource.BLOCKS, 1.0F, 0.9F + level.getRandom().nextFloat() * 0.2F);
		if (level instanceof ServerLevel serverLevel) {
			serverLevel.sendParticles(ParticleTypes.SOUL, pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 8, 0.4, 0.4, 0.4, 0.02);
			serverLevel.sendParticles(ParticleTypes.LARGE_SMOKE, pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 6, 0.4, 0.4, 0.4, 0.0);
		}
		return true;
	}

	@Override
	protected void playEmptySound(@Nullable LivingEntity user, LevelAccessor level, BlockPos pos) {
		level.playSound(user, pos, ModSounds.BUCKET_EMPTY_ICHOR, SoundSource.BLOCKS, 1.0F, 1.0F);
	}
}
