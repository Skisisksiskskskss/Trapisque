package thesift.test;

import java.util.List;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.BonemealSource;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;

import thesift.block.HealthySculkGrassBlock;
import thesift.block.SongwoodSaplingBlock;
import thesift.registry.ModBlocks;

/** WP-042: behaviour of block set I (world.md §3–4). */
public final class SiftBlocksTest {
	private static final String SIFT = "thesift:the_sift";
	private static final BlockPos GROUND = new BlockPos(1, 1, 1);
	private static final BlockPos ON_GROUND = GROUND.above();

	@GameTest(dimension = SIFT)
	public void coveredHealthySculkDiesBackToHymnstone(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.setBlock(ON_GROUND, Blocks.STONE);
		ServerLevel level = helper.getLevel();
		BlockPos pos = helper.absolutePos(GROUND);
		level.getBlockState(pos).randomTick(level, pos, level.getRandom());
		helper.assertBlockPresent(ModBlocks.HYMNSTONE, GROUND);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void openHealthySculkStaysAlive(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		ServerLevel level = helper.getLevel();
		BlockPos pos = helper.absolutePos(GROUND);
		level.getBlockState(pos).randomTick(level, pos, level.getRandom());
		helper.assertBlockPresent(ModBlocks.HEALTHY_SCULK, GROUND);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void healthySculkDropsHymnstoneWithoutSilkTouch(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		BlockPos pos = helper.absolutePos(GROUND);
		List<ItemStack> drops = Block.getDrops(helper.getLevel().getBlockState(pos), helper.getLevel(), pos, null);
		helper.assertTrue(drops.size() == 1 && drops.getFirst().is(ModBlocks.HYMNSTONE.asItem()), "drops " + drops);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void grassNeedsSiftGround(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockState grass = ModBlocks.HEALTHY_SCULK_GRASS.defaultBlockState();
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.assertTrue(grass.canSurvive(level, helper.absolutePos(ON_GROUND)), "grass survives on healthy sculk");
		helper.setBlock(GROUND, ModBlocks.HYMNSTONE);
		helper.assertFalse(grass.canSurvive(level, helper.absolutePos(ON_GROUND)), "grass can't stand on bare hymnstone");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void boneMealGrowsTallGrassInTheSift(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.setBlock(ON_GROUND, ModBlocks.HEALTHY_SCULK_GRASS);
		BlockPos pos = helper.absolutePos(ON_GROUND);
		HealthySculkGrassBlock block = (HealthySculkGrassBlock) ModBlocks.HEALTHY_SCULK_GRASS;
		helper.assertTrue(block.isValidBonemealTarget(level, pos, level.getBlockState(pos), BonemealSource.INTERACTION), "bone meal works in the Sift");
		block.performBonemeal(level, level.getRandom(), pos, level.getBlockState(pos), BonemealSource.INTERACTION);
		helper.assertBlockPresent(ModBlocks.TALL_HEALTHY_SCULK_GRASS, ON_GROUND);
		helper.succeed();
	}

	@GameTest
	public void siftPlantsDontGrowInTheOverworld(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.setBlock(ON_GROUND, ModBlocks.HEALTHY_SCULK_GRASS);
		BlockPos pos = helper.absolutePos(ON_GROUND);
		helper.assertFalse(((HealthySculkGrassBlock) ModBlocks.HEALTHY_SCULK_GRASS)
				.isValidBonemealTarget(level, pos, level.getBlockState(pos), BonemealSource.INTERACTION), "no bone meal on Sift grass at home");
		helper.setBlock(ON_GROUND, ModBlocks.SONGWOOD_SAPLING);
		helper.assertFalse(((SongwoodSaplingBlock) ModBlocks.SONGWOOD_SAPLING)
				.isValidBonemealTarget(level, pos, level.getBlockState(pos), BonemealSource.INTERACTION), "no bone meal on a songwood sapling at home");
		for (int i = 0; i < 50; i++) {
			level.getBlockState(pos).randomTick(level, pos, level.getRandom());
		}
		helper.assertBlockPresent(ModBlocks.SONGWOOD_SAPLING, ON_GROUND);
		helper.succeed();
	}

	@GameTest(dimension = SIFT, skyAccess = true)
	public void songwoodSaplingGrowsATreeInTheSift(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		// The trunk needs a clear 5×5 column (TwoLayersFeatureSize), so plant it in the middle of the test area.
		BlockPos centre = new BlockPos(4, 2, 4);
		helper.setBlock(centre.below(), ModBlocks.HEALTHY_SCULK);
		helper.setBlock(centre, ModBlocks.SONGWOOD_SAPLING);
		BlockPos pos = helper.absolutePos(centre);
		SongwoodSaplingBlock sapling = (SongwoodSaplingBlock) ModBlocks.SONGWOOD_SAPLING;
		for (int i = 0; i < 10 && level.getBlockState(pos).is(ModBlocks.SONGWOOD_SAPLING); i++) {
			sapling.advanceTree(level, pos, level.getBlockState(pos), level.getRandom());
		}
		helper.assertBlockPresent(ModBlocks.SONGWOOD_LOG, centre);
		helper.succeed();
	}
}
