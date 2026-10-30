package thesift.client.entity;

import com.mojang.blaze3d.vertex.PoseStack;

import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.resources.Identifier;

import thesift.TheSift;
import thesift.entity.singer.Singer;

/** The Singer: tall (drawn at 1.15 ×), its clips driven by its singing; while faded it is invisible. */
public final class SingerRenderer extends MobRenderer<Singer, SingerModel.State, SingerModel> {
	public static final ModelLayerLocation LAYER = new ModelLayerLocation(TheSift.id("singer"), "main");
	private static final Identifier TEXTURE = TheSift.id("textures/entity/singer/singer.png");
	private static final float SCALE = 1.15F;

	public SingerRenderer(EntityRendererProvider.Context context) {
		super(context, new SingerModel(context.bakeLayer(LAYER)), 0.6F);
	}

	@Override
	public SingerModel.State createRenderState() {
		return new SingerModel.State();
	}

	@Override
	public void extractRenderState(Singer entity, SingerModel.State state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		state.singing = entity.singing() > 0 ? entity.singing() - partialTicks : 0.0F;
		state.restored = entity.restored();
	}

	@Override
	protected void scale(SingerModel.State state, PoseStack poseStack) {
		poseStack.scale(SCALE, SCALE, SCALE);
	}

	@Override
	public Identifier getTextureLocation(SingerModel.State state) {
		return TEXTURE;
	}
}
