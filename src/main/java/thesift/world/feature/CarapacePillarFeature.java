package thesift.world.feature;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.registry.ModBlocks;

/**
 * A pillar of the Carapace (owner playtest 6; canon's screenshot shows blue-teal stone pillars over pale
 * dust): carapace stone, 5 to 10 tall (now and then a tall one to 20), narrowing as it rises, with a
 * ledge here and there and a cap of Sift dust and red and yellow grass. Half of them have bounce jelly
 * at their foot, which throws a player high enough to land on top.
 */
public record CarapacePillarFeature() implements Feature {
	public static final CarapacePillarFeature INSTANCE = new CarapacePillarFeature();
	public static final MapCodec<CarapacePillarFeature> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<CarapacePillarFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		BlockState ground = level.getBlockState(origin.below());
		if (!level.getFluidState(origin).isEmpty() || !(ground.is(ModBlocks.SIFT_DUST) || ground.is(ModBlocks.CARAPACE_STONE))) {
			return false;
		}
		BlockState stone = ModBlocks.CARAPACE_STONE.defaultBlockState();
		int height = random.nextInt(8) == 0 ? 14 + random.nextInt(7) : 5 + random.nextInt(6);
		float radius = 1.1F + random.nextFloat() * 1.2F;
		float phase = random.nextFloat() * Mth.TWO_PI;
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		for (int y = -1; y >= -6; y--) { // roots, so it never stands on air
			disc(level, p, origin.getX(), origin.getY() + y, origin.getZ(), radius + 0.5F, stone, true);
		}
		float top = radius;
		for (int y = 0; y < height; y++) {
			float t = (float) y / height;
			top = radius * (1.0F - 0.3F * t) + (Mth.sin(y * 1.3F + phase) > 0.75F ? 0.7F : 0.0F);
			disc(level, p, origin.getX(), origin.getY() + y, origin.getZ(), top, stone, false);
		}
		// The cap: its top layer turned to dust, with grass growing in it.
		int capY = origin.getY() + height - 1;
		int r = Mth.ceil(top);
		for (int dx = -r; dx <= r; dx++) {
			for (int dz = -r; dz <= r; dz++) {
				p.set(origin.getX() + dx, capY, origin.getZ() + dz);
				if (level.getBlockState(p).is(ModBlocks.CARAPACE_STONE) && level.getBlockState(p.above()).isAir()) {
					level.setBlock(p, ModBlocks.SIFT_DUST.defaultBlockState(), Block.UPDATE_CLIENTS);
					if (random.nextInt(3) == 0) {
						Block grass = random.nextInt(5) < 3 ? ModBlocks.RED_CARAPACE_GRASS : ModBlocks.YELLOW_CARAPACE_GRASS;
						level.setBlock(p.move(Direction.UP), grass.defaultBlockState(), Block.UPDATE_CLIENTS);
					}
				}
			}
		}
		if (height <= 10 && random.nextBoolean()) {
			// Bounce jelly at its foot, flush with the ground.
			Direction side = Direction.Plane.HORIZONTAL.getRandomDirection(random);
			BlockPos jelly = origin.below().relative(side, Mth.ceil(radius) + 1);
			if (level.getBlockState(jelly).is(ModBlocks.SIFT_DUST) && level.getBlockState(jelly.above()).isAir()) {
				level.setBlock(jelly, ModBlocks.BOUNCE_JELLY.defaultBlockState(), Block.UPDATE_CLIENTS);
			}
		}
		return true;
	}

	/** A filled disc; replaces only air and plants (or, for roots, anything that isn't a full block). */
	private static void disc(WorldGenLevel level, BlockPos.MutableBlockPos p, int cx, int y, int cz, float radius, BlockState state, boolean roots) {
		int r = Mth.ceil(radius);
		for (int dx = -r; dx <= r; dx++) {
			for (int dz = -r; dz <= r; dz++) {
				if (dx * dx + dz * dz > radius * radius) {
					continue;
				}
				p.set(cx + dx, y, cz + dz);
				BlockState here = level.getBlockState(p);
				if (roots ? !here.isCollisionShapeFullBlock(level, p) : (here.isAir() || here.canBeReplaced())) {
					level.setBlock(p, state, Block.UPDATE_CLIENTS);
				}
			}
		}
	}
}
