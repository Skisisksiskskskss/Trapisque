package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.RotatedPillarBlock;
import net.minecraft.world.level.block.state.BlockState;

import thesift.world.Tide;

/**
 * Songwood's flute holes puff notes when music plays nearby, and now and then on their own in
 * Thrive: a visual for the wood's hum (world.md §3, §3.2). Client-side only.
 */
public class SongwoodLogBlock extends RotatedPillarBlock {
	public SongwoodLogBlock(Properties properties) {
		super(properties);
	}

	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		boolean music = random.nextInt(3) == 0 && MusicNearby.near(pos);
		boolean hum = !music && random.nextInt(600) == 0 && Tide.current(level) == Tide.THRIVE;
		if (!music && !hum) {
			return;
		}
		Direction face = Direction.Plane.HORIZONTAL.getRandomDirection(random);
		if (!level.getBlockState(pos.relative(face)).isAir()) {
			return;
		}
		double x = pos.getX() + 0.5 + face.getStepX() * 0.55;
		double z = pos.getZ() + 0.5 + face.getStepZ() * 0.55;
		// NOTE reads its colour from the first velocity argument (0..1 over 24 pitches).
		level.addParticle(ParticleTypes.NOTE, x, pos.getY() + 0.3 + random.nextDouble() * 0.4, z, random.nextInt(25) / 24.0, 0.0, 0.0);
	}
}
