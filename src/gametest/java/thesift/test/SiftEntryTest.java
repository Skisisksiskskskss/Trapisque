package thesift.test;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.animal.pig.Pig;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.phys.Vec3;

import thesift.block.SiftMembraneBlock;
import thesift.entry.FrameMusic;
import thesift.entry.FrameShapes;
import thesift.entry.Offering;
import thesift.entry.SiftFrame;
import thesift.entry.SiftGates;
import thesift.entry.SiftLinks;
import thesift.registry.ModBlocks;
import thesift.world.SiftKeys;
import thesift.world.SiftAdvancements;
import thesift.world.SoulPoints;

/** WP-046/047: the way in and the way back (entry_path.md). */
public final class SiftEntryTest {
	/**
	 * A spot for a full-size frame, far from the GameTest structures. Each test uses its own
	 * index; the links are server-wide, so frames must not share positions.
	 */
	private static BlockPos site(GameTestHelper helper, int index) {
		BlockPos o = helper.absolutePos(BlockPos.ZERO);
		return new BlockPos(o.getX() + 4096 + index * 160, 100, o.getZ() + 4096);
	}

	private static SiftFrame buildCityFrame(ServerLevel level, BlockPos origin, Direction.Axis axis) {
		SiftFrame frame = new SiftFrame(origin, axis, SiftFrame.CITY_WIDTH, SiftFrame.CITY_HEIGHT);
		frame.border().forEach(p -> level.setBlockAndUpdate(p, Blocks.REINFORCED_DEEPSLATE.defaultBlockState()));
		frame.opening().forEach(p -> level.setBlockAndUpdate(p, Blocks.AIR.defaultBlockState()));
		return frame;
	}

	private static ServerPlayer playerAt(GameTestHelper helper, SiftFrame frame, int levels) {
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		Vec3 front = frame.arrival();
		player.setPos(front.x, front.y, front.z);
		player.setExperienceLevels(levels);
		player.setExperiencePoints(0);
		return player;
	}

	@GameTest
	public void frameIsFoundFromAnyBorderBlock(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		for (Direction.Axis axis : new Direction.Axis[] {Direction.Axis.X, Direction.Axis.Z}) {
			SiftFrame frame = buildCityFrame(level, site(helper, axis == Direction.Axis.X ? 0 : 1), axis);
			for (BlockPos touched : new BlockPos[] {frame.at(0, 0), frame.at(11, 7), frame.at(21, 3), frame.at(5, 0)}) {
				helper.assertValueEqual(FrameShapes.find(level, touched, Blocks.REINFORCED_DEEPSLATE, 22, 8).orElse(null), frame,
						"frame found from " + touched);
			}
			level.setBlockAndUpdate(frame.at(21, 4), Blocks.DEEPSLATE.defaultBlockState());
			helper.assertTrue(FrameShapes.find(level, frame.at(0, 0), Blocks.REINFORCED_DEEPSLATE, 22, 8).isEmpty(),
					"a frame missing a block stays dormant");
		}
		helper.succeed();
	}

	@GameTest
	public void offeringTakesExperienceAndWakesTheFrame(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		SiftFrame frame = buildCityFrame(level, site(helper, 2), Direction.Axis.X);
		ServerPlayer player = playerAt(helper, frame, 30);
		helper.assertValueEqual(SoulPoints.total(player), Offering.PRICE, "level 30 is the whole price");

		helper.assertTrue(Offering.offer(player, level, frame.at(3, 0)), "the frame takes an offering");
		helper.assertValueEqual(SoulPoints.total(player), Offering.PRICE - Offering.POINTS_PER_USE, "one use takes 10 points");
		helper.assertValueEqual(player.experienceLevel, 29, "crossing a level boundary");

		for (int i = 0; i < 200 && SoulPoints.total(player) > 0; i++) {
			Offering.offer(player, level, frame.at(3, 0));
		}
		SiftLinks.FrameLink link = SiftLinks.get(level.getServer()).frameWithBorder(frame.at(3, 0)).orElseThrow();
		helper.assertTrue(link.awake(), "the full price wakes the frame: " + link.charge());
		helper.assertValueEqual(SoulPoints.total(player), 0, "every point went in");
		helper.assertFalse(FrameMusic.isOpen(level, frame), "waking does not open it: that takes music");
		helper.assertTrue(SiftAdvancements.has(player, SiftAdvancements.OFFERING), "waking the frame grants An Offering");
		helper.succeed();
	}

