package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;

import thesift.entity.singer.Singer;
import thesift.registry.ModBlocks;
import thesift.registry.ModSounds;

/**
 * A chorus stone (items.md §1.1): three ring each Singer's grove, empty and dark. Each takes one soul
 * block (canon: the "stolen soul blocks" of "Lost Harmonies"): it lights and chimes, and the Singer's
 * phrase grows by a bar. Unbreakable in survival, as the gatestone, so a grove can't be broken.
 */
public class ChorusStoneBlock extends Block {
	public static final BooleanProperty FILLED = BooleanProperty.create("filled");

	public ChorusStoneBlock(Properties properties) {
		super(properties);
		this.registerDefaultState(this.stateDefinition.any().setValue(FILLED, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		builder.add(FILLED);
	}

	@Override
	protected InteractionResult useItemOn(ItemStack stack, BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand,
			BlockHitResult hit) {
		if (state.getValue(FILLED) || !stack.is(ModBlocks.SOUL_BLOCK.asItem())) {
			return InteractionResult.TRY_WITH_EMPTY_HAND;
		}
		if (level instanceof ServerLevel server) {
			stack.consume(1, player);
			server.setBlock(pos, state.setValue(FILLED, true), Block.UPDATE_ALL);
			server.playSound(null, pos, ModSounds.CHORUS_STONE_FILL, SoundSource.BLOCKS, 1.5F, 1.0F);
			server.sendParticles(ParticleTypes.SOUL, pos.getX() + 0.5, pos.getY() + 1.2, pos.getZ() + 0.5, 12, 0.3, 0.4, 0.3, 0.02);
			int filled = GroveHeartBlock.filledStones(server, pos, 8);
			for (Singer singer : server.getEntitiesOfClass(Singer.class, new AABB(pos).inflate(16))) {
				singer.sing(ModSounds.SINGER_HUM, 20 + 15 * filled, 0.8F + 0.12F * filled); // one more bar
			}
		}
		return InteractionResult.SUCCESS;
	}
}
