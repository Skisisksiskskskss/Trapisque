package thesift.entry;

import java.util.ArrayList;
import java.util.List;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

/**
 * A rectangular frame standing in one vertical plane: an Ancient City frame in the Overworld or a
 * gate in the Sift (entry_path.md). {@code origin} is the lowest corner; the frame runs
 * {@code width} blocks along {@code axis} and {@code height} blocks up, and the opening is
 * everything inside the border.
 */
public record SiftFrame(BlockPos origin, Direction.Axis axis, int width, int height) {
	/** The Ancient City frame: 22 x 8 reinforced deepslate around a 20 x 6 opening (VANILLA_ANALOGS W6). */
	public static final int CITY_WIDTH = 22;
	public static final int CITY_HEIGHT = 8;
	/** The Sift-side gate: 6 x 7 gatestone around a 4 x 5 opening. */
	public static final int GATE_WIDTH = 6;
	public static final int GATE_HEIGHT = 7;

	public static final Codec<SiftFrame> CODEC = RecordCodecBuilder.create(i -> i.group(
			BlockPos.CODEC.fieldOf("origin").forGetter(SiftFrame::origin),
			Direction.Axis.CODEC.fieldOf("axis").forGetter(SiftFrame::axis),
			Codec.INT.fieldOf("width").forGetter(SiftFrame::width),
			Codec.INT.fieldOf("height").forGetter(SiftFrame::height)
	).apply(i, SiftFrame::new));

	/** The block at {@code u} along the frame and {@code v} up from its origin. */
	public BlockPos at(int u, int v) {
		return this.axis == Direction.Axis.X ? this.origin.offset(u, v, 0) : this.origin.offset(0, v, u);
	}

	private boolean inPlane(BlockPos pos) {
		return this.axis == Direction.Axis.X ? pos.getZ() == this.origin.getZ() : pos.getX() == this.origin.getX();
	}

	private int u(BlockPos pos) {
		return this.axis == Direction.Axis.X ? pos.getX() - this.origin.getX() : pos.getZ() - this.origin.getZ();
	}

	public boolean isBorder(BlockPos pos) {
		if (!this.inPlane(pos)) {
			return false;
		}
		int u = this.u(pos);
		int v = pos.getY() - this.origin.getY();
		return u >= 0 && v >= 0 && u < this.width && v < this.height
				&& (u == 0 || v == 0 || u == this.width - 1 || v == this.height - 1);
	}

	public boolean inOpening(BlockPos pos) {
		if (!this.inPlane(pos)) {
			return false;
		}
		int u = this.u(pos);
		int v = pos.getY() - this.origin.getY();
		return u > 0 && v > 0 && u < this.width - 1 && v < this.height - 1;
	}

	public List<BlockPos> border() {
		List<BlockPos> out = new ArrayList<>(2 * (this.width + this.height) - 4);
		for (int u = 0; u < this.width; u++) {
			for (int v = 0; v < this.height; v++) {
				if (u == 0 || v == 0 || u == this.width - 1 || v == this.height - 1) {
					out.add(this.at(u, v));
				}
			}
		}
		return out;
	}

	public List<BlockPos> opening() {
		List<BlockPos> out = new ArrayList<>((this.width - 2) * (this.height - 2));
		for (int u = 1; u < this.width - 1; u++) {
			for (int v = 1; v < this.height - 1; v++) {
				out.add(this.at(u, v));
			}
		}
		return out;
	}

	/** Where an arriving entity stands: the bottom middle of the opening, like a Nether portal arrival. */
	public Vec3 arrival() {
		Vec3 base = Vec3.atLowerCornerOf(this.at(0, 1));
		return this.axis == Direction.Axis.X ? base.add(this.width / 2.0, 0, 0.5) : base.add(0.5, 0, this.width / 2.0);
	}

	public AABB box() {
		BlockPos far = this.at(this.width - 1, this.height - 1);
		return AABB.encapsulatingFullBlocks(this.origin, far);
	}

	public Vec3 center() {
		return this.box().getCenter();
	}

	/** Distance from {@code pos} to the nearest point of the frame (0 inside it). */
	public double distanceTo(Vec3 pos) {
		AABB box = this.box();
		double dx = Math.max(0, Math.max(box.minX - pos.x, pos.x - box.maxX));
		double dy = Math.max(0, Math.max(box.minY - pos.y, pos.y - box.maxY));
		double dz = Math.max(0, Math.max(box.minZ - pos.z, pos.z - box.maxZ));
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	}
}
