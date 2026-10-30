package thesift.client;

import com.mojang.blaze3d.vertex.VertexConsumer;

import net.fabricmc.fabric.api.client.render.fluid.v1.FluidRenderHandler;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.Sheets;
import net.minecraft.client.renderer.block.BlockAndTintGetter;
import net.minecraft.client.renderer.block.FluidRenderer;
import net.minecraft.client.renderer.chunk.ChunkSectionLayer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;
import net.minecraft.client.resources.model.sprite.SpriteId;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.ARGB;
import net.minecraft.util.LightCoordsUtil;
import net.minecraft.world.level.CardinalLighting;
import net.minecraft.world.level.block.HalfTransparentBlock;
import net.minecraft.world.level.block.LeavesBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.TheSift;

/**
 * Draws ichor (owner playtest 6, D-037): one big, seamless, moving picture over every ichor block, as
 * Dungeons II's pools are, instead of a block's tile or a colour per block. {@code ichor_field} is an
 * animated 16 x 16-block tile of an oil slick's marbled colours and glitter (tools/art/ichor_art.py);
 * each face takes its own part of it by world position, so neighbouring blocks continue each other's
 * colours with no seam, gradients run through a block, and the colours swirl as the texture animates.
 * Sides of falling or flowing ichor take {@code ichor_fall}, the same colours drawn out into ribbons
 * that pour downward, mapped the same way.
 *
 * <p>This handler meshes ichor itself rather than recolouring vanilla's mesh: Sodium (and Iris, which
 * draws through it) replaces vanilla's fluid mesher with its own and ignores a wrapped vertex consumer,
 * but takes geometry a handler emits. The faces, heights and culling follow vanilla's
 * {@link FluidRenderer#tesselate}; only the texture mapping and the colour differ. Vertex colours are
 * white but for vanilla's face shading and a faint, broad brightness drift, so the colour is the
 * texture's, and shader packs see an ordinary translucent surface to reflect and refract.
 */
public final class IchorSheen implements FluidRenderHandler {
	/** Blocks one tile of each texture spans (tools/art/ichor_art.py FIELD_TILE, FALL_TILE). */
	static final int FIELD_TILE = 16;
	static final int FALL_TILE = 4;
	private static final SpriteId FIELD = Sheets.BLOCKS_MAPPER.apply(TheSift.id("ichor_field"));
	private static final SpriteId FALL = Sheets.BLOCKS_MAPPER.apply(TheSift.id("ichor_fall"));
	private static final float OFFSET = 0.001F;

