package thesift.client.particle;

import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.particle.Particle;
import net.minecraft.client.particle.ParticleProvider;
import net.minecraft.client.particle.SingleQuadParticle;
import net.minecraft.client.particle.SpriteSet;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;
import net.minecraft.core.particles.SimpleParticleType;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;

/**
 * The Sift's ambient motes: they glow at full brightness, sway as they drift and fade in and out.
 * Trills rise slowly like pollen in Thrive; glow petals sink through Endure.
 */
public class SiftMoteParticle extends SingleQuadParticle {
	private static final int FULL_BRIGHT = 0xF000F0;
	private final double sink;
	private final float phase;

	protected SiftMoteParticle(ClientLevel level, double x, double y, double z, TextureAtlasSprite sprite, double sink, float size, int lifetime) {
		super(level, x, y, z, sprite);
		this.sink = sink;
		this.phase = this.random.nextFloat() * Mth.TWO_PI;
		this.quadSize = size * (0.7F + this.random.nextFloat() * 0.6F);
		this.lifetime = lifetime + this.random.nextInt(lifetime / 2);
		this.hasPhysics = false;
		this.gravity = 0.0F;
		this.friction = 1.0F;
		this.alpha = 0.0F;
	}

	@Override
	public void tick() {
		float t = (this.age + this.phase * 10) * 0.05F;
		this.xd = Mth.sin(t) * 0.01;
		this.zd = Mth.cos(t * 0.8F) * 0.01;
		this.yd = this.sink;
		super.tick();
		float life = (float) this.age / this.lifetime;
		this.alpha = Mth.clamp(Math.min(life * 6.0F, (1.0F - life) * 4.0F), 0.0F, 0.9F);
		this.oRoll = this.roll;
		this.roll += 0.02F;
	}

	@Override
	protected int getLightCoords(float partialTick) {
		return FULL_BRIGHT;
	}

	@Override
	public SingleQuadParticle.Layer getLayer() {
		return SingleQuadParticle.Layer.TRANSLUCENT;
	}

	public record TrillProvider(SpriteSet sprites) implements ParticleProvider<SimpleParticleType> {
		@Override
		public Particle createParticle(SimpleParticleType options, ClientLevel level, double x, double y, double z,
				double xAux, double yAux, double zAux, RandomSource random) {
			return new SiftMoteParticle(level, x, y, z, this.sprites.get(random), 0.004, 0.05F, 160);
		}
	}

	public record GlowPetalProvider(SpriteSet sprites) implements ParticleProvider<SimpleParticleType> {
		@Override
		public Particle createParticle(SimpleParticleType options, ClientLevel level, double x, double y, double z,
				double xAux, double yAux, double zAux, RandomSource random) {
			// A petal shed by music lifts off (yAux > 0); an ambient one sinks.
			return new SiftMoteParticle(level, x, y, z, this.sprites.get(random), yAux != 0.0 ? yAux : -0.008, 0.07F, yAux != 0.0 ? 60 : 220);
		}
	}
}
