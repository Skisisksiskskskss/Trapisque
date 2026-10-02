package thesift.client;

import com.mojang.blaze3d.vertex.VertexConsumer;

import net.fabricmc.fabric.api.client.render.fluid.v1.FluidRenderHandler;
import net.minecraft.client.renderer.block.BlockAndTintGetter;
import net.minecraft.client.renderer.block.FluidRenderer;
import net.minecraft.core.BlockPos;
import net.minecraft.util.ARGB;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.FluidState;

/**
 * Ichor's soap-bubble sheen (owner playtest 2, D-026). The ichor textures are a faint, pale
 * shimmer, as vanilla's water textures are grey; this handler colours them. A smooth, swirled field
 * over the world's x and z walks the film's colour cycle (the {@code ichor} ramp's first twenty
 * entries in docs/DESIGN/palette.md), so turquoise, mint, gold, rose and lilac lie in broad bands
 * across a pond, as a bubble's colours lie, instead of one pattern repeating on every block.
 *
 * <p>A tint source gives a whole block one colour, which turned ponds into a mosaic. So vanilla's
 * geometry is drawn untinted and each vertex takes the colour at its own corner: neighbouring
 * blocks share their corners, and the colours blend across faces with no edge.
 */
public final class IchorSheen implements FluidRenderHandler {
	/** The ichor ramp's film cycle, in order (palette.md). */
	private static final int[] FILM = {
			0x1f7a92, 0x23879d, 0x2f96aa, 0x3fa7b6, 0x56b9c0, 0x72c8c3, 0x93d4bf, 0xb6dcae, 0xd4dd9f, 0xecd79a,
			0xf2c7a2, 0xf1b4b5, 0xe8a7c8, 0xd7a3dc, 0xbea5ea, 0xa3aaf0, 0x889fe4, 0x6d97d2, 0x5590c3, 0x3a86ae};
	/** The walk over the cycle: it lingers in turquoise (2-5) before going once round, so turquoise leads. */
	private static final int[] WALK = {2, 3, 4, 5, 4, 3, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 0, 1};
	/** Blocks per radian of the field: turquoise patches a dozen or so blocks across, rimmed by bands a few blocks wide. */
	private static final double SCALE = 8.0;

	@Override
	public void renderFluid(FluidRenderer fluidRenderer, BlockPos pos, BlockAndTintGetter level, FluidRenderer.Output output,
			BlockState blockState, FluidState fluidState) {
		// Vertices arrive relative to the 16-block section; their world corner is the section's origin plus that.
		int originX = pos.getX() & ~15;
		int originZ = pos.getZ() & ~15;
		FluidRenderHandler.super.renderFluid(fluidRenderer, pos, level,
				layer -> new Tinted(output.getBuilder(layer), originX, originZ), blockState, fluidState);
	}

	/** The sheen at a point of the world, opaque. */
	static int colourAt(double x, double z) {
		return film(field(x, z));
	}

	/** Where (x, z) falls on the walk, before wrapping: a swirled interference of two waves. */
	static double field(double x, double z) {
		double a = x / SCALE;
		double b = z / SCALE;
		double wa = a + 0.9 * Math.sin(0.7 * b + 1.3) + 0.4 * Math.sin(1.9 * b - 0.6 * a);
		double wb = b + 0.9 * Math.sin(0.8 * a + 4.1) + 0.4 * Math.sin(1.7 * a + 0.5 * b + 2.2);
		return 1.15 * (0.5 + 0.3 * Math.sin(wa + 0.6 * wb) + 0.2 * Math.sin(1.3 * wb - 0.4 * wa + 2.0));
	}

	/** The film colour at a point on the walk, blended between its two nearest stops. */
	static int film(double p) {
		double s = (p - Math.floor(p)) * WALK.length;
		int i = (int) s;
		int from = FILM[WALK[i % WALK.length]];
		int to = FILM[WALK[(i + 1) % WALK.length]];
		return ARGB.srgbLerp((float) (s - i), 0xFF000000 | from, 0xFF000000 | to);
	}

	/** Passes vanilla's fluid vertices on, each multiplied by the sheen at its corner. */
	private record Tinted(VertexConsumer inner, int originX, int originZ) implements VertexConsumer {
		@Override
		public void addVertex(float x, float y, float z, int color, float u, float v, int overlayCoords, int lightCoords,
				float nx, float ny, float nz) {
			int sheen = colourAt(originX + x, originZ + z);
			inner.addVertex(x, y, z, ARGB.multiply(color, sheen), u, v, overlayCoords, lightCoords, nx, ny, nz);
		}

		@Override
		public VertexConsumer addVertex(float x, float y, float z) {
			return inner.addVertex(x, y, z);
		}

		@Override
		public VertexConsumer setColor(int r, int g, int b, int a) {
			return inner.setColor(r, g, b, a);
		}

		@Override
		public VertexConsumer setColor(int color) {
			return inner.setColor(color);
		}

		@Override
		public VertexConsumer setUv(float u, float v) {
			return inner.setUv(u, v);
		}

		@Override
		public VertexConsumer setUv1(int u, int v) {
			return inner.setUv1(u, v);
		}

		@Override
		public VertexConsumer setUv2(int u, int v) {
			return inner.setUv2(u, v);
		}

		@Override
		public VertexConsumer setUv3(float u, float v) {
			return inner.setUv3(u, v);
		}

		@Override
		public VertexConsumer setNormal(float x, float y, float z) {
			return inner.setNormal(x, y, z);
		}

		@Override
		public VertexConsumer setLineWidth(float width) {
			return inner.setLineWidth(width);
		}
	}
}
