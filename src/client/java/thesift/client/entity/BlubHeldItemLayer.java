package thesift.client.entity;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;

import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.item.ItemStackRenderState;
import net.minecraft.client.renderer.texture.OverlayTexture;

/** What a foraging blub carries (BlubGoals.Forage, D-029), held crosswise in its mouth as a fox holds things. */
public final class BlubHeldItemLayer extends RenderLayer<BlubRenderState, BlubModel> {
	public BlubHeldItemLayer(RenderLayerParent<BlubRenderState, BlubModel> renderer) {
		super(renderer);
	}

	@Override
	public void submit(PoseStack poseStack, SubmitNodeCollector submitNodeCollector, int lightCoords, BlubRenderState state, float yRot,
			float xRot) {
		ItemStackRenderState item = state.heldItem;
		if (item.isEmpty()) {
			return;
		}
		poseStack.pushPose();
		this.getParentModel().body().translateAndRotate(poseStack);
		// The mouth: low on the body's front face (the body's box runs y -7..0, z -4..4).
		poseStack.translate(0.0F, -1.5F / 16.0F, -4.4F / 16.0F);
		poseStack.rotateDegrees(Axis.XP, 90.0F);
		item.submit(poseStack, submitNodeCollector, lightCoords, OverlayTexture.NO_OVERLAY, state.outlineColor);
		poseStack.popPose();
	}
}
