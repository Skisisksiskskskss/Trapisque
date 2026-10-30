package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.VegetationBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.registry.ModBlocks;

/** The Carapace's red and yellow grass (canon: "red and yellow grass patches"): on Sift dust or Sift ground. */
public class CarapaceGrassBlock extends VegetationBlock {
	private static final VoxelShape SHAPE = Block.column(12.0, 0.0, 13.0);

	public CarapaceGrassBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPE;
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return state.is(ModBlocks.SIFT_DUST) || state.is(ModBlocks.HEALTHY_SCULK) || state.is(ModBlocks.SIFT_SOIL) || state.is(ModBlocks.CARAPACE_STONE);
	}
}
