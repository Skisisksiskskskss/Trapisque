package thesift.test;

import java.util.List;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.enchantment.Enchantments;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;

import thesift.block.TideFloraBlock;
import thesift.block.TidewrackBlock;
import thesift.entity.blub.Blub;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModFluids;
import thesift.registry.ModItems;
import thesift.world.Tide;
import thesift.world.TideClock;

/** WP-064: the M2 flora's rules (block_flora_ii.md). */
public final class SiftFloraTest {
	private static final String SIFT = "thesift:the_sift";
	private static final BlockPos GROUND = new BlockPos(1, 1, 1);
	private static final BlockPos PLANT = GROUND.above();

	private static void setTide(GameTestHelper helper, Tide tide) {
		MinecraftServer server = helper.getLevel().getServer();
		server.clockManager().setTotalTicks(TideClock.clock(server), tide.startTick() + 10);
	}

	@GameTest(dimension = SIFT)
	public void tidewrackPickedOnceInThrive(GameTestHelper helper) {
		setTide(helper, Tide.THRIVE);
		helper.setBlock(GROUND, ModBlocks.TIDE_SAND);
		helper.setBlock(PLANT, ModBlocks.TIDEWRACK.defaultBlockState().setValue(TideFloraBlock.OPEN, true));
		helper.useBlock(PLANT, helper.makeMockPlayer(GameType.SURVIVAL));
		helper.assertItemEntityPresent(ModItems.TIDEWRACK_FROND, PLANT, 2.0);
		BlockState picked = helper.getBlockState(PLANT);
		helper.assertTrue(TideFloraBlock.isPicked(picked, helper.getLevel()), "picked this cycle");
		helper.assertFalse(((TideFloraBlock) picked.getBlock()).isReady(picked, helper.getLevel()), "a second pick yields nothing");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void outOfWindowUseClosesWithoutYield(GameTestHelper helper) {
		setTide(helper, Tide.THRIVE);
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.setBlock(PLANT, ModBlocks.ENDURE_BLOOM.defaultBlockState().setValue(TideFloraBlock.OPEN, true));
		helper.useBlock(PLANT, helper.makeMockPlayer(GameType.SURVIVAL));
		helper.assertBlockProperty(PLANT, TideFloraBlock.OPEN, false);
		helper.assertItemEntityNotPresent(ModItems.ENDURE_PETAL, PLANT, 2.0);
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void endureBloomYieldsInEndure(GameTestHelper helper) {
		setTide(helper, Tide.ENDURE);
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.setBlock(PLANT, ModBlocks.ENDURE_BLOOM.defaultBlockState().setValue(TideFloraBlock.OPEN, true));
		helper.useBlock(PLANT, helper.makeMockPlayer(GameType.SURVIVAL));
		helper.assertItemEntityPresent(ModItems.ENDURE_PETAL, PLANT, 2.0);
		setTide(helper, Tide.THRIVE);
		helper.succeed();
	}

	/** D-027: no tool gives a tide plant or the lumen bloom, Silk Touch included. */
	@GameTest(dimension = SIFT)
	public void wildPlantsNeverDropThemselves(GameTestHelper helper) {
		setTide(helper, Tide.THRIVE);
		ServerLevel level = helper.getLevel();
		ItemStack silk = new ItemStack(Items.DIAMOND_PICKAXE);
		silk.enchant(level.registryAccess().lookupOrThrow(Registries.ENCHANTMENT).getOrThrow(Enchantments.SILK_TOUCH), 1);
		for (Block block : List.of(ModBlocks.TIDEWRACK, ModBlocks.ENDURE_BLOOM, ModBlocks.LUMEN_BLOOM)) {
			for (ItemStack tool : List.of(silk, new ItemStack(Items.SHEARS))) {
				BlockPos pos = helper.absolutePos(PLANT);
				List<ItemStack> drops = Block.getDrops(block.defaultBlockState(), level, pos, null, null, tool);
				helper.assertTrue(drops.stream().noneMatch(s -> s.is(block.asItem())), block + " dropped itself: " + drops);
			}
		}
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void tidewrackHoldsIchorSourceOnly(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.TIDE_SAND);
		helper.setBlock(PLANT, ModBlocks.TIDEWRACK);
		BlockPos pos = helper.absolutePos(PLANT);
		BlockState dry = helper.getBlockState(PLANT);
		TidewrackBlock wrack = (TidewrackBlock) dry.getBlock();
		helper.assertFalse(wrack.canPlaceLiquid(null, helper.getLevel(), pos, dry, ModFluids.FLOWING_ICHOR), "flowing ichor stays out");
		helper.assertTrue(wrack.placeLiquid(helper.getLevel(), pos, dry, ModFluids.ICHOR.getSource(false)), "an ichor source goes in");
		helper.assertBlockProperty(PLANT, TidewrackBlock.SUBMERGED, true);
		helper.assertTrue(helper.getLevel().getFluidState(pos).is(ModFluids.ICHOR), "it holds ichor");
		helper.succeed();
	}

	@GameTest(dimension = SIFT)
	public void lightsAndLumen(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		helper.setBlock(PLANT, ModBlocks.LUMEN_BLOOM);
		helper.assertTrue(ModBlocks.GLOWCAP.defaultBlockState().getLightEmission() == 10, "glowcap light 10");
		helper.assertTrue(helper.getBlockState(PLANT).getLightEmission() == 12, "lumen bloom light 12");
		helper.assertTrue(ModBlocks.ENDURE_BLOOM.defaultBlockState().setValue(TideFloraBlock.OPEN, true).getLightEmission() == 0,
				"an open Endure bloom gives no block light");
		helper.assertTrue(helper.getLevel().getPoiManager().getType(helper.absolutePos(PLANT)).isPresent(), "lumen is a POI");
		helper.succeed();
	}

	/** items_m2.md: the lumen lantern is a lantern (light 15) whose light is lumen. */
	@GameTest(dimension = SIFT)
	public void lumenLanternIsLumen(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.HYMNSTONE);
		helper.setBlock(PLANT, ModBlocks.LUMEN_LANTERN);
		helper.assertTrue(helper.getBlockState(PLANT).getLightEmission() == 15, "lantern light 15");
		helper.assertTrue(helper.getLevel().getPoiManager().getType(helper.absolutePos(PLANT)).isPresent(), "the lantern is lumen");
		helper.succeed();
	}

	/** items_m2.md: a frond heals a befriended blub by 4 for its owner; a wild blub won't eat. */
	@GameTest(dimension = SIFT)
	public void frondTreatsBefriendedBlubsOnly(GameTestHelper helper) {
		helper.setBlock(GROUND, ModBlocks.HEALTHY_SCULK);
		Player player = helper.makeMockPlayer(GameType.SURVIVAL);
		Blub wild = helper.spawn(ModEntities.BLUB, new Vec3(1.5, 2, 1.5));
		Blub friend = helper.spawn(ModEntities.BLUB, new Vec3(3.5, 2, 1.5));
		friend.tame(player);
		friend.setHealth(2.0F);
		wild.setHealth(2.0F);
		player.setItemInHand(InteractionHand.MAIN_HAND, new ItemStack(ModItems.TIDEWRACK_FROND, 2));
		helper.assertTrue(wild.mobInteract(player, InteractionHand.MAIN_HAND) == InteractionResult.PASS, "a wild blub won't eat");
		friend.mobInteract(player, InteractionHand.MAIN_HAND);
		helper.assertTrue(friend.getHealth() == 6.0F, "the treat heals 4");
		helper.assertTrue(player.getMainHandItem().getCount() == 1, "one frond eaten");
		helper.assertTrue(wild.getHealth() == 2.0F, "the wild blub is unhealed");
		helper.succeed();
	}

	/** items_m2.md: two befriended blubs in love make a baby blub, befriended to their owner. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 300)
	public void blubsBreedAnOwnedBaby(GameTestHelper helper) {
		setTide(helper, Tide.THRIVE);
		for (int x = 0; x < 5; x++) {
			for (int z = 0; z < 5; z++) {
				helper.setBlock(new BlockPos(x, 0, z), ModBlocks.HEALTHY_SCULK);
			}
		}
		// A real (mock server) owner in the level: a tamed mob whose owner is offline sits, as vanilla's.
		Player player = helper.makeMockServerPlayer(GameType.SURVIVAL);
		player.setPos(helper.absoluteVec(new Vec3(2.5, 1, 3.5)));
		Blub a = helper.spawn(ModEntities.BLUB, new Vec3(1.5, 1, 1.5));
		Blub b = helper.spawn(ModEntities.BLUB, new Vec3(3.5, 1, 1.5));
		for (Blub blub : List.of(a, b)) {
			blub.tame(player);
			blub.setInLove(player);
		}
		helper.succeedWhen(() -> {
			List<Blub> babies = helper.getEntities(ModEntities.BLUB).stream().filter(Blub::isBaby).toList();
			helper.assertTrue(babies.size() == 1, "one baby");
			helper.assertTrue(babies.getFirst().isOwnedBy(player), "the baby is the owner's");
		});
	}

	/** D-029: the ichor lily floats on an ichor source only, and glows (light 9). */
	@GameTest(dimension = SIFT)
	public void ichorLilyFloatsOnIchorOnly(GameTestHelper helper) {
		helper.setBlock(GROUND, ModFluids.ICHOR.getSource(false).createLegacyBlock());
		helper.assertTrue(ModBlocks.ICHOR_LILY.defaultBlockState().canSurvive(helper.getLevel(), helper.absolutePos(PLANT)), "floats on ichor");
		helper.setBlock(GROUND, Blocks.WATER);
		helper.assertFalse(ModBlocks.ICHOR_LILY.defaultBlockState().canSurvive(helper.getLevel(), helper.absolutePos(PLANT)), "not on water");
		helper.assertTrue(ModBlocks.ICHOR_LILY.defaultBlockState().getLightEmission() == 9, "light 9");
		helper.succeed();
	}

	/** D-029: a frond in its owner's hand within 8 blocks makes a befriended blub beg. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 100)
	public void blubBegsForAFrond(GameTestHelper helper) {
		floor(helper);
		Player owner = helper.makeMockServerPlayer(GameType.SURVIVAL);
		owner.setPos(helper.absoluteVec(new Vec3(8.5, 1, 4.5)));
		Blub blub = helper.spawn(ModEntities.BLUB, new Vec3(8.5, 1, 8.5));
		blub.tame(owner);
		owner.setItemInHand(InteractionHand.MAIN_HAND, new ItemStack(ModItems.TIDEWRACK_FROND));
		helper.succeedWhen(() -> helper.assertTrue(blub.isInterested(), "begging"));
	}

	/** D-029: in Thrive a befriended blub picks ready tidewrack and drops the frond at its owner's feet. */
	@GameTest(dimension = SIFT, structure = SiftBasinTest.BIG, maxTicks = 900)
	public void blubForagesAFrondForItsOwner(GameTestHelper helper) {
		setTide(helper, Tide.THRIVE);
		floor(helper);
		helper.setBlock(new BlockPos(12, 0, 12), ModBlocks.TIDE_SAND);
		helper.setBlock(new BlockPos(12, 1, 12), ModBlocks.TIDEWRACK.defaultBlockState().setValue(TideFloraBlock.OPEN, true));
		Player owner = helper.makeMockServerPlayer(GameType.SURVIVAL);
		owner.setPos(helper.absoluteVec(new Vec3(3.5, 1, 3.5)));
		Blub blub = helper.spawn(ModEntities.BLUB, new Vec3(5.5, 1, 5.5));
		blub.tame(owner);
		helper.succeedWhen(() -> {
			helper.assertTrue(TideFloraBlock.isPicked(helper.getBlockState(new BlockPos(12, 1, 12)), helper.getLevel()), "the blub picked it");
			helper.assertItemEntityPresent(ModItems.TIDEWRACK_FROND, new BlockPos(3, 1, 3), 3.0);
		});
	}

	private static void floor(GameTestHelper helper) {
		for (int x = 0; x < 17; x++) {
			for (int z = 0; z < 17; z++) {
				helper.setBlock(new BlockPos(x, 0, z), ModBlocks.HEALTHY_SCULK);
			}
		}
	}
}
