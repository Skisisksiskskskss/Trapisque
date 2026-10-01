package thesift.client.entity;

import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.resources.Identifier;

import thesift.TheSift;
import thesift.entity.blub.Blub;

/** Renders the Blub (the Meadow skin; other skins come later, mob_blub.md). */
public class BlubRenderer extends MobRenderer<Blub, BlubRenderState, BlubModel> {
	public static final ModelLayerLocation LAYER = new ModelLayerLocation(TheSift.id("blub"), "main");
	private static final Identifier TEXTURE = TheSift.id("textures/entity/blub/blub.png");

	public BlubRenderer(EntityRendererProvider.Context context) {
		super(context, new BlubModel(context.bakeLayer(LAYER)), 0.3F);
	}

	@Override
	public BlubRenderState createRenderState() {
		return new BlubRenderState();
	}

	@Override
	public void extractRenderState(Blub entity, BlubRenderState state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		state.sitting = entity.isInSittingPose();
	}

	@Override
	public Identifier getTextureLocation(BlubRenderState state) {
		return TEXTURE;
	}
}
