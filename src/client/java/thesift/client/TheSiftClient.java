package thesift.client;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientLifecycleEvents;
import net.fabricmc.fabric.api.client.particle.v1.ParticleProviderRegistry;
import net.fabricmc.fabric.api.client.render.fluid.v1.FluidRenderingRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.ModelLayerRegistry;
import net.minecraft.client.particle.FireflyParticle;
import net.minecraft.client.renderer.block.FluidModel;
import net.minecraft.client.renderer.entity.EntityRenderers;
import net.minecraft.client.resources.model.sprite.Material;

import thesift.TheSift;
import thesift.client.entity.BlubModel;
import thesift.client.entity.BlubRenderer;
import thesift.client.entity.NesterModel;
import thesift.client.entity.NesterRenderer;
import thesift.client.entity.RiftRenderer;
import thesift.client.entity.SingerModel;
import thesift.client.entity.SingerRenderer;
import thesift.client.particle.SiftMoteParticle;
import thesift.registry.ModEntities;
import thesift.registry.ModFluids;
import thesift.registry.ModParticles;

/**
 * Client-only entrypoint. Rendering, models, particles and other client-side registration go here,
 * never in the common source set.
 */
public final class TheSiftClient implements ClientModInitializer {
	@Override
	public void onInitializeClient() {
		// Ichor meshes itself (IchorSheen, D-037): one big seamless field over every block. The model's
		// sprites are the field and the fall (translucent, so the translucent layer), with no overlay
		// and no tint: the colour is the texture's own.
		FluidRenderingRegistry.register(ModFluids.ICHOR, ModFluids.FLOWING_ICHOR, new FluidModel.Unbaked(
				new Material(TheSift.id("block/ichor_field")), new Material(TheSift.id("block/ichor_fall")), null, null),
				new IchorSheen());
		ParticleProviderRegistry.getInstance().register(ModParticles.TRILL, SiftMoteParticle.TrillProvider::new);
		ParticleProviderRegistry.getInstance().register(ModParticles.GLIMMER, FireflyParticle.FireflyProvider::new);
		ParticleProviderRegistry.getInstance().register(ModParticles.GLOW_PETAL, SiftMoteParticle.GlowPetalProvider::new);
		ModelLayerRegistry.registerModelLayer(BlubRenderer.LAYER, BlubModel::createBodyLayer);
		ModelLayerRegistry.registerModelLayer(NesterRenderer.LAYER, NesterModel::createBodyLayer);
		ModelLayerRegistry.registerModelLayer(SingerRenderer.LAYER, SingerModel::createBodyLayer);
		EntityRenderers.register(ModEntities.BLUB, BlubRenderer::new);
		EntityRenderers.register(ModEntities.NESTER, NesterRenderer::new);
		EntityRenderers.register(ModEntities.RIFT, RiftRenderer::new);
		EntityRenderers.register(ModEntities.SINGER, SingerRenderer::new);
		// The sound manager exists once the client has started.
		ClientLifecycleEvents.CLIENT_STARTED.register(client -> MusicListener.install());
	}
}
