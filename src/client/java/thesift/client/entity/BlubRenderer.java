package thesift.client.entity;

import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.client.renderer.entity.layers.LivingEntityEmissiveLayer;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.material.FluidState;

import thesift.TheSift;
import thesift.entity.blub.Blub;
import thesift.registry.ModTags;

/** Renders the Blub (the Meadow skin; other skins come later, mob_blub.md), with its glowing belly. */
public final class BlubRenderer extends MobRenderer<Blub, BlubRenderState, BlubModel> {
	public static final ModelLayerLocation LAYER = new ModelLayerLocation(TheSift.id("blub"), "main");
	private static final Identifier TEXTURE = TheSift.id("textures/entity/blub/blub.png");
	private static final Identifier GLOW = TheSift.id("textures/entity/blub/blub_glow.png");
	/** The belly's height above the feet, in blocks: a bathing blub sits in ichor up to here. */
	private static final float BELLY = 0.22F;

	public BlubRenderer(EntityRendererProvider.Context context) {
		super(context, new BlubModel(context.bakeLayer(LAYER)), 0.3F);
		// The Endure lantern: render only, fading in and out (the warden's glow layer, with our alpha).
		this.addLayer(new LivingEntityEmissiveLayer<>(this, state -> GLOW, (state, ageInTicks) -> state.glow,
				this.getModel(), RenderTypes::entityTranslucentEmissive, false));
	}

	@Override
	public BlubRenderState createRenderState() {
		return new BlubRenderState();
	}

	@Override
	public void extractRenderState(Blub entity, BlubRenderState state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		state.sitting = entity.isInSittingPose();
		state.listening = entity.isListening();
		state.curled = entity.isCurled();
		state.restless = entity.isRestless();
		state.stacked = entity.isPassenger() && entity.getVehicle() instanceof Blub || entity.isVehicle();
		int level = 0;
		for (Entity e = entity.getVehicle(); e instanceof Blub; e = e.getVehicle()) {
			level++;
		}
		state.towerLevel = level;
		state.airborne = !entity.onGround() && !entity.isPassenger() && entity.getDeltaMovement().y > 0.05;
		state.sing = entity.singProgress(partialTicks);
		state.teeter = entity.teeter(partialTicks);
		state.glow = entity.glow(partialTicks);
		BlockPos pos = entity.blockPosition();
		FluidState fluid = entity.level().getFluidState(pos);
		state.bathe = fluid.is(ModTags.ICHOR) && !entity.isPassenger()
				? Math.max(0.0F, pos.getY() + fluid.getHeight(entity.level(), pos) - (float) entity.getY() - BELLY)
				: 0.0F;
	}

	@Override
	public Identifier getTextureLocation(BlubRenderState state) {
		return TEXTURE;
	}
}
