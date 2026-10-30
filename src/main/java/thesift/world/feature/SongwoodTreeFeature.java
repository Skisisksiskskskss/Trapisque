package thesift.world.feature;

import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.HangingMossBlock;
import net.minecraft.world.level.block.LeavesBlock;
import net.minecraft.world.level.block.RotatedPillarBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.feature.Feature;

import thesift.registry.ModBlocks;

/**
 * Songwood after the teasers' white trees (owner playtest 6): a dark trunk crowned by a tall box of
 * pale leaves, with branches holding up more boxes around it, two to four canopies in all. Each box
 * has a level, square top and is taller than it is wide; along its bottom edges leaves droop a block
 * or two, and drapes hang below. About one tree in twelve is grand: a 2 x 2 trunk, taller, with five
 * canopies a little bigger. Leaves keep their distance to the logs (a log runs up inside each box), so
 * they stay until the tree is felled.
 */
public record SongwoodTreeFeature() implements Feature {
	public static final SongwoodTreeFeature INSTANCE = new SongwoodTreeFeature();
	public static final MapCodec<SongwoodTreeFeature> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<SongwoodTreeFeature> codec() {
		return CODEC;
	}

	@Override
	public boolean place(WorldGenLevel level, ChunkGenerator chunkGenerator, RandomSource random, BlockPos origin) {
		boolean grand = random.nextInt(12) == 0;
		for (BlockPos foot : new BlockPos[] {origin.offset(1, -1, 0), origin.offset(0, -1, 1), origin.offset(1, -1, 1)}) {
			grand &= level.getBlockState(foot).isFaceSturdy(level, foot, Direction.UP); // a 2 x 2 trunk stands on ground
		}
		int width = grand ? 2 : 1;
		int height = grand ? 11 + random.nextInt(4) : 7 + random.nextInt(3);
		int canopies = grand ? 5 : 2 + random.nextInt(3);
		Map<BlockPos, BlockState> logs = new HashMap<>();
		Set<BlockPos> leaves = new HashSet<>();
		BlockState log = ModBlocks.SONGWOOD_LOG.defaultBlockState();
		for (int y = 0; y < height; y++) {
			for (int dx = 0; dx < width; dx++) {
				for (int dz = 0; dz < width; dz++) {
					logs.put(origin.offset(dx, y, dz), log);
				}
			}
		}
		for (BlockPos p : logs.keySet()) {
			if (!replaceable(level, p) && !p.equals(origin)) {
				return false; // no room for the trunk
			}
		}
		// The trunk's crown, then the branches' canopies around it, spread evenly with a little wobble.
		double centre = (width - 1) / 2.0;
		canopy(origin.getX() + centre, origin.getY() + height - 2, origin.getZ() + centre, grand, random, logs, leaves);
		double start = random.nextDouble() * Mth.TWO_PI;
		for (int i = 1; i < canopies; i++) {
			double angle = start + i * Mth.TWO_PI / (canopies - 1) + (random.nextDouble() - 0.5) * 0.6;
			int from = height - 3 - random.nextInt(grand ? 5 : 3);
			int length = (grand ? 4 : 3) + random.nextInt(2);
			int rise = 1 + random.nextInt(3);
			double x = origin.getX() + centre;
			double z = origin.getZ() + centre;
			BlockPos end = origin;
			for (int step = 1; step <= length; step++) {
				int bx = Mth.floor(x + Math.cos(angle) * (step - 0.5 + width / 2.0) + 0.5);
				int bz = Mth.floor(z + Math.sin(angle) * (step - 0.5 + width / 2.0) + 0.5);
				int by = origin.getY() + from + (rise * step + length / 2) / length;
				Direction.Axis axis = Math.abs(Math.cos(angle)) > Math.abs(Math.sin(angle)) ? Direction.Axis.X : Direction.Axis.Z;
				BlockPos p = new BlockPos(bx, by, bz);
				logs.putIfAbsent(p, log.setValue(RotatedPillarBlock.AXIS, axis));
				if (!end.equals(origin) && end.getY() < by) {
					logs.putIfAbsent(end.above(), log); // a step up keeps the branch whole
				}
				end = p;
			}
			canopy(end.getX(), end.getY() + 1, end.getZ(), grand, random, logs, leaves);
		}
		for (Map.Entry<BlockPos, BlockState> e : logs.entrySet()) {
			if (replaceable(level, e.getKey()) || e.getKey().equals(origin)) {
				level.setBlock(e.getKey(), e.getValue(), Block.UPDATE_CLIENTS);
			}
		}
		placeLeaves(level, logs.keySet(), leaves);
		for (BlockPos leaf : leaves) {
			BlockPos below = leaf.below();
			if (random.nextFloat() >= 0.22F || leaves.contains(below) || !level.getBlockState(below).isAir()
					|| !level.getBlockState(leaf).is(ModBlocks.SONGWOOD_LEAVES)) {
				continue;
			}
			int length = 1 + random.nextInt(4);
			int placed = 0;
			while (placed < length && level.getBlockState(below.below(placed)).isAir()) {
				placed++;
			}
			for (int i = 0; i < placed; i++) {
				level.setBlock(below.below(i), ModBlocks.SONGWOOD_DRAPES.defaultBlockState().setValue(HangingMossBlock.TIP, i == placed - 1),
						Block.UPDATE_CLIENTS);
			}
		}
		return true;
	}

