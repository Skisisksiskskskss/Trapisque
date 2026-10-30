package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.FlowerBlock;
import net.minecraft.world.level.block.state.BlockState;

/** A flower of the Sift (owner playtest 6: the goldfrond, the bluebulb): vanilla's flower, on the Sift's ground. */
public class SiftFlowerBlock extends FlowerBlock {
	public SiftFlowerBlock(Holder<MobEffect> effect, float seconds, Properties properties) {
		super(effect, seconds, properties);
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.isSiftGround(state);
	}
}
