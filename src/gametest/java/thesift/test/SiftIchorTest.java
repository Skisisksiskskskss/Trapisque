package thesift.test;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.Difficulty;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.animal.pig.Pig;
import net.minecraft.world.entity.decoration.ArmorStand;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;

import thesift.fluid.IchorFluid;
import thesift.item.IchorBucketItem;
import thesift.registry.ModBlocks;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;
import thesift.test.mixin.EntityStuckAccessor;
import thesift.world.SoulPoints;

/** WP-044: ichor, a wade-through liquid (D-013, rules.md). */
public final class SiftIchorTest {
	private static final String SIFT = "thesift:the_sift";

	private static void pool(GameTestHelper helper, int y) {
		for (int x = 1; x <= 5; x++) {
			for (int z = 1; z <= 5; z++) {
				helper.setBlock(new BlockPos(x, y - 1, z), ModBlocks.HYMNSTONE);
				helper.setBlock(new BlockPos(x, y, z), ModBlocks.ICHOR);
			}
		}
	}

	private static ServerPlayer playerInIchor(GameTestHelper helper, int levels) {
		return playerInIchor(helper, levels, GameType.SURVIVAL);
	}

	private static ServerPlayer playerInIchor(GameTestHelper helper, int levels, GameType mode) {
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(mode);
		BlockPos at = helper.absolutePos(new BlockPos(3, 2, 3));
		player.setPos(at.getX() + 0.5, at.getY(), at.getZ() + 0.5);
		player.setExperienceLevels(levels);
		player.setExperiencePoints(0);
		return player;
	}

	/** Calls ichor's effects the way Entity#checkInsideBlocks does, on one game tick. */
	private static void standIn(GameTestHelper helper, net.minecraft.world.entity.Entity entity) {
		ServerLevel level = helper.getLevel();
		BlockPos pos = helper.absolutePos(new BlockPos(3, 2, 3));
		level.getFluidState(pos).entityInside(level, pos, entity, InsideBlockEffectApplier.NOOP);
	}

	/** Points drained per second at the server's difficulty (tests share the server, so never change it). */
	private static int perSecond(GameTestHelper helper) {
		return 20 / IchorFluid.drainInterval(helper.getLevel().getDifficulty());
	}

	@GameTest(dimension = SIFT, maxTicks = 100)
	public void ichorBurnsAPigThatWadesIn(GameTestHelper helper) {
		pool(helper, 2);
		Pig pig = helper.spawn(EntityTypes.PIG, new Vec3(3.5, 2, 3.5));
		// Through the real tick path (Entity#checkInsideBlocks); wading itself is checked below.
		helper.succeedWhen(() -> helper.assertTrue(pig.isOnFire(), "the pig burns"));
	}

	@GameTest(dimension = SIFT)
	public void wadingSlowsHorizontallyOnly(GameTestHelper helper) {
		pool(helper, 2);
		ServerPlayer player = playerInIchor(helper, 0);
		standIn(helper, player);
		helper.assertValueEqual(((EntityStuckAccessor) player).thesift$stuckSpeedMultiplier(), IchorFluid.WADE, "wading multiplier");
		helper.assertValueEqual(IchorFluid.WADE.y, 1.0, "climbing out stays possible");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void fireResistanceStopsTheBurnNotTheDrain(GameTestHelper helper) {
		pool(helper, 2);
		ServerPlayer player = playerInIchor(helper, 5);
		// Straight into the map: addEffect would send a packet, and mock players have no connection.
		player.getActiveEffectsMap().put(MobEffects.FIRE_RESISTANCE, new MobEffectInstance(MobEffects.FIRE_RESISTANCE, 600));
		int before = SoulPoints.total(player);
		long start = helper.getLevel().getGameTime();
		// Twenty game ticks of standing in ichor, simulated on the current tick's clock.
		for (int tick = 0; tick < 20; tick++) {
			IchorFluid.applySoulEffects(helper.getLevel(), player, start + tick); // one second of standing in ichor
		}
		helper.assertFalse(player.isOnFire(), "Fire Resistance stops the burning");
		helper.assertValueEqual(SoulPoints.total(player), before - perSecond(helper), "the drain goes on");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void outsidersBurnAndAreDrained(GameTestHelper helper) {
		pool(helper, 2);
		ServerPlayer player = playerInIchor(helper, 5);
		int before = SoulPoints.total(player);
		long start = helper.getLevel().getGameTime();
		for (int tick = 0; tick < 20; tick++) {
			IchorFluid.applySoulEffects(helper.getLevel(), player, start + tick);
		}
		helper.assertTrue(player.isOnFire(), "an outsider burns");
		helper.assertValueEqual(SoulPoints.total(player), before - perSecond(helper), "drained at the difficulty's rate");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void creativePlayersKeepTheirSouls(GameTestHelper helper) {
		pool(helper, 2);
		ServerPlayer player = playerInIchor(helper, 5, GameType.CREATIVE);
		int before = SoulPoints.total(player);
		long start = helper.getLevel().getGameTime();
		for (int tick = 0; tick < 40; tick++) {
			IchorFluid.applySoulEffects(helper.getLevel(), player, start + tick);
		}
		helper.assertValueEqual(SoulPoints.total(player), before, "no drain in creative");
		helper.succeed();
	}

	@GameTest(dimension = SIFT, maxTicks = 60)
	public void ichorHasNoCurrent(GameTestHelper helper) {
		for (int x = 0; x <= 6; x++) {
			for (int z = 2; z <= 4; z++) {
				helper.setBlock(new BlockPos(x, 1, z), ModBlocks.HYMNSTONE);
			}
		}
		helper.setBlock(new BlockPos(1, 2, 3), ModBlocks.ICHOR);
		ArmorStand stand = helper.spawn(EntityTypes.ARMOR_STAND, new Vec3(2.5, 2, 3.5));
		Vec3 start = stand.position();
		helper.runAfterDelay(50, () -> {
			helper.assertFalse(stand.isInWater() || stand.isInLava() || stand.isSwimming(), "ichor is not water or lava to an entity");
			helper.assertTrue(stand.position().distanceTo(start) < 0.05, "nothing pushed it: moved " + stand.position().distanceTo(start));
			helper.succeed();
		});
	}

	@GameTest(dimension = SIFT, maxTicks = 300)
	public void ichorFlowsThreeBlocks(GameTestHelper helper) {
		for (int x = 0; x <= 7; x++) {
			helper.setBlock(new BlockPos(x, 1, 3), ModBlocks.HYMNSTONE);
		}
		helper.setBlock(new BlockPos(0, 2, 3), ModBlocks.ICHOR);
		helper.succeedWhen(() -> {
			helper.assertTrue(helper.getLevel().getFluidState(helper.absolutePos(new BlockPos(3, 2, 3))).getType() == ModFluids.FLOWING_ICHOR,
					"ichor reaches three blocks out");
			helper.assertTrue(helper.getLevel().getFluidState(helper.absolutePos(new BlockPos(4, 2, 3))).isEmpty(), "and no further");
		});
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

	@GameTest
	public void drainRatesByDifficulty(GameTestHelper helper) {
		helper.assertValueEqual(IchorFluid.drainInterval(Difficulty.EASY), 20, "Easy: 1 point a second");
		helper.assertValueEqual(IchorFluid.drainInterval(Difficulty.NORMAL), 10, "Normal: 2 points a second");
		helper.assertValueEqual(IchorFluid.drainInterval(Difficulty.HARD), 5, "Hard: 4 points a second");
		helper.succeed();
	}
}
