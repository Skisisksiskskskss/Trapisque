package thesift.world.feature;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.entity.singer.Singer;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;

/**
 * A Singer's grove (items.md §1.1, world.md §3): a round clearing of healthy sculk with the grove heart at
 * its centre, three empty chorus stones around it 4 blocks out, a ring of chime bells beyond, and the
 * Singer standing by its heart. Only on fairly level ground.
 */
public record SingerGroveFeature() implements Feature {
	public static final SingerGroveFeature INSTANCE = new SingerGroveFeature();
	public static final MapCodec<SingerGroveFeature> CODEC = MapCodec.unit(INSTANCE);
	private static final int RADIUS = 7;

	@Override
	public MapCodec<SingerGroveFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		int ground = level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, origin.getX(), origin.getZ()) - 1;
		for (int dx = -RADIUS; dx <= RADIUS; dx += RADIUS) {
			for (int dz = -RADIUS; dz <= RADIUS; dz += RADIUS) {
				int y = level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, origin.getX() + dx, origin.getZ() + dz) - 1;
				if (Math.abs(y - ground) > 3 || !level.getFluidState(new BlockPos(origin.getX() + dx, y, origin.getZ() + dz)).isEmpty()) {
					return false; // too steep or wet for a grove
				}
			}
		}
		BlockPos heart = new BlockPos(origin.getX(), ground, origin.getZ());
		// The clearing: a level floor of healthy sculk on soil, cleared above.
		for (int dx = -RADIUS; dx <= RADIUS; dx++) {
			for (int dz = -RADIUS; dz <= RADIUS; dz++) {
				if (dx * dx + dz * dz > RADIUS * RADIUS + 2) {
					continue;
				}
				BlockPos floor = heart.offset(dx, 0, dz);
				level.setBlock(floor, ModBlocks.HEALTHY_SCULK.defaultBlockState(), Block.UPDATE_CLIENTS);
				for (int down = 1; down <= 3; down++) {
					if (level.getBlockState(floor.below(down)).isAir()) {
						level.setBlock(floor.below(down), ModBlocks.SIFT_SOIL.defaultBlockState(), Block.UPDATE_CLIENTS);
					}
				}
				for (int up = 1; up <= 6; up++) {
					level.setBlock(floor.above(up), Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS);
				}
			}
		}
		level.setBlock(heart, ModBlocks.GROVE_HEART.defaultBlockState(), Block.UPDATE_CLIENTS);
		double turn = random.nextDouble() * Math.PI * 2.0;
		for (int i = 0; i < 3; i++) {
			double a = turn + i * Math.PI * 2.0 / 3.0;
			BlockPos stone = heart.offset((int) Math.round(Math.cos(a) * 4), 1, (int) Math.round(Math.sin(a) * 4));
			level.setBlock(stone, ModBlocks.CHORUS_STONE.defaultBlockState(), Block.UPDATE_CLIENTS);
		}
		for (int i = 0; i < 24; i++) {
			double a = i * Math.PI * 2.0 / 24.0;
			BlockPos bell = heart.offset((int) Math.round(Math.cos(a) * 6.5), 1, (int) Math.round(Math.sin(a) * 6.5));
			if (random.nextInt(3) != 0 && level.getBlockState(bell).isAir()) {
				level.setBlock(bell, ModBlocks.CHIME_BELL_FLOWER.defaultBlockState(), Block.UPDATE_CLIENTS);
			}
		}
		Singer singer = ModEntities.SINGER.create(level.getLevel(), EntitySpawnReason.STRUCTURE);
		if (singer != null) {
			singer.snapTo(heart.getX() + 1.5, heart.getY() + 1.0, heart.getZ() + 0.5, random.nextFloat() * 360.0F, 0.0F);
			singer.setHome(heart);
			level.addFreshEntityWithPassengers(singer);
		}
		return true;
	}
}
