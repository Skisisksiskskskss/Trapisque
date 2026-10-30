package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.FlowerBedBlock;
import net.minecraft.world.level.block.state.BlockState;

/** Gold petals (owner playtest 6): vanilla's flower bed, as pink petals are, three pixels tall, on the Sift's ground. */
public class GoldPetalsBlock extends FlowerBedBlock {
	public GoldPetalsBlock(Properties properties) {
		super(properties, 3);
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.isSiftGround(state);
	}
}
