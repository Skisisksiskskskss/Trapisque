package thesift.test;

import java.util.List;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.entity.rift.RiftEntity;
import thesift.entry.Rifts;
import thesift.registry.ModGameRules;
import thesift.registry.ModItems;
import thesift.world.SiftKeys;

/** WP-082: rifts between the Overworld and the Sift, and the rift fork (survival_sift.md §2). */
public final class SiftRiftTest {
	private static final String SIFT = "thesift:the_sift";

	/** Footing to stand on and two free cells (survival_sift.md §2.1). */
	private static void assertSafe(GameTestHelper helper, ServerLevel level, BlockPos feet) {
		helper.assertTrue(level.getBlockState(feet.below()).isFaceSturdy(level, feet.below(), Direction.UP)
				|| SiftKeys.isSift(level) && !level.getFluidState(feet).isEmpty(), "footing under " + feet + " in " + level.dimension().identifier());
		for (BlockPos cell : new BlockPos[] {feet, feet.above()}) {
			helper.assertTrue(level.getBlockState(cell).getCollisionShape(level, cell).isEmpty(), "free cell " + cell);
		}
		if (!SiftKeys.isSift(level)) {
			helper.assertTrue(level.getFluidState(feet).isEmpty() && level.getFluidState(feet.below()).isEmpty(), "no water or lava at " + feet);
		}
	}

	@GameTest(dimension = SIFT)
	public void aRiftInTheSiftLeadsToSafeGroundInTheOverworld(GameTestHelper helper) {
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		Vec3 at = helper.absoluteVec(new Vec3(1.5, 1, 1.5));
		player.setPos(at.x, at.y, at.z);
		TeleportTransition to = Rifts.destination(helper.getLevel(), player);
		helper.assertTrue(to != null && to.newLevel().dimension() == Level.OVERWORLD, "a Sift rift leads to the Overworld");
		helper.assertTrue(Math.abs(to.position().x - at.x) <= Rifts.LANDING_SEARCH + 1 && Math.abs(to.position().z - at.z) <= Rifts.LANDING_SEARCH + 1,
				"near the same x and z: " + to.position());
		assertSafe(helper, to.newLevel(), BlockPos.containing(to.position()));
		helper.succeed();
	}

	@GameTest
	public void aRiftInTheOverworldLeadsToSafeGroundInTheSift(GameTestHelper helper) {
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		Vec3 at = helper.absoluteVec(new Vec3(1.5, 1, 1.5));
		player.setPos(at.x, at.y, at.z);
		TeleportTransition to = Rifts.destination(helper.getLevel(), player);
		helper.assertTrue(to != null && SiftKeys.isSift(to.newLevel()), "an Overworld rift leads to the Sift");
		assertSafe(helper, to.newLevel(), BlockPos.containing(to.position()));
		helper.succeed();
	}

	@GameTest(dimension = SIFT, maxTicks = 60)
	public void aRiftClosesWhenItsTimeRunsOut(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		Vec3 at = helper.absoluteVec(new Vec3(1.5, 1, 1.5));
		Rifts.open(level, at, 10);
		AABB around = new AABB(at, at).inflate(3);
		helper.assertTrue(level.getEntitiesOfClass(RiftEntity.class, around).size() == 1, "the rift opened");
		helper.runAfterDelay(20, () -> {
			helper.assertTrue(level.getEntitiesOfClass(RiftEntity.class, around).isEmpty(), "the rift closed after 10 ticks");
			helper.succeed();
		});
	}

	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG)
	public void theRiftForkOpensARiftAhead(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		for (int x = 2; x <= 7; x++) {
			for (int z = 2; z <= 9; z++) {
				helper.setBlock(new BlockPos(x, 0, z), Blocks.STONE);
			}
		}
		ServerPlayer player = helper.makeMockServerPlayerInLevel(); // the cooldown is sent to the player's connection
		Vec3 at = helper.absoluteVec(new Vec3(4.5, 1, 4.5));
		player.teleport(new TeleportTransition(level, at, Vec3.ZERO, 0.0F, 0.0F, TeleportTransition.DO_NOTHING)); // facing south (+z)
		ItemStack fork = new ItemStack(ModItems.RIFT_FORK);
		player.setItemInHand(InteractionHand.MAIN_HAND, fork);
		fork.getItem().use(level, player, InteractionHand.MAIN_HAND);
		List<RiftEntity> rifts = level.getEntitiesOfClass(RiftEntity.class, new AABB(at, at).inflate(5));
		helper.assertTrue(rifts.size() == 1, "one rift opened: " + rifts.size());
		RiftEntity rift = rifts.getFirst();
		helper.assertTrue(rift.getZ() > at.z + 2.0, "it opened ahead of the player: " + rift.position());
		helper.assertValueEqual(rift.closesAt() - rift.openedAt(), (long) RiftEntity.FORK_LIFE, "a fork rift's lifetime");
		helper.assertValueEqual(fork.getDamageValue(), player.hasInfiniteMaterials() ? 0 : 1, "one use spent (none in creative, as any tool)");
		helper.assertTrue(player.getCooldowns().isOnCooldown(fork), "the fork cools down");
		rift.discard();
		level.getServer().getPlayerList().remove(player);
		helper.succeed();
	}

	@GameTest
	public void riftGameRulesDefaults(GameTestHelper helper) {
		helper.assertTrue(helper.getLevel().getGameRules().get(ModGameRules.SPAWN_RIFTS), "natural rifts on by default");
		helper.assertFalse(helper.getLevel().getGameRules().get(ModGameRules.START_IN_SIFT), "the Sift start off by default");
		helper.succeed();
	}

	/** The whole crossing: a player standing in an open rift in the Sift arrives in the Overworld, and the rift will close soon. */
	@GameTest(dimension = SIFT, maxTicks = 100)
	public void walkingIntoARiftCarriesThePlayerThrough(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		ServerPlayer player = helper.makeMockServerPlayerInLevel();
		Vec3 at = helper.absoluteVec(new Vec3(1.5, 1, 1.5));
		player.teleport(new TeleportTransition(level, at, Vec3.ZERO, 0.0F, 0.0F, TeleportTransition.DO_NOTHING));
		RiftEntity rift = Rifts.open(level, at, RiftEntity.NATURAL_LIFE);
		rift.open(level.getGameTime() - RiftEntity.OPENING, RiftEntity.NATURAL_LIFE); // already open
		helper.onEachTick(() -> {
			if (player.level().dimension() == Level.OVERWORLD) {
				helper.assertTrue(rift.closesAt() <= level.getGameTime() + RiftEntity.FOLLOW, "it closes 10 s after the first crossing");
				assertSafe(helper, player.level(), player.blockPosition());
				level.getServer().getPlayerList().remove(player);
				rift.discard();
				helper.succeed();
			}
		});
	}
}