	@GameTest
	public void enteringTheSiftGrantsWhereSoulsDrift(GameTestHelper helper) {
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		helper.assertFalse(SiftAdvancements.has(player, SiftAdvancements.ENTER), "not before");
		net.minecraft.advancements.triggers.CriteriaTriggers.CHANGED_DIMENSION.trigger(player, net.minecraft.world.level.Level.OVERWORLD, SiftKeys.LEVEL);
		helper.assertTrue(SiftAdvancements.has(player, SiftAdvancements.ENTER), "arriving in the Sift grants Where Souls Drift");
		helper.succeed();
	}

	@GameTest
	public void offeringNeedsAFrame(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockPos lone = site(helper, 3);
		level.setBlockAndUpdate(lone, Blocks.REINFORCED_DEEPSLATE.defaultBlockState());
		ServerPlayer player = playerAt(helper, new SiftFrame(lone, Direction.Axis.X, 22, 8), 10);
		int before = SoulPoints.total(player);
		helper.assertFalse(Offering.offer(player, level, lone), "a lone block is no frame");
		helper.assertValueEqual(SoulPoints.total(player), before, "nothing is taken");
		helper.succeed();
	}

	@GameTest
	public void musicOpensOnlyAnAwakeFrame(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		SiftLinks links = SiftLinks.get(level.getServer());
		SiftFrame dormant = buildCityFrame(level, site(helper, 4), Direction.Axis.Z);
		SiftFrame awake = buildCityFrame(level, site(helper, 5), Direction.Axis.Z);
		links.add(dormant);
		links.addCharge(awake, Offering.PRICE);

		Vec3 nearDormant = Vec3.atCenterOf(dormant.at(11, 0)).add(5, 0, 0);
		level.gameEvent(GameEvent.NOTE_BLOCK_PLAY, nearDormant, GameEvent.Context.of(Blocks.NOTE_BLOCK.defaultBlockState()));
		helper.assertFalse(FrameMusic.isOpen(level, dormant), "a dormant frame ignores music");

		Vec3 farFromAwake = Vec3.atCenterOf(awake.at(11, 0)).add(FrameMusic.VIBRATION_RANGE + 3, 0, 0);
		level.gameEvent(GameEvent.NOTE_BLOCK_PLAY, farFromAwake, GameEvent.Context.of(Blocks.NOTE_BLOCK.defaultBlockState()));
		helper.assertFalse(FrameMusic.isOpen(level, awake), "music out of range is not heard");

		Vec3 jukebox = Vec3.atCenterOf(awake.at(11, 0)).add(FrameMusic.JUKEBOX_RANGE - 2, 0, 0);
		// Natural frames grow sculk veins into the opening; they must not keep it shut.
		level.setBlock(awake.at(1, 3), Blocks.SCULK_VEIN.defaultBlockState()
				.setValue(net.minecraft.world.level.block.state.properties.BlockStateProperties.NORTH, true), 2);
		level.gameEvent(GameEvent.JUKEBOX_PLAY, jukebox, GameEvent.Context.of(Blocks.JUKEBOX.defaultBlockState()));
		for (BlockPos p : awake.opening()) {
			helper.assertTrue(level.getBlockState(p).is(ModBlocks.SIFT_MEMBRANE), "membrane fills the opening at " + p);
			helper.assertValueEqual(level.getBlockState(p).getValue(SiftMembraneBlock.AXIS), Direction.Axis.Z, "membrane axis");
		}
		helper.succeed();
	}

	@GameTest
	public void musicNeverReplacesAnotherPortal(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		SiftFrame frame = buildCityFrame(level, site(helper, 6), Direction.Axis.X);
		SiftLinks.get(level.getServer()).addCharge(frame, Offering.PRICE);
		level.setBlock(frame.at(4, 2), Blocks.NETHER_PORTAL.defaultBlockState(), 2);
		helper.assertFalse(FrameMusic.open(level, frame), "the first mod to fill the frame wins");
		helper.assertFalse(level.getBlockState(frame.at(1, 1)).is(ModBlocks.SIFT_MEMBRANE), "nothing was placed");
		helper.succeed();
	}

