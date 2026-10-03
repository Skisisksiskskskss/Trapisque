package thesift.test;

import java.util.List;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.enchantment.Enchantments;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

import thesift.block.TideFloraBlock;
import thesift.block.TidewrackBlock;
import thesift.registry.ModBlocks;
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
}
