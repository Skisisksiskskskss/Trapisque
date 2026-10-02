package thesift.test;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.tags.FluidTags;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.animal.pig.Pig;
import net.minecraft.world.entity.decoration.ArmorStand;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;

import thesift.item.IchorBucketItem;
import thesift.registry.ModBlocks;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;

/** Ichor, the Sift's water (D-024): clear, swimmable, and it flows as water does. */
public final class SiftIchorTest {
	private static final String SIFT = "thesift:the_sift";

	/** A 5 × 5 pool, two deep, on hymnstone. */
	private static void pool(GameTestHelper helper) {
		for (int x = 1; x <= 5; x++) {
			for (int z = 1; z <= 5; z++) {
				helper.setBlock(new BlockPos(x, 1, z), ModBlocks.HYMNSTONE);
				helper.setBlock(new BlockPos(x, 2, z), ModBlocks.ICHOR);
				helper.setBlock(new BlockPos(x, 3, z), ModBlocks.ICHOR);
			}
		}
	}

	@GameTest(dimension = SIFT)
	public void ichorIsWater(GameTestHelper helper) {
		helper.assertTrue(ModFluids.ICHOR.defaultFluidState().is(FluidTags.WATER), "ichor is in #minecraft:water");
		helper.assertTrue(ModFluids.FLOWING_ICHOR.defaultFluidState().is(FluidTags.WATER), "flowing ichor too");
		helper.succeed();
	}

	@GameTest(dimension = SIFT, maxTicks = 100)
	public void aPigSwimsInIchorAndDoesNotBurn(GameTestHelper helper) {
		pool(helper);
		Pig pig = helper.spawn(EntityTypes.PIG, new Vec3(3.5, 2, 3.5));
		helper.runAfterDelay(40, () -> {
			helper.assertTrue(pig.isInWater(), "a pig in ichor is in water");
			helper.assertFalse(pig.isOnFire(), "and nothing sets it alight");
			helper.assertTrue(pig.getHealth() >= pig.getMaxHealth(), "nor hurts it");
			helper.succeed();
		});
	}

	@GameTest(dimension = SIFT, maxTicks = 100)
	public void ichorPutsOutFire(GameTestHelper helper) {
		pool(helper);
		Pig pig = helper.spawn(EntityTypes.PIG, new Vec3(3.5, 2, 3.5));
		pig.igniteForSeconds(8.0F);
		helper.runAfterDelay(10, () -> {
			helper.assertFalse(pig.isOnFire(), "a burning pig that walks into ichor is put out");
			helper.succeed();
		});
	}

	@GameTest(dimension = SIFT, maxTicks = 100)
	public void ichorHasACurrent(GameTestHelper helper) {
		for (int x = 0; x <= 6; x++) {
			for (int z = 2; z <= 4; z++) {
				helper.setBlock(new BlockPos(x, 1, z), ModBlocks.HYMNSTONE);
			}
		}
		helper.setBlock(new BlockPos(1, 2, 3), ModBlocks.ICHOR);
		ArmorStand stand = helper.spawn(EntityTypes.ARMOR_STAND, new Vec3(2.5, 2, 3.5));
		Vec3 start = stand.position();
		helper.succeedWhen(() -> helper.assertTrue(stand.position().distanceTo(start) > 0.1,
				"flowing ichor carries things along, as water does: moved " + stand.position().distanceTo(start)));
	}

	@GameTest(dimension = SIFT, maxTicks = 300)
	public void ichorFlowsSevenBlocks(GameTestHelper helper) {
		for (int x = 0; x <= 9; x++) {
			helper.setBlock(new BlockPos(x, 1, 3), ModBlocks.HYMNSTONE);
		}
		helper.setBlock(new BlockPos(0, 2, 3), ModBlocks.ICHOR);
		helper.succeedWhen(() -> {
			helper.assertTrue(helper.getLevel().getFluidState(helper.absolutePos(new BlockPos(7, 2, 3))).getType() == ModFluids.FLOWING_ICHOR,
					"ichor reaches seven blocks out, as water does");
			helper.assertTrue(helper.getLevel().getFluidState(helper.absolutePos(new BlockPos(8, 2, 3))).isEmpty(), "and no further");
		});
	}

	@GameTest(dimension = SIFT, maxTicks = 100)
	public void twoSourcesMakeAThird(GameTestHelper helper) {
		for (int x = 0; x <= 4; x++) {
			for (int z = 0; z <= 2; z++) {
				helper.setBlock(new BlockPos(x, 1, z), ModBlocks.HYMNSTONE);
				helper.setBlock(new BlockPos(x, 2, z), z == 1 && x >= 1 && x <= 3 ? Blocks.AIR : ModBlocks.HYMNSTONE);
			}
		}
		helper.setBlock(new BlockPos(1, 2, 1), ModBlocks.ICHOR);
		helper.setBlock(new BlockPos(3, 2, 1), ModBlocks.ICHOR);
		helper.succeedWhen(() -> helper.assertTrue(helper.getLevel().getFluidState(helper.absolutePos(new BlockPos(2, 2, 1))).isSource(),
				"between two sources ichor renews itself, as water does"));
	}

	@GameTest
	public void aBucketOfIchorEvaporatesInTheOverworld(GameTestHelper helper) {
		BlockPos pos = new BlockPos(2, 2, 2);
		helper.setBlock(pos.below(), Blocks.STONE);
		IchorBucketItem bucket = (IchorBucketItem) ModItems.ICHOR_BUCKET;
		helper.assertTrue(bucket.emptyContents(null, helper.getLevel(), helper.absolutePos(pos), null), "the bucket empties");
		helper.assertBlockPresent(Blocks.AIR, pos);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void aBucketOfIchorPoursInTheSift(GameTestHelper helper) {
		BlockPos pos = new BlockPos(2, 2, 2);
		helper.setBlock(pos.below(), ModBlocks.HYMNSTONE);
		IchorBucketItem bucket = (IchorBucketItem) ModItems.ICHOR_BUCKET;
		helper.assertTrue(bucket.emptyContents(null, helper.getLevel(), helper.absolutePos(pos), null), "the bucket empties");
		helper.assertBlockPresent(ModBlocks.ICHOR, pos);
		helper.succeed();
	}
}