	@GameTest(maxTicks = 200)
	public void crossingBuildsAGateAndReturnLeadsBack(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		ServerLevel sift = level.getServer().getLevel(SiftKeys.LEVEL);
		SiftLinks links = SiftLinks.get(level.getServer());
		SiftFrame frame = buildCityFrame(level, site(helper, 7), Direction.Axis.X);
		links.addCharge(frame, Offering.PRICE);
		FrameMusic.open(level, frame);
		ServerPlayer player = playerAt(helper, frame, 0);

		TeleportTransition there = SiftGates.destination(level, player, frame.at(10, 1));
		helper.assertTrue(there != null && there.newLevel() == sift, "the membrane leads into the Sift");
		SiftFrame gate = links.frameWithBorder(frame.at(0, 0)).orElseThrow().gate().orElseThrow();
		helper.assertValueEqual(FrameShapes.find(sift, gate.origin(), ModBlocks.GATESTONE, SiftFrame.GATE_WIDTH, SiftFrame.GATE_HEIGHT).orElse(null),
				gate, "a whole gatestone gate stands in the Sift");
		helper.assertTrue(FrameMusic.isOpen(sift, gate), "the gate is open");
		helper.assertValueEqual(gate.axis(), frame.axis(), "the gate faces like the frame");
		helper.assertTrue(Math.abs(gate.center().x - frame.center().x) < 2 && Math.abs(gate.center().z - frame.center().z) < 2,
				"the gate stands at the matching x/z: " + gate.center());
		helper.assertValueEqual(there.position(), gate.arrival(), "arrival is inside the gate");
		helper.assertTrue(sift.getBlockState(BlockPos.containing(gate.arrival()).below()).is(ModBlocks.GATESTONE), "arrival stands on the gate's sill");

		TeleportTransition again = SiftGates.destination(level, player, frame.at(15, 4));
		helper.assertValueEqual(again.position(), there.position(), "the same gate every time");

		TeleportTransition back = SiftGates.destination(sift, player, gate.at(2, 2));
		helper.assertTrue(back != null && back.newLevel() == level, "the gate leads home");
		helper.assertValueEqual(back.position(), frame.arrival(), "back at the frame");

		sift.setBlockAndUpdate(gate.at(2, 2), Blocks.AIR.defaultBlockState());
		SiftGates.destination(level, player, frame.at(10, 1));
		helper.assertTrue(sift.getBlockState(gate.at(2, 2)).is(ModBlocks.SIFT_MEMBRANE), "crossing mends a removed gate membrane");
		helper.succeed();
	}

	@GameTest
	public void gatesKeepTheirDistance(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		ServerLevel sift = level.getServer().getLevel(SiftKeys.LEVEL);
		SiftLinks links = SiftLinks.get(level.getServer());
		SiftFrame a = buildCityFrame(level, site(helper, 8), Direction.Axis.X);
		SiftFrame b = buildCityFrame(level, site(helper, 8).offset(0, 0, 30), Direction.Axis.X);
		SiftFrame gateA = links.setGate(a, SiftGates.build(sift, links, a)).gate().orElseThrow();
		SiftFrame gateB = links.setGate(b, SiftGates.build(sift, links, b)).gate().orElseThrow();
		double d = Math.hypot(gateA.center().x - gateB.center().x, gateA.center().z - gateB.center().z);
		helper.assertTrue(d >= SiftGates.SPACING, "two cities never share a gate: " + d);
		helper.succeed();
	}

	@GameTest
	public void wardensAndBossesCannotCross(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		Entity warden = EntityTypes.WARDEN.create(level, EntitySpawnReason.COMMAND);
		Entity wither = EntityTypes.WITHER.create(level, EntitySpawnReason.COMMAND);
		Entity pig = EntityTypes.PIG.create(level, EntitySpawnReason.COMMAND);
		helper.assertFalse(SiftMembraneBlock.canCross(warden), "a warden can't follow you through");
		helper.assertFalse(SiftMembraneBlock.canCross(wither), "nor can the Wither");
		helper.assertTrue(SiftMembraneBlock.canCross(pig), "a pig can");
		helper.succeed();
	}

	@GameTest
	public void aWardenRidingAMinecartCannotCross(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		var cart = EntityTypes.MINECART.create(level, EntitySpawnReason.COMMAND);
		Entity warden = EntityTypes.WARDEN.create(level, EntitySpawnReason.COMMAND);
		cart.setPos(Vec3.atCenterOf(helper.absolutePos(new BlockPos(2, 1, 2))));
		warden.setPos(cart.position());
		level.addFreshEntity(cart);
		level.addFreshEntity(warden);
		helper.assertTrue(warden.startRiding(cart, true, false), "the warden boards the cart");
		helper.assertTrue(SiftMembraneBlock.canCross(EntityTypes.MINECART.create(level, EntitySpawnReason.COMMAND)), "an empty cart may cross");
		helper.assertFalse(SiftMembraneBlock.canCross(cart), "a cart carrying a warden may not");
		warden.discard();
		cart.discard();
		helper.succeed();
	}