	@Override
	public void renderFluid(FluidRenderer fluidRenderer, BlockPos pos, BlockAndTintGetter level, FluidRenderer.Output output,
			BlockState blockState, FluidState fluidState) {
		BlockState down = level.getBlockState(pos.below());
		BlockState up = level.getBlockState(pos.above());
		BlockState north = level.getBlockState(pos.north());
		BlockState south = level.getBlockState(pos.south());
		BlockState west = level.getBlockState(pos.west());
		BlockState east = level.getBlockState(pos.east());
		Fluid type = fluidState.getType();
		boolean renderUp = !up.getFluidState().getType().isSame(type);
		boolean renderDown = FluidRenderer.shouldRenderFace(fluidState, blockState, Direction.DOWN, down.getFluidState())
				&& !occludes(Direction.DOWN, 0.8888889F, down);
		boolean renderNorth = FluidRenderer.shouldRenderFace(fluidState, blockState, Direction.NORTH, north.getFluidState());
		boolean renderSouth = FluidRenderer.shouldRenderFace(fluidState, blockState, Direction.SOUTH, south.getFluidState());
		boolean renderWest = FluidRenderer.shouldRenderFace(fluidState, blockState, Direction.WEST, west.getFluidState());
		boolean renderEast = FluidRenderer.shouldRenderFace(fluidState, blockState, Direction.EAST, east.getFluidState());
		if (!(renderUp || renderDown || renderNorth || renderSouth || renderWest || renderEast)) {
			return;
		}
		VertexConsumer builder = output.getBuilder(ChunkSectionLayer.TRANSLUCENT);
		TextureAtlasSprite field = Minecraft.getInstance().getAtlasManager().get(FIELD);
		TextureAtlasSprite fall = Minecraft.getInstance().getAtlasManager().get(FALL);
		CardinalLighting lighting = level.cardinalLighting();

		float self = height(level, type, pos, blockState, fluidState);
		float hNE;
		float hNW;
		float hSE;
		float hSW;
		if (self >= 1.0F) {
			hNE = hNW = hSE = hSW = 1.0F;
		} else {
			float hN = height(level, type, pos.north(), north, north.getFluidState());
			float hS = height(level, type, pos.south(), south, south.getFluidState());
			float hE = height(level, type, pos.east(), east, east.getFluidState());
			float hW = height(level, type, pos.west(), west, west.getFluidState());
			hNE = cornerHeight(level, type, self, hN, hE, pos.north().east());
			hNW = cornerHeight(level, type, self, hN, hW, pos.north().west());
			hSE = cornerHeight(level, type, self, hS, hE, pos.south().east());
			hSW = cornerHeight(level, type, self, hS, hW, pos.south().west());
		}

		// Vertices are relative to the 16-block section; textures are mapped by world position.
		int wx = pos.getX();
		int wy = pos.getY();
		int wz = pos.getZ();
		float x = wx & 15;
		float y = wy & 15;
		float z = wz & 15;
		float bottom = renderDown ? OFFSET : 0.0F;
		// The block's corner on each tile, as a fraction of the tile.
		float fu = Math.floorMod(wx, FIELD_TILE) / (float) FIELD_TILE;
		float fv = Math.floorMod(wz, FIELD_TILE) / (float) FIELD_TILE;
		float fStep = 1.0F / FIELD_TILE;

		if (renderUp && !occludes(Direction.UP, Math.min(Math.min(hNW, hSW), Math.min(hSE, hNE)), up)) {
			hNW -= OFFSET;
			hSW -= OFFSET;
			hSE -= OFFSET;
			hNE -= OFFSET;
			int light = light(level, pos);
			float shade = lighting.up();
			// North-west, south-west, south-east, north-east, as vanilla winds the top face.
			int cNW = colour(shade, wx, wz);
			int cSW = colour(shade, wx, wz + 1);
			int cSE = colour(shade, wx + 1, wz + 1);
			int cNE = colour(shade, wx + 1, wz);
			float u0 = field.getU(fu);
			float u1 = field.getU(fu + fStep);
			float v0 = field.getV(fv);
			float v1 = field.getV(fv + fStep);
			vertex(builder, x, y + hNW, z, cNW, u0, v0, light);
			vertex(builder, x, y + hSW, z + 1.0F, cSW, u0, v1, light);
			vertex(builder, x + 1.0F, y + hSE, z + 1.0F, cSE, u1, v1, light);
			vertex(builder, x + 1.0F, y + hNE, z, cNE, u1, v0, light);
			if (fluidState.shouldRenderBackwardUpFace(level, pos.above())) {
				vertex(builder, x, y + hNW, z, cNW, u0, v0, light);
				vertex(builder, x + 1.0F, y + hNE, z, cNE, u1, v0, light);
				vertex(builder, x + 1.0F, y + hSE, z + 1.0F, cSE, u1, v1, light);
				vertex(builder, x, y + hSW, z + 1.0F, cSW, u0, v1, light);
			}
		}

		if (renderDown) {
			int light = light(level, pos.below());
			float shade = lighting.down();
			float u0 = field.getU(fu);
			float u1 = field.getU(fu + fStep);
			float v0 = field.getV(fv);
			float v1 = field.getV(fv + fStep);
			vertex(builder, x, y + bottom, z, colour(shade, wx, wz), u0, v0, light);
			vertex(builder, x + 1.0F, y + bottom, z, colour(shade, wx + 1, wz), u1, v0, light);
			vertex(builder, x + 1.0F, y + bottom, z + 1.0F, colour(shade, wx + 1, wz + 1), u1, v1, light);
			vertex(builder, x, y + bottom, z + 1.0F, colour(shade, wx, wz + 1), u0, v1, light);
		}

		// Falling or flowing ichor pours down its sides; a still pool's side (through glass) shows the field.
		boolean pouring = !fluidState.isSource();
		int sideLight = light(level, pos);
		for (Direction face : Direction.Plane.HORIZONTAL) {
			float h0;
			float h1;
			float x0;
			float x1;
			float z0;
			float z1;
			boolean render;
			BlockState neighbour;
			// Where the face's two edges lie along the world axis it runs on, and where its plane lies.
			int along0;
			int along1;
			int plane;
			switch (face) {
				case NORTH -> {
					h0 = hNW;
					h1 = hNE;
					x0 = x;
					x1 = x + 1.0F;
					z0 = z1 = z + OFFSET;
					render = renderNorth;
					neighbour = north;
					along0 = wx;
					along1 = wx + 1;
					plane = wz;
				}
				case SOUTH -> {
					h0 = hSE;
					h1 = hSW;
					x0 = x + 1.0F;
					x1 = x;
					z0 = z1 = z + 1.0F - OFFSET;
					render = renderSouth;
					neighbour = south;
					along0 = wx + 1;
					along1 = wx;
					plane = wz + 1;
				}
				case WEST -> {
					h0 = hSW;
					h1 = hNW;
					x0 = x1 = x + OFFSET;
					z0 = z + 1.0F;
					z1 = z;
					render = renderWest;
					neighbour = west;
					along0 = wz + 1;
					along1 = wz;
					plane = wx;
				}
				default -> {
					h0 = hNE;
					h1 = hSE;
					x0 = x1 = x + 1.0F - OFFSET;
					z0 = z;
					z1 = z + 1.0F;
					render = renderEast;
					neighbour = east;
					along0 = wz;
					along1 = wz + 1;
					plane = wx + 1;
				}
			}
			if (!render || occludes(face, Math.max(h0, h1), neighbour)) {
				continue;
			}
			// Against glass or leaves the face is seen from inside the pool too: one-sided, as vanilla's overlay.
			boolean throughGlass = neighbour.getBlock() instanceof HalfTransparentBlock || neighbour.getBlock() instanceof LeavesBlock;
			TextureAtlasSprite sprite = pouring && !throughGlass ? fall : field;
			int tile = sprite == fall ? FALL_TILE : FIELD_TILE;
			// Across the face: the world coordinate it runs along. Down the face: world height, falling.
			float edge = Math.min(along0, along1);
			float a0 = (Math.floorMod((int) edge, tile) + (along0 - edge)) / tile;
			float a1 = (Math.floorMod((int) edge, tile) + (along1 - edge)) / tile;
			float top = Math.floorMod(-wy - 1, tile) / (float) tile; // the block's top edge, down the tile
			float u0 = sprite.getU(a0);
			float u1 = sprite.getU(a1);
			float v0 = sprite.getV(top + (1.0F - h0) / tile);
			float v1 = sprite.getV(top + (1.0F - h1) / tile);
			float vb = sprite.getV(top + (1.0F - bottom) / tile);
			float shade = lighting.up() * (face.getAxis() == Direction.Axis.Z ? lighting.north() : lighting.west());
			int c0 = face.getAxis() == Direction.Axis.Z ? colour(shade, along0, plane) : colour(shade, plane, along0);
			int c1 = face.getAxis() == Direction.Axis.Z ? colour(shade, along1, plane) : colour(shade, plane, along1);
			vertex(builder, x0, y + h0, z0, c0, u0, v0, sideLight);
			vertex(builder, x1, y + h1, z1, c1, u1, v1, sideLight);
			vertex(builder, x1, y + bottom, z1, c1, u1, vb, sideLight);
			vertex(builder, x0, y + bottom, z0, c0, u0, vb, sideLight);
			if (!throughGlass) {
				vertex(builder, x0, y + h0, z0, c0, u0, v0, sideLight);
				vertex(builder, x0, y + bottom, z0, c0, u0, vb, sideLight);
				vertex(builder, x1, y + bottom, z1, c1, u1, vb, sideLight);
				vertex(builder, x1, y + h1, z1, c1, u1, v1, sideLight);
			}
		}
	}

