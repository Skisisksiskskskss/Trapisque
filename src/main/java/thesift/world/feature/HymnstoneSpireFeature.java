package thesift.world.feature;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.registry.ModBlocks;

/**
 * The teasers' signature (owner playtest rework): a tall rose spire of hymnstone, swaying a little as
 * it rises, with ledges where its layers jut out and, on most, a wide mushroom-like cap grown over
 * with healthy sculk. 14 to 33 blocks tall; it stays within a block of its chunk's neighbours.
 */
public record HymnstoneSpireFeature() implements Feature {
	public static final HymnstoneSpireFeature INSTANCE = new HymnstoneSpireFeature();
	public static final MapCodec<HymnstoneSpireFeature> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<HymnstoneSpireFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		BlockPos ground = origin.below();
		if (!level.getFluidState(origin).isEmpty() || !level.getBlockState(ground).is(ModBlocks.HEALTHY_SCULK)) {
			return false;
		}
		BlockState stone = ModBlocks.HYMNSTONE.defaultBlockState();
		BlockState grass = ModBlocks.HEALTHY_SCULK.defaultBlockState();
		int height = 14 + random.nextInt(20);
		float baseRadius = 2.0F + random.nextFloat() * 1.8F;
		float topRadius = baseRadius * (0.55F + random.nextFloat() * 0.3F);
		float phase = random.nextFloat() * Mth.TWO_PI;
		float swayX = (random.nextFloat() - 0.5F) * 0.12F;
		float swayZ = (random.nextFloat() - 0.5F) * 0.12F;
		boolean cap = random.nextFloat() < 0.75F;
		int capRadius = Mth.ceil(topRadius) + 2 + random.nextInt(2);
		BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
		// Roots: down to solid ground, so it never stands on air over a slope.
		for (int y = -1; y >= -8; y--) {
			disc(level, p, origin.getX(), origin.getY() + y, origin.getZ(), baseRadius + 0.5F, stone, true);
		}
		double cx = origin.getX();
		double cz = origin.getZ();
		for (int y = 0; y < height; y++) {
			float t = (float) y / height;
			// Ledges where a harder layer juts out, a little every few blocks.
			float ledge = Mth.sin(y * 0.9F + phase) > 0.85F ? 0.8F : 0.0F;
			float r = Mth.lerp(t, baseRadius, topRadius) + ledge;
			cx += swayX;
			cz += swayZ;
			disc(level, p, (int) Math.round(cx), origin.getY() + y, (int) Math.round(cz), r, stone, false);
		}
		int top = origin.getY() + height;
		int tx = (int) Math.round(cx);
		int tz = (int) Math.round(cz);
		if (cap) {
			// A mushroom cap: wide on top, drawn in underneath.
			disc(level, p, tx, top - 1, tz, capRadius - 1.5F, stone, false);
			disc(level, p, tx, top, tz, capRadius - 0.5F, stone, false);
			disc(level, p, tx, top + 1, tz, capRadius, stone, false);
			disc(level, p, tx, top + 2, tz, capRadius - 0.8F, grass, false);
		} else {
			disc(level, p, tx, top, tz, topRadius, grass, false);
		}
		return true;
	}

	/** A filled disc; replaces only air and plants (or, for roots, anything that isn't solid). */
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
