package thesift.registry;

import net.fabricmc.fabric.api.particle.v1.FabricParticleTypes;
import net.minecraft.core.Registry;
import net.minecraft.core.particles.SimpleParticleType;
import net.minecraft.core.registries.BuiltInRegistries;

import thesift.TheSift;

/** Particle types (D-019). Trills drift through Thrive; glow petals fall through Endure (rules.md, creatures.md). */
public final class ModParticles {
	public static final SimpleParticleType TRILL = Registry.register(BuiltInRegistries.PARTICLE_TYPE, TheSift.id("trill"), FabricParticleTypes.simple(false));
	public static final SimpleParticleType GLOW_PETAL = Registry.register(BuiltInRegistries.PARTICLE_TYPE, TheSift.id("glow_petal"), FabricParticleTypes.simple(false));

	private ModParticles() {
	}

	public static void init() {
		// Class loading registers the fields above.
	}
}