	/**
	 * White, scaled by the face's shade and a faint brightness drift over a few dozen blocks: the
	 * field tile repeats every 16 blocks, and this keeps the repeats from being exact. Corners shared
	 * by neighbouring blocks get the same colour, so the drift has no edges either.
	 */
	static int colour(float shade, int cornerX, int cornerZ) {
		double drift = 0.5 + 0.25 * Math.sin(cornerX * 0.083 + cornerZ * 0.051 + 1.3) + 0.25 * Math.sin(cornerZ * 0.097 - cornerX * 0.037 + 4.1);
		return ARGB.scaleRGB(0xFFFFFFFF, shade * (float) (0.9 + 0.1 * drift));
	}

	private static void vertex(VertexConsumer builder, float x, float y, float z, int colour, float u, float v, int light) {
		builder.addVertex(x, y, z, colour, u, v, OverlayTexture.NO_OVERLAY, light, 0.0F, 1.0F, 0.0F);
	}

	private static int light(BlockAndTintGetter level, BlockPos pos) {
		return LightCoordsUtil.max(LightCoordsUtil.getLightCoords(level, pos), LightCoordsUtil.getLightCoords(level, pos.above()));
	}

	/** Whether a neighbour hides the face toward it (vanilla's isFaceOccludedByState). */
	private static boolean occludes(Direction direction, float height, BlockState neighbour) {
		VoxelShape occluder = neighbour.getFaceOcclusionShape(direction.getOpposite());
		if (occluder == Shapes.empty()) {
			return false;
		}
		if (occluder == Shapes.block()) {
			return direction != Direction.UP || height == 1.0F;
		}
		return Shapes.blockOccludes(Shapes.box(0.0, 0.0, 0.0, 1.0, height, 1.0), occluder, direction);
	}

