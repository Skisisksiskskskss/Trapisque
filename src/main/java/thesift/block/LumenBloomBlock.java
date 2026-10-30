package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.VegetationBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.registry.ModBlocks;

/**
 * The lumen bloom (block_flora_ii.md §5): the natural lumen. Hunters keep out of its radius
 * (system_hunt.md §6, the {@code thesift:lumen} POI), it gives light 12, and it drops nothing even
 * with Silk Touch: a natural lumen is a place, and lanterns are how players make their own. Now and
 * then a pale mote drifts up from its core.
 */
public class LumenBloomBlock extends VegetationBlock {
	private static final VoxelShape SHAPE = Block.column(14.0, 0.0, 6.0);

	public LumenBloomBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPE;
	}

	/** The Meadow's ground, or the Hollows' hymnstone. */
	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.isSiftGround(state) || state.is(ModBlocks.HYMNSTONE);
	}

	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		if (random.nextInt(8) == 0) {
			level.addParticle(ParticleTypes.END_ROD, pos.getX() + 0.5 + (random.nextDouble() - 0.5) * 0.2, pos.getY() + 0.35,
					pos.getZ() + 0.5 + (random.nextDouble() - 0.5) * 0.2, 0.0, 0.02, 0.0);
		}
	}
}
