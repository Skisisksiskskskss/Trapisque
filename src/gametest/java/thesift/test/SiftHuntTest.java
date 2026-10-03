package thesift.test;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.Vec3;

import thesift.entity.nester.Nester;
import thesift.entity.nester.NesterState;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;

/** The hunt (system_hunt.md) and the Nester (mob_nester.md), WP-066/067. */
public final class SiftHuntTest {
	private static final String SIFT = "thesift:the_sift";
	// Test environments (clock_time) set the Tide clock for their batch and restore it after, so tests
	// that need different Tides never run side by side.
	private static final String ENDURE = "thesift-gametest:endure";
	private static final String DAWN = "thesift-gametest:dawn";
	private static final String NEXT_THRIVE = "thesift-gametest:next_thrive";

	private static void floor(GameTestHelper helper) {
		for (int x = 0; x < 17; x++) {
			for (int z = 0; z < 17; z++) {
				helper.setBlock(new BlockPos(x, 0, z), ModBlocks.HEALTHY_SCULK);
			}
		}
	}

	private static Nester nester(GameTestHelper helper, double x, double z) {
		return helper.spawn(ModEntities.NESTER, new Vec3(x, 1, z));
	}

	/** A Nester as the world makes one: not persistent (helper.spawn marks its mobs persistent, and persistent hunters stay). */
	private static Nester wildNester(GameTestHelper helper, double x, double z) {
		Nester nester = ModEntities.NESTER.create(helper.getLevel(), EntitySpawnReason.COMMAND);
		nester.setPos(helper.absoluteVec(new Vec3(x, 1, z)));
		helper.getLevel().addFreshEntity(nester);
		return nester;
	}

	/** §3: the listener's radius is 16 in Endure... */
	@GameTest(dimension = SIFT, environment = ENDURE)
	public void nestersListenInEndure(GameTestHelper helper) {
		helper.setBlock(new BlockPos(1, 0, 1), ModBlocks.HEALTHY_SCULK);
		helper.assertTrue(nester(helper, 1.5, 1.5).getVibrationUser().getListenerRadius() == 16, "16 in Endure");
		helper.succeed();
	}

	/** ...and 0 in every other Tide, so it hears nothing and costs nothing then. */
	@GameTest(dimension = SIFT, environment = NEXT_THRIVE)
	public void nestersAreDeafOutsideEndure(GameTestHelper helper) {
		helper.setBlock(new BlockPos(1, 0, 1), ModBlocks.HEALTHY_SCULK);
		helper.assertTrue(nester(helper, 1.5, 1.5).getVibrationUser().getListenerRadius() == 0, "deaf in Thrive");
		helper.succeed();
	}