	/** A corner's height: vanilla's average of the four blocks around it, full ones weighted ten to one. */
	private static float cornerHeight(BlockAndTintGetter level, Fluid type, float self, float a, float b, BlockPos corner) {
		if (a >= 1.0F || b >= 1.0F) {
			return 1.0F;
		}
		float[] weighted = new float[2];
		if (a > 0.0F || b > 0.0F) {
			BlockState state = level.getBlockState(corner);
			float diagonal = height(level, type, corner, state, state.getFluidState());
			if (diagonal >= 1.0F) {
				return 1.0F;
			}
			addWeighted(weighted, diagonal);
		}
		addWeighted(weighted, self);
		addWeighted(weighted, a);
		addWeighted(weighted, b);
		return weighted[0] / weighted[1];
	}

	private static void addWeighted(float[] weighted, float height) {
		if (height >= 0.8F) {
			weighted[0] += height * 10.0F;
			weighted[1] += 10.0F;
		} else if (height >= 0.0F) {
			weighted[0] += height;
			weighted[1]++;
		}
	}

	/** The fluid's height in a block: full under more of it, its own level otherwise; 0 open, -1 solid. */
	@SuppressWarnings("deprecation") // isSolid(), as vanilla's own mesher asks
	private static float height(BlockAndTintGetter level, Fluid type, BlockPos pos, BlockState state, FluidState fluid) {
		if (type.isSame(fluid.getType())) {
			return type.isSame(level.getBlockState(pos.above()).getFluidState().getType()) ? 1.0F : fluid.getOwnHeight();
		}
		return state.isSolid() ? -1.0F : 0.0F;
	}
}
