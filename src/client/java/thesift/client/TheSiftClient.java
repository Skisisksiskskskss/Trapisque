package thesift.client;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientLifecycleEvents;
import net.fabricmc.fabric.api.client.particle.v1.ParticleProviderRegistry;
import net.fabricmc.fabric.api.client.render.fluid.v1.FluidRenderingRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.ModelLayerRegistry;
import net.minecraft.client.renderer.block.FluidModel;
import net.minecraft.client.renderer.entity.EntityRenderers;
import net.minecraft.client.renderer.fog.FogRenderer;
import net.minecraft.client.resources.model.sprite.Material;

import thesift.TheSift;
import thesift.client.entity.BlubModel;
import thesift.client.entity.BlubRenderer;
import thesift.client.fog.IchorFogEnvironment;
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
		// Like vanilla lava: still and flowing sprites, no overlay, no tint.
		FluidRenderingRegistry.register(ModFluids.ICHOR, ModFluids.FLOWING_ICHOR, new FluidModel.Unbaked(
				new Material(TheSift.id("block/ichor_still")), new Material(TheSift.id("block/ichor_flow")), null, null));
		ParticleProviderRegistry.getInstance().register(ModParticles.TRILL, SiftMoteParticle.TrillProvider::new);
		ParticleProviderRegistry.getInstance().register(ModParticles.GLOW_PETAL, SiftMoteParticle.GlowPetalProvider::new);
		ModelLayerRegistry.registerModelLayer(BlubRenderer.LAYER, BlubModel::createBodyLayer);
		EntityRenderers.register(ModEntities.BLUB, BlubRenderer::new);
		// The fog inside ichor goes first, as lava's does, so it wins over the atmosphere.
		FogRenderer.FOG_ENVIRONMENTS.add(0, new IchorFogEnvironment());
		// The sound manager exists once the client has started.
		ClientLifecycleEvents.CLIENT_STARTED.register(client -> MusicListener.install());
	}
}
