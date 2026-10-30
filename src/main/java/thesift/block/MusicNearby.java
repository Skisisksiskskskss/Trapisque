package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;

import thesift.registry.ModParticles;

/**
 * The bridge for music reactions (world.md §3.2): our blocks' {@code animateTick} (client side
 * only) asks whether music played near them lately; the client's sound listener answers. On a
 * dedicated server nothing ever asks, and the answer stays "no".
 */
public final class MusicNearby {
	public interface Query {
		boolean near(BlockPos pos);
	}

	private static Query query = pos -> false;

	private MusicNearby() {
	}

	public static void set(Query newQuery) {
		query = newQuery;
	}

	public static boolean near(BlockPos pos) {
		return query.near(pos);
	}

	/** Healthy sculk and its grass shed a glowing petal that lifts off while music plays near. */
	public static void shedPetals(Level level, BlockPos pos, RandomSource random, double height) {
		if (random.nextInt(4) == 0 && near(pos)) {
			level.addParticle(ModParticles.GLOW_PETAL, pos.getX() + random.nextDouble(), pos.getY() + height,
					pos.getZ() + random.nextDouble(), 0.0, 0.015, 0.0);
		}
	}
}
