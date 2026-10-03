package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.LilyPadBlock;
import net.minecraft.world.level.block.state.BlockState;

import thesift.registry.ModFluids;
import thesift.registry.ModParticles;

/**
 * The ichor lily (owner playtest 3, D-029): the Ichor Flats' own plant, a lily pad that floats only on
 * still ichor, with a pale bud that glows (light 9) and lets glimmers drift up over the flats, as a
 * firefly bush lets fireflies go. Boats break it, as they break lily pads.
 */
public class IchorLilyBlock extends LilyPadBlock {
	public IchorLilyBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return level.getFluidState(pos).isSourceOfType(ModFluids.ICHOR) && level.getFluidState(pos.above()).isEmpty();
	}

	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		if (random.nextInt(6) == 0) {
			level.addParticle(ModParticles.GLIMMER, pos.getX() + 0.5 + (random.nextDouble() - 0.5) * 3.0,
					pos.getY() + 0.3 + random.nextDouble() * 1.5, pos.getZ() + 0.5 + (random.nextDouble() - 0.5) * 3.0, 0.0, 0.0, 0.0);
		}
	}
}