	/**
	 * A box of leaves around (x, z), its bottom a block below {@code bottom}: 4 or 5 wide (5 or 6 on a
	 * grand tree) and two or three taller than wide, with a log up its middle to hold the leaves.
	 * Along the bottom edges, leaves droop one block (and now and then two).
	 */
	private static void canopy(double x, int bottom, double z, boolean grand, RandomSource random, Map<BlockPos, BlockState> logs,
			Set<BlockPos> leaves) {
		int side = (grand ? 5 : 4) + random.nextInt(2);
		int tall = side + 2 + random.nextInt(2);
		int x0 = Mth.floor(x - (side - 1) / 2.0 + 0.5);
		int z0 = Mth.floor(z - (side - 1) / 2.0 + 0.5);
		int y0 = bottom - 1;
		for (int dy = 0; dy < tall; dy++) {
			for (int dx = 0; dx < side; dx++) {
				for (int dz = 0; dz < side; dz++) {
					leaves.add(new BlockPos(x0 + dx, y0 + dy, z0 + dz));
				}
			}
		}
		for (int dx = 0; dx < side; dx++) {
			for (int dz = 0; dz < side; dz++) {
				boolean edge = dx == 0 || dz == 0 || dx == side - 1 || dz == side - 1;
				float r = random.nextFloat();
				int droop = !edge ? 0 : r < 0.12F ? 2 : r < 0.5F ? 1 : 0;
				for (int d = 1; d <= droop; d++) {
					leaves.add(new BlockPos(x0 + dx, y0 - d, z0 + dz));
				}
			}
		}
		BlockState log = ModBlocks.SONGWOOD_LOG.defaultBlockState();
		int cx = x0 + side / 2;
		int cz = z0 + side / 2;
		for (int dy = 0; dy < tall - 1; dy++) { // up to the layer under the top, so the top stays all leaves
			logs.putIfAbsent(new BlockPos(cx, y0 + dy, cz), log);
		}
	}

	/** Leaves wherever there's room, each with its true distance to a log through the leaves (they decay past 6). */
	private static void placeLeaves(WorldGenLevel level, Set<BlockPos> logs, Set<BlockPos> leaves) {
		Map<BlockPos, Integer> distance = new HashMap<>();
		ArrayDeque<BlockPos> queue = new ArrayDeque<>();
		for (BlockPos p : logs) {
			distance.put(p, 0);
			queue.add(p);
		}
		while (!queue.isEmpty()) {
			BlockPos p = queue.poll();
			int d = distance.get(p);
			if (d >= LeavesBlock.DECAY_DISTANCE - 1) {
				continue;
			}
			for (Direction direction : Direction.values()) {
				BlockPos n = p.relative(direction);
				if (leaves.contains(n) && !logs.contains(n) && !distance.containsKey(n)) {
					distance.put(n, d + 1);
					queue.add(n);
				}
			}
		}
		BlockState leaf = ModBlocks.SONGWOOD_LEAVES.defaultBlockState();
		for (BlockPos p : leaves) {
			Integer d = distance.get(p);
			if (d != null && d > 0 && replaceable(level, p)) {
				level.setBlock(p, leaf.setValue(LeavesBlock.DISTANCE, d), Block.UPDATE_CLIENTS);
			}
		}
	}

	private static boolean replaceable(WorldGenLevel level, BlockPos p) {
		BlockState state = level.getBlockState(p);
		return state.isAir() || state.canBeReplaced() || state.is(ModBlocks.SONGWOOD_LEAVES) || state.is(ModBlocks.SONGWOOD_DRAPES);
	}
}
