package thesift.client.entity;

import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.client.renderer.entity.layers.LivingEntityEmissiveLayer;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.resources.Identifier;

import thesift.TheSift;
import thesift.entity.nester.Nester;

/** The Nester: its model's clips follow the synced state; an enduring one is pale cyan, its eyes and antennae aglow (D-034). */
public final class NesterRenderer extends MobRenderer<Nester, NesterRenderState, NesterModel> {
	public static final ModelLayerLocation LAYER = new ModelLayerLocation(TheSift.id("nester"), "main");
	private static final Identifier TEXTURE = TheSift.id("textures/entity/nester/nester.png");
	private static final Identifier SOUL = TheSift.id("textures/entity/nester/nester_soul.png");
	private static final Identifier GLOW = TheSift.id("textures/entity/nester/nester_glow.png");

	public NesterRenderer(EntityRendererProvider.Context context) {
		super(context, new NesterModel(context.bakeLayer(LAYER)), 0.5F);
		this.addLayer(new LivingEntityEmissiveLayer<>(this, state -> GLOW, (state, ageInTicks) -> state.glow,
				this.getModel(), RenderTypes::entityTranslucentEmissive, false));
	}

	@Override
	public NesterRenderState createRenderState() {
		return new NesterRenderState();
	}

	@Override
	public void extractRenderState(Nester entity, NesterRenderState state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		state.state = entity.state();
		state.stateTime = entity.clientStateTicks() + partialTicks;
		state.enduring = entity.isEnduring();
		state.glow = state.enduring ? 1.0F : 0.0F;
	}

	@Override
	public Identifier getTextureLocation(NesterRenderState state) {
		return state.enduring ? SOUL : TEXTURE;
	}
}