	@GameTest(maxTicks = 200)
	public void aMissingGateIsRebuiltAndABlockedArrivalRefused(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		ServerLevel sift = level.getServer().getLevel(SiftKeys.LEVEL);
		SiftLinks links = SiftLinks.get(level.getServer());
		SiftFrame frame = buildCityFrame(level, site(helper, 13), Direction.Axis.X);
		links.addCharge(frame, Offering.PRICE);
		FrameMusic.open(level, frame);
		ServerPlayer player = playerAt(helper, frame, 0);
		SiftGates.destination(level, player, frame.at(10, 1));
		SiftFrame gate = links.frameWithBorder(frame.at(0, 0)).orElseThrow().gate().orElseThrow();
		// As if the Sift's region files were reset: the gate is gone.
		gate.border().forEach(p -> sift.setBlockAndUpdate(p, ModBlocks.HYMNSTONE.defaultBlockState()));
		gate.opening().forEach(p -> sift.setBlockAndUpdate(p, ModBlocks.HYMNSTONE.defaultBlockState()));
		TeleportTransition there = SiftGates.destination(level, player, frame.at(10, 1));
		helper.assertTrue(there != null, "crossing still works");
		SiftFrame rebuilt = links.frameWithBorder(frame.at(0, 0)).orElseThrow().gate().orElseThrow();
		helper.assertTrue(sift.getBlockState(rebuilt.origin()).is(ModBlocks.GATESTONE), "the gate was rebuilt");
		BlockPos arrival = BlockPos.containing(there.position());
		helper.assertTrue(sift.getBlockState(arrival).getCollisionShape(sift, arrival).isEmpty(), "arrival is in the open");
		// A blocked arrival in the Overworld refuses the crossing instead of burying the traveller.
		level.setBlockAndUpdate(BlockPos.containing(frame.arrival()), Blocks.STONE.defaultBlockState());
		helper.assertTrue(SiftGates.destination(sift, player, rebuilt.at(2, 2)) == null, "no crossing into stone");
		helper.succeed();
	}