	/** §3: it gallops to where the sound was, not to whoever made it. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 300, environment = ENDURE)
	public void aNesterGoesToTheSound(GameTestHelper helper) {
		floor(helper);
		Nester nester = nester(helper, 2.5, 2.5);
		BlockPos sound = new BlockPos(13, 1, 13);
		helper.runAfterDelay(5, () -> helper.getLevel().gameEvent(GameEvent.BLOCK_PLACE, helper.absolutePos(sound),
				GameEvent.Context.of(ModBlocks.HEALTHY_SCULK.defaultBlockState())));
		helper.succeedWhen(() -> helper.assertTrue(nester.position().distanceTo(helper.absoluteVec(Vec3.atBottomCenterOf(sound))) < 3.0,
				"at the sound"));
	}

	/** §6: a sound inside lumen's radius brings it to the rim, never inside 6 blocks. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 300, environment = ENDURE)
	public void lumenKeepsItAtTheRim(GameTestHelper helper) {
		floor(helper);
		BlockPos lantern = new BlockPos(14, 1, 14);
		helper.setBlock(lantern, ModBlocks.LUMEN_LANTERN);
		Nester nester = nester(helper, 3.5, 3.5); // 13 blocks from the sound: within hearing
		Vec3 light = helper.absoluteVec(Vec3.atCenterOf(lantern));
		helper.runAfterDelay(5, () -> helper.getLevel().gameEvent(GameEvent.BLOCK_PLACE, helper.absolutePos(new BlockPos(13, 1, 13)),
				GameEvent.Context.of(ModBlocks.HEALTHY_SCULK.defaultBlockState())));
		double[] closest = {Double.MAX_VALUE};
		helper.onEachTick(() -> {
			double d = nester.position().distanceTo(light);
			helper.assertTrue(d > 5.5, "it stays out of the light");
			closest[0] = Math.min(closest[0], d);
		});
		helper.runAfterDelay(200, () -> {
			helper.assertTrue(closest[0] < 9.0, "it came to the rim (closest " + closest[0] + ")");
			helper.succeed();
		});
	}

	/** §7: on soil only, never within 8 of lumen. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG)
	public void spawnsOnSoilAwayFromLumen(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		floor(helper);
		helper.setBlock(new BlockPos(1, 0, 1), ModBlocks.HYMNSTONE);
		helper.setBlock(new BlockPos(14, 1, 14), ModBlocks.LUMEN_LANTERN);
		helper.assertTrue(Nester.checkNesterSpawnRules(ModEntities.NESTER, level, EntitySpawnReason.TRIAL_SPAWNER,
				helper.absolutePos(new BlockPos(3, 1, 3)), level.getRandom()), "on soil, away from lumen");
		helper.assertFalse(Nester.checkNesterSpawnRules(ModEntities.NESTER, level, EntitySpawnReason.TRIAL_SPAWNER,
				helper.absolutePos(new BlockPos(1, 1, 1)), level.getRandom()), "a stone floor is a safe floor");
		helper.assertFalse(Nester.checkNesterSpawnRules(ModEntities.NESTER, level, EntitySpawnReason.TRIAL_SPAWNER,
				helper.absolutePos(new BlockPos(10, 1, 12)), level.getRandom()), "none within 8 of lumen");
		helper.succeed();
	}

	/** §4: at its moment in falling Flow it digs into the soil and is gone. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 400, environment = DAWN) // past every moment (27 000-28 999); a check, a walk, a 60-tick dig
	public void nestersBurrowAtDawn(GameTestHelper helper) {
		floor(helper);
		wildNester(helper, 8.5, 8.5);
		helper.succeedWhen(() -> helper.assertTrue(helper.getEntities(ModEntities.NESTER).isEmpty(), "dug away"));
	}

	/** §4, §5: past its return-by in Thrive it's taken by the tide; a persistent enduring one stays, no longer enduring. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 100, environment = NEXT_THRIVE)
	public void theThriveSweep(GameTestHelper helper) {
		floor(helper);
		Nester gone = wildNester(helper, 4.5, 4.5);
		Nester kept = nester(helper, 12.5, 12.5);
		gone.setReturnBy(30_000);
		kept.setReturnBy(30_000);
		kept.setPersistenceRequired();
		kept.setEnduring(true);
		helper.succeedWhen(() -> {
			helper.assertFalse(gone.isAlive(), "the tide took it");
			helper.assertTrue(kept.isAlive(), "a name-tagged one stays");
			helper.assertFalse(kept.isEnduring(), "and stops enduring");
		});
	}

	/** §5: an enduring Nester has health 30, a bite of 6.25 (Normal), and gives 10 XP. */
	@GameTest(dimension = SIFT)
	public void enduringNumbers(GameTestHelper helper) {
		helper.setBlock(new BlockPos(1, 0, 1), ModBlocks.HEALTHY_SCULK);
		Nester nester = nester(helper, 1.5, 1.5);
		nester.setEnduring(true);
		helper.assertTrue(Math.abs(nester.getMaxHealth() - 30.0F) < 1.0E-4, "health 30");
		helper.assertTrue(Math.abs(nester.getAttributeValue(Attributes.ATTACK_DAMAGE) - 6.25) < 1.0E-4, "bite 6.25");
		nester.setEnduring(false);
		helper.assertTrue(Math.abs(nester.getMaxHealth() - 20.0F) < 1.0E-4, "back to 20");
		helper.succeed();
	}

	/** mob_nester.md, Dodge: with its guard up, the first melee hit from its target misses; the next lands. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG)
	public void theGuardDodgesOneHit(GameTestHelper helper) {
		floor(helper);
		Player player = helper.makeMockServerPlayer(GameType.SURVIVAL);
		player.setPos(helper.absoluteVec(new Vec3(8.5, 1, 6.5)));
		Nester nester = nester(helper, 8.5, 8.5);
		nester.guardAgainst(player);
		float health = nester.getHealth();
		ServerLevel level = helper.getLevel();
		helper.assertFalse(nester.hurtServer(level, level.damageSources().playerAttack(player), 4.0F), "the first hit is dodged");
		helper.assertTrue(nester.getHealth() == health, "no damage");
		helper.assertTrue(nester.state() == NesterState.DODGE, "it hops aside");
		helper.assertTrue(nester.hurtServer(level, level.damageSources().playerAttack(player), 4.0F), "the next lands");
		helper.succeed();
	}
}
