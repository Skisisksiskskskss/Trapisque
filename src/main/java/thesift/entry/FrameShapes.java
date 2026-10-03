package thesift.entry;

import java.util.Optional;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.Block;

/**
 * Finds the frame a touched block belongs to (D-020). The check runs only on a deliberate use of
 * the block, never per tick: it tries every rectangle of the given size, in both vertical planes,
 * whose border passes through the touched block, and accepts one whose whole border is
 * {@code frameBlock} with none of it inside.
 */
public final class FrameShapes {
	private FrameShapes() {
	}

	public static Optional<SiftFrame> find(BlockGetter level, BlockPos touched, Block frameBlock, int width, int height) {
		if (!level.getBlockState(touched).is(frameBlock)) {
			return Optional.empty();
		}
		for (Direction.Axis axis : new Direction.Axis[] {Direction.Axis.X, Direction.Axis.Z}) {
			int pu = axis == Direction.Axis.X ? touched.getX() : touched.getZ();
			for (int u0 = pu - (width - 1); u0 <= pu; u0++) {
				for (int y0 = touched.getY() - (height - 1); y0 <= touched.getY(); y0++) {
					boolean onBorder = pu == u0 || pu == u0 + width - 1 || touched.getY() == y0 || touched.getY() == y0 + height - 1;
					if (!onBorder) {
						continue;
					}
					BlockPos origin = axis == Direction.Axis.X ? new BlockPos(u0, y0, touched.getZ()) : new BlockPos(touched.getX(), y0, u0);
					SiftFrame frame = new SiftFrame(origin, axis, width, height);
					if (matches(level, frame, frameBlock)) {
						return Optional.of(frame);
					}
				}
			}
		}
		return Optional.empty();
	}

	private static boolean matches(BlockGetter level, SiftFrame frame, Block frameBlock) {
		for (BlockPos pos : frame.border()) {
			if (!level.getBlockState(pos).is(frameBlock)) {
				return false;
			}
		}
		for (BlockPos pos : frame.opening()) {
			if (level.getBlockState(pos).is(frameBlock)) {
				return false;
			}
		}
		return true;
	}
}