	/**
	 * A gate's hill on flat ground can be walked down on every side: no step over one block. The
	 * geometry doesn't depend on the dimension, so this runs in the Overworld test world, whose test
	 * areas have open sky (the Sift's sit under its hills).
	 */
	@GameTest(structure = SiftBasinTest.BIG)
	public void aGateHillOnFlatGroundIsWalkable(GameTestHelper helper) {
		ServerLevel sift = helper.getLevel();
		SiftLinks links = new SiftLinks(); // its own: the server's links hold other tests' gates, which spacing would avoid
		// Test areas sit inside the terrain: open the sky above this one, then lay a flat floor.
		for (int x = 0; x <= 16; x++) {
			for (int z = 0; z <= 16; z++) {
				BlockPos column = helper.absolutePos(new BlockPos(x, 0, z));
				int top = sift.getHeight(net.minecraft.world.level.levelgen.Heightmap.Types.WORLD_SURFACE, column.getX(), column.getZ());
				for (int y = column.getY() + 4; y <= top; y++) {
					sift.setBlock(column.atY(y), Blocks.AIR.defaultBlockState(), net.minecraft.world.level.block.Block.UPDATE_CLIENTS);
				}
				for (int y = 0; y <= 3; y++) {
					helper.setBlock(new BlockPos(x, y, z), ModBlocks.HYMNSTONE);
				}
			}
		}
		BlockPos centre = helper.absolutePos(new BlockPos(8, 4, 8));
		SiftFrame fakeCity = new SiftFrame(new BlockPos(centre.getX() - 11, 0, centre.getZ()), Direction.Axis.X, 22, 8);
		SiftFrame gate = SiftGates.build(sift, links, fakeCity);
		helper.assertTrue(Math.abs(gate.center().x - centre.getX()) < 2 && Math.abs(gate.center().z - centre.getZ()) < 2,
				"the gate stands at the test centre: " + gate.center());
		for (int[] dir : new int[][] {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
			int last = Integer.MIN_VALUE;
			for (int r = 4; r <= 8; r++) {
				int x = centre.getX() + dir[0] * r;
				int z = centre.getZ() + dir[1] * r;
				int y = sift.getHeight(net.minecraft.world.level.levelgen.Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, x, z);
				if (last != Integer.MIN_VALUE) {
					helper.assertTrue(Math.abs(y - last) <= 1, "step of " + (y - last) + " at radius " + r + " toward " + dir[0] + "," + dir[1]);
				}
				last = y;
			}
			helper.assertValueEqual(last, centre.getY(), "the hill ends at the natural ground");
		}
		helper.succeed();
	}

	/**
	 * End to end through the real portal path (entityInside, the portal processor, our
	 * destination): a pig standing in a gate inside the test area walks home to its frame. Mobs
	 * cross with no delay. The gate fits the 8x8x8 test area; a full city frame would not.
	 */
	@GameTest(dimension = "thesift:the_sift", maxTicks = 200)
	public void aPigWalksHomeThroughAGate(GameTestHelper helper) {
		ServerLevel sift = helper.getLevel();
		ServerLevel overworld = sift.getServer().overworld();
		SiftLinks links = SiftLinks.get(sift.getServer());
		SiftFrame frame = buildCityFrame(overworld, site(helper, 11), Direction.Axis.X);
		links.addCharge(frame, Offering.PRICE);
		SiftFrame gate = new SiftFrame(helper.absolutePos(new BlockPos(1, 1, 3)), Direction.Axis.X, SiftFrame.GATE_WIDTH, SiftFrame.GATE_HEIGHT);
		gate.border().forEach(p -> sift.setBlockAndUpdate(p, ModBlocks.GATESTONE.defaultBlockState()));
		links.setGate(frame, gate);
		FrameMusic.open(sift, gate);
		Vec3 at = gate.arrival().subtract(Vec3.atLowerCornerOf(helper.absolutePos(BlockPos.ZERO)));
		Pig pig = helper.spawn(EntityTypes.PIG, at);
		helper.succeedWhen(() -> {
			helper.assertTrue(pig.isRemoved(), "the pig left the Sift");
			helper.assertFalse(overworld.getEntitiesOfClass(Pig.class, frame.box().inflate(3)).isEmpty(), "the pig arrived at the frame");
		});
	}

	/** The detector against vanilla's own output: a real Ancient City, placed like /place structure. */
	@GameTest(maxTicks = 400)
	public void aRealAncientCityFrameIsFound(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockPos at = site(helper, 12).atY(0);
		// /place needs every chunk the city can reach loaded (max_distance_from_center 116). Forced,
		// because getChunk's own ticket can expire before /place runs when other tests load chunks too.
		for (int cx = (at.getX() >> 4) - 8; cx <= (at.getX() >> 4) + 8; cx++) {
			for (int cz = (at.getZ() >> 4) - 8; cz <= (at.getZ() >> 4) + 8; cz++) {
				level.setChunkForced(cx, cz, true);
				level.getChunk(cx, cz);
			}
		}
		var source = level.getServer().createCommandSourceStack().withSuppressedOutput().withLevel(level).withPosition(Vec3.atCenterOf(at));
		var city = level.registryAccess().lookupOrThrow(net.minecraft.core.registries.Registries.STRUCTURE)
				.getOrThrow(net.minecraft.world.level.levelgen.structure.BuiltinStructures.ANCIENT_CITY);
		try {
			net.minecraft.server.commands.PlaceCommand.placeStructure(source, city, at);
		} catch (com.mojang.brigadier.exceptions.CommandSyntaxException e) {
			helper.fail("place structure failed: " + e.getMessage());
		}
		SiftFrame found = null;
		int y = -28; // the frame's top row: one below the anchor's start_height of -27 (VANILLA_ANALOGS W6)
		for (int dx = -96; dx <= 96 && found == null; dx++) {
			for (int dz = -96; dz <= 96 && found == null; dz++) {
				BlockPos p = new BlockPos(at.getX() + dx, y, at.getZ() + dz);
				if (level.getBlockState(p).is(Blocks.REINFORCED_DEEPSLATE)) {
					found = FrameShapes.find(level, p, Blocks.REINFORCED_DEEPSLATE, SiftFrame.CITY_WIDTH, SiftFrame.CITY_HEIGHT).orElse(null);
				}
			}
		}
		for (int cx = (at.getX() >> 4) - 8; cx <= (at.getX() >> 4) + 8; cx++) {
			for (int cz = (at.getZ() >> 4) - 8; cz <= (at.getZ() >> 4) + 8; cz++) {
				level.setChunkForced(cx, cz, false);
			}
		}
		helper.assertTrue(found != null, "the placed city has a frame");
		helper.assertValueEqual(found.origin().getY() + SiftFrame.CITY_HEIGHT - 1, y, "frame top at the anchor");
		helper.succeed();
	}
}
