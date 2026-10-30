package thesift.world.feature;

import com.mojang.serialization.Codec;
import com.mojang.serialization.MapCodec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.Registry;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.block.HangingMossBlock;
import net.minecraft.world.level.levelgen.feature.treedecorators.TreeDecorator;
import net.minecraft.world.level.levelgen.feature.treedecorators.TreeDecoratorType;

import thesift.TheSift;
import thesift.registry.ModBlocks;

/**
 * Songwood drapes hanging from the bottom of a canopy (owner rework, after the teaser's drooping
 * trees and canon's "towering tree-like growths covered in pale-blue vines"): from each leaf with air
 * below, by chance, a strand one to four blocks long.
 */
public final class DrapesDecorator extends TreeDecorator {
	public static final MapCodec<DrapesDecorator> CODEC = Codec.floatRange(0.0F, 1.0F).fieldOf("probability")
			.xmap(DrapesDecorator::new, d -> d.probability);
	public static final TreeDecoratorType<DrapesDecorator> TYPE = Registry.register(BuiltInRegistries.TREE_DECORATOR_TYPE,
			TheSift.id("songwood_drapes"), new TreeDecoratorType<>(CODEC));

	private final float probability;

	public DrapesDecorator(float probability) {
		this.probability = probability;
	}

	@Override
	protected TreeDecoratorType<?> type() {
		return TYPE;
	}

	@Override
	public void place(TreeDecorator.Context context) {
		RandomSource random = context.random();
		for (BlockPos leaf : context.leaves()) {
			BlockPos below = leaf.below();
			if (random.nextFloat() >= this.probability || !context.isAir(below)) {
				continue;
			}
			int length = 1 + random.nextInt(4);
			int placed = 0;
			while (placed < length && context.isAir(below.below(placed))) {
				placed++;
			}
			for (int i = 0; i < placed; i++) {
				context.setBlock(below.below(i), ModBlocks.SONGWOOD_DRAPES.defaultBlockState().setValue(HangingMossBlock.TIP, i == placed - 1));
			}
		}
	}

	/** Class loading registers the type. */
	public static void init() {
	}
}
