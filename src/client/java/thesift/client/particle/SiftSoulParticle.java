package thesift.client.particle;

import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.particle.Particle;
import net.minecraft.client.particle.ParticleProvider;
import net.minecraft.client.particle.SingleQuadParticle;
import net.minecraft.client.particle.SpriteSet;
import net.minecraft.core.particles.SimpleParticleType;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;

/**
 * The Sift's soul (owner playtest 6: never vanilla's soul particle): a little pale-blue wailing ghost,
 * as Dungeons II draws its souls. It gathers, forms and waves its wisps while it drifts on the motion
 * it was sent with (slowing as vanilla's souls do, so cues that aim it still land), then rises and
 * dissolves. Full bright and translucent.
 */
public class SiftSoulParticle extends SingleQuadParticle {
	private static final int FULL_BRIGHT = 0xF000F0;
	private static final int LAST_FRAME = 5;
	private final SpriteSet sprites;
	private final float phase;

	protected SiftSoulParticle(ClientLevel level, double x, double y, double z, double xd, double yd, double zd, SpriteSet sprites) {
		super(level, x, y, z, sprites.get(0, LAST_FRAME));
		this.sprites = sprites;
		this.xd = xd + (this.random.nextFloat() - 0.5F) * 0.01F;
		this.yd = yd + 0.01F + this.random.nextFloat() * 0.01F;
		this.zd = zd + (this.random.nextFloat() - 0.5F) * 0.01F;
		this.friction = 0.96F;
		this.gravity = 0.0F;
		this.hasPhysics = false;
		this.lifetime = 28 + this.random.nextInt(16);
		this.quadSize = 0.15F * (0.85F + this.random.nextFloat() * 0.3F);
		this.phase = this.random.nextFloat() * Mth.TWO_PI;
		this.alpha = 0.0F;
	}

	@Override
	public void tick() {
		super.tick();
		// Gathers (frames 0, 1), waves its wisps (2 and 3 by turns), rises and dissolves (4, 5).
		int left = this.lifetime - this.age;
		int frame = this.age < 3 ? 0 : this.age < 6 ? 1 : left <= 3 ? 5 : left <= 8 ? 4 : 2 + (this.age / 5) % 2;
		this.setSprite(this.sprites.get(frame, LAST_FRAME));
		this.xd += Mth.sin(this.age * 0.25F + this.phase) * 0.0015F;
		this.zd += Mth.cos(this.age * 0.21F + this.phase) * 0.0015F;
		this.yd += 0.0012F;
		this.alpha = Mth.clamp(Math.min(this.age / 3.0F, left / 4.0F), 0.0F, 1.0F) * 0.95F;
	}

	@Override
	protected int getLightCoords(float partialTick) {
		return FULL_BRIGHT;
	}

	@Override
	public SingleQuadParticle.Layer getLayer() {
		return SingleQuadParticle.Layer.TRANSLUCENT;
	}

	public record Provider(SpriteSet sprites) implements ParticleProvider<SimpleParticleType> {
		@Override
		public Particle createParticle(SimpleParticleType options, ClientLevel level, double x, double y, double z,
				double xAux, double yAux, double zAux, RandomSource random) {
			return new SiftSoulParticle(level, x, y, z, xAux, yAux, zAux, this.sprites);
		}
	}
}
