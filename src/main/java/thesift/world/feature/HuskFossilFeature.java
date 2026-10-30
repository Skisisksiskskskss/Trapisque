package thesift.world.feature;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.RotatedPillarBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.registry.ModBlocks;

/**
 * A husk fossil in the Carapace (canon: "colossal fossils … the largest of these are the humbler husks,
 * which can be entered"; D-035): the rib cage of something huge, half sunk in the dust. A spine 14-22
 * long and 5-7 up, ribs arching down to the ground every third block with room to walk between them,
 * and a hollow skull with two eye holes at one end.
 */
public record HuskFossilFeature() implements Feature {
	public static final HuskFossilFeature INSTANCE = new HuskFossilFeature();
	public static final MapCodec<HuskFossilFeature> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<HuskFossilFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		Direction.Axis axis = random.nextBoolean() ? Direction.Axis.X : Direction.Axis.Z;
		Direction along = Direction.fromAxisAndDirection(axis, Direction.AxisDirection.POSITIVE);
		Direction across = along.getClockWise();
		int length = 14 + random.nextInt(9);
		int height = 5 + random.nextInt(3);
		int ground = origin.getY() - 2; // half sunk
		BlockState spine = ModBlocks.HUSK_BONE_BLOCK.defaultBlockState().setValue(RotatedPillarBlock.AXIS, axis);
		BlockState rib = ModBlocks.HUSK_BONE_BLOCK.defaultBlockState().setValue(RotatedPillarBlock.AXIS, Direction.Axis.Y);
		BlockState ribAcross = ModBlocks.HUSK_BONE_BLOCK.defaultBlockState().setValue(RotatedPillarBlock.AXIS, across.getAxis());
		BlockPos start = origin.relative(along, -length / 2);
		for (int i = 0; i < length; i++) {
			BlockPos at = start.relative(along, i);
			int sag = i < 2 || i >= length - 2 ? 1 : 0;
			set(level, at.atY(ground + height - sag), spine);
			if (i % 3 == 1 && i > 2 && i < length - 3) {
				for (int side : new int[] {-1, 1}) {
					for (int a = 1; a <= 16; a++) {
						double t = a / 16.0 * Math.PI / 2.0; // from the spine (t = 0) down to the ground
						int out = (int) Math.round(Math.sin(t) * height) * side;
						int y = ground + (int) Math.round(Math.cos(t) * height);
						set(level, at.relative(across, out).atY(y), a < 6 ? ribAcross : rib);
					}
				}
			}
		}
		// The skull: a hollow box past the spine's front end, two eye holes looking out.
		BlockPos front = start.relative(along, -1);
		int top = ground + height + 1;
		for (int l = 0; l < 4; l++) {
			for (int w = -2; w <= 2; w++) {
				for (int y = top - 3; y <= top; y++) {
					boolean shell = l == 0 || l == 3 || Math.abs(w) == 2 || y == top - 3 || y == top;
					BlockPos p = front.relative(along, -l).relative(across, w).atY(y);
					boolean eye = l == 3 && Math.abs(w) == 1 && y == top - 1;
					if (shell && !eye) {
						set(level, p, spine);
					} else if (level.getBlockState(p).canBeReplaced() || eye) {
						level.setBlock(p, Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS);
					}
				}
			}
		}
		return true;
	}

	private static void set(WorldGenLevel level, BlockPos pos, BlockState state) {
		if (!level.getBlockState(pos).is(Blocks.BEDROCK) && level.isInsideBuildHeight(pos.getY())) {
			level.setBlock(pos, state, Block.UPDATE_CLIENTS);
		}
	}
}
