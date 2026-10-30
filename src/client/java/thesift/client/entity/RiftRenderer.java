package thesift.client.entity;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;

import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.state.EntityRenderState;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.client.renderer.state.level.CameraRenderState;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;

import thesift.TheSift;
import thesift.entity.rift.RiftEntity;

/**
 * A rift (survival_sift.md §2.1): a tall tear of the membrane's cyan and the ichor's film colours,
 * swirling (16 frames), always facing the viewer about its upright axis and lit by itself. It widens
 * open over a second and pinches shut as it closes.
 */
public final class RiftRenderer extends EntityRenderer<RiftEntity, RiftRenderer.State> {
	public static final int FRAMES = 16;
	private static final Identifier TEXTURE = TheSift.id("textures/entity/rift/rift.png");
	private static final RenderType RENDER_TYPE = RenderTypes.entityTranslucentEmissive(TEXTURE);
	private static final float WIDTH = 1.5F;
	private static final float HEIGHT = 3.0F;

	public RiftRenderer(EntityRendererProvider.Context context) {
		super(context);
	}

	public static final class State extends EntityRenderState {
		/** 0 shut, 1 fully open. */
		public float open;
		public int frame;
	}

	@Override
	public State createRenderState() {
		return new State();
	}

	@Override
	public void extractRenderState(RiftEntity entity, State state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		float now = entity.level().getGameTime() + partialTicks;
		float sinceOpen = now - entity.openedAt();
		float untilClose = entity.closesAt() - now;
		state.open = Mth.clamp(Math.min(sinceOpen, untilClose) / RiftEntity.OPENING, 0.0F, 1.0F);
		state.frame = Math.floorMod((int) (now / 3.0F), FRAMES);
	}

	@Override
	public void submit(State state, PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera) {
		if (state.open > 0.0F) {
			poseStack.pushPose();
			poseStack.rotate(Axis.YP.rotationDegrees(180.0F - camera.yRot));
			float eased = state.open * state.open * (3.0F - 2.0F * state.open);
			poseStack.scale(WIDTH * eased, HEIGHT * (0.4F + 0.6F * eased), 1.0F);
			float v0 = state.frame / (float) FRAMES;
			float v1 = (state.frame + 1) / (float) FRAMES;
			collector.submitCustomGeometry(poseStack, RENDER_TYPE, (pose, buffer) -> {
				vertex(buffer, pose, -0.5F, 0.0F, 0.0F, v1);
				vertex(buffer, pose, 0.5F, 0.0F, 1.0F, v1);
				vertex(buffer, pose, 0.5F, 1.0F, 1.0F, v0);
				vertex(buffer, pose, -0.5F, 1.0F, 0.0F, v0);
			});
			poseStack.popPose();
		}
		super.submit(state, poseStack, collector, camera);
	}

	private static void vertex(VertexConsumer buffer, PoseStack.Pose pose, float x, float y, float u, float v) {
		buffer.addVertex(pose, x, y, 0.0F).setColor(-1).setUv(u, v).setOverlay(OverlayTexture.NO_OVERLAY).setLight(0xF000F0)
				.setNormal(pose, 0.0F, 0.0F, 1.0F);
	}
}
