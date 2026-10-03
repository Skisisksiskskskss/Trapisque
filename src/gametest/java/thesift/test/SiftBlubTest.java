package thesift.test;

import java.util.List;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.decoration.LeashFenceKnotEntity;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.NoteBlock;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.Vec3;

import thesift.entity.blub.Blub;
import thesift.entity.blub.BlubCrossing;
import thesift.registry.ModBlocks;
import thesift.registry.ModEntities;
import thesift.registry.ModTags;
import thesift.world.SiftKeys;
import thesift.world.Tide;

/** The Blub (mob_blub.md): befriending by hand-played notes, the echo, sitting and release, crossing, spawning. */
public final class SiftBlubTest {
	private static final BlockPos NOTE = new BlockPos(1, 1, 1);

	/** A stone floor, a note block at {@link #NOTE} and a player standing next to it. */
	private static ServerPlayer stage(GameTestHelper helper, int note) {
		for (int x = 0; x < 8; x++) {
			for (int z = 0; z < 8; z++) {
				helper.setBlock(new BlockPos(x, 0, z), Blocks.STONE);
			}
		}
		helper.setBlock(NOTE, Blocks.NOTE_BLOCK.defaultBlockState().setValue(NoteBlock.NOTE, note));
		ServerPlayer player = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		Vec3 at = helper.absoluteVec(new Vec3(2.5, 1, 1.5));
		player.setPos(at.x, at.y, at.z);
		return player;
	}

	private static Blub blub(GameTestHelper helper, double x, double z) {
		Blub blub = helper.spawn(ModEntities.BLUB, new Vec3(x, 1, z));
		blub.setNoAi(true); // these tests drive the music by hand; the goals would wander off
		return blub;
	}

	/** A note played by {@code player}'s hand (null: by redstone) on the test's note block. */
	private static void play(GameTestHelper helper, ServerPlayer player) {
		helper.getLevel().gameEvent(player, GameEvent.NOTE_BLOCK_PLAY, helper.absolutePos(NOTE));
	}

	@GameTest
	public void theFirstNoteOnlyListensTheNextBefriends(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub blub = blub(helper, 4.5, 1.5);
		play(helper, player);
		helper.assertTrue(blub.isListening(), "music makes a blub listen");
		helper.assertFalse(blub.isTame(), "the first note never befriends");
		play(helper, player);
		helper.assertTrue(blub.isTame() && blub.isOwnedBy(player), "the next hand-played note befriends the listening blub");
		helper.succeed();
	}

	@GameTest
	public void oneNoteBefriendsOnlyTheNearestWithinFour(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub near = blub(helper, 3.5, 1.5);
		Blub next = blub(helper, 4.5, 2.5);
		Blub far = blub(helper, 7.5, 6.5);
		play(helper, player);
		play(helper, player);
		helper.assertTrue(near.isTame(), "the nearest listening blub is befriended");
		helper.assertFalse(next.isTame(), "one note, one blub");
		play(helper, player);
		helper.assertTrue(next.isTame(), "the next note befriends the next nearest");
		play(helper, player);
		helper.assertFalse(far.isTame(), "a blub more than 4 blocks from the player is never befriended");
		helper.assertTrue(far.isListening(), "but it listens");
		helper.succeed();
	}

	@GameTest
	public void redstoneNotesAndJukeboxesNeverBefriend(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub blub = blub(helper, 4.5, 1.5);
		ServerLevel level = helper.getLevel();
		BlockPos note = helper.absolutePos(NOTE);
		level.gameEvent(null, GameEvent.NOTE_BLOCK_PLAY, note);
		level.gameEvent(null, GameEvent.NOTE_BLOCK_PLAY, note);
		level.gameEvent(null, GameEvent.JUKEBOX_PLAY, note);
		helper.assertTrue(blub.isListening(), "redstone notes and jukeboxes make blubs listen");
		helper.assertFalse(blub.isTame(), "no hand, no friend");
		helper.succeed();
	}

	@GameTest(maxTicks = 100)
	public void befriendedBlubsSingAChord(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub root = blub(helper, 3.5, 1.5);
		Blub third = blub(helper, 4.5, 1.5);
		Blub fifth = blub(helper, 5.5, 1.5);
		play(helper, player);
		play(helper, player);
		play(helper, player);
		play(helper, player);
		helper.assertTrue(root.isTame() && third.isTame() && fifth.isTame(), "three notes after the first befriend three blubs");
		helper.assertValueEqual(List.of(root.echoInterval(), third.echoInterval(), fifth.echoInterval()), List.of(0, 4, 7),
				"each new blub takes the next interval: root, third, fifth");
		helper.runAfterDelay(20, () -> {
			helper.setBlock(NOTE, Blocks.NOTE_BLOCK.defaultBlockState().setValue(NoteBlock.NOTE, 10));
			play(helper, player);
			helper.runAfterDelay(Blub.ECHO_DELAY + 2, () -> {
				helper.assertValueEqual(List.of(root.lastSungNote(), third.lastSungNote(), fifth.lastSungNote()), List.of(10, 14, 17),
						"the owner's note plus each blub's interval");
				helper.succeed();
			});
		});
	}

	@GameTest
	public void echoesStayInRangeAndDropAnOctave(GameTestHelper helper) {
		helper.assertValueEqual(Blub.echoNote(22, 7), 17, "past note 24 the echo drops an octave instead of clamping");
		helper.assertValueEqual(Blub.echoNote(17, 7), 24, "note 24 is still in range");
		helper.assertValueEqual(Blub.echoNote(3, 4), 7, "a third above");
		helper.succeed();
	}

	@GameTest
	public void useSitsAndSneakUseReleases(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub blub = blub(helper, 3.5, 1.5);
		play(helper, player);
		play(helper, player);
		helper.assertTrue(blub.isTame(), "befriended");
		blub.mobInteract(player, InteractionHand.MAIN_HAND);
		helper.assertTrue(blub.isOrderedToSit(), "use with an empty hand sits it");
		player.setShiftKeyDown(true);
		blub.mobInteract(player, InteractionHand.MAIN_HAND);
		helper.assertFalse(blub.isTame(), "sneak-use releases a sitting blub");
		helper.assertTrue(blub.getOwnerReference() == null && !blub.isOrderedToSit(), "released: no owner, not sitting");
		helper.succeed();
	}

	@GameTest
	public void theHeraldWarnsBeforeEachFlow(GameTestHelper helper) {
		long rising = Tide.FLOW_RISING.startTick();
		long falling = Tide.FLOW_FALLING.startTick();
		helper.assertFalse(Blub.isHeraldTime(rising - Blub.HERALD_TICKS - 1), "quiet until 30 s before Flow");
		helper.assertTrue(Blub.isHeraldTime(rising - Blub.HERALD_TICKS), "restless at the end of Thrive");
		helper.assertTrue(Blub.isHeraldTime(rising - 1), "restless until Flow begins");
		helper.assertFalse(Blub.isHeraldTime(rising), "calm once Flow begins");
		helper.assertTrue(Blub.isHeraldTime(falling - 1), "restless at the end of Endure");
		helper.assertFalse(Blub.isHeraldTime(Tide.ENDURE.startTick() - 1), "no warning before Endure: the sky shows it");
		helper.succeed();
	}

	@GameTest
	public void blubsCantCross(GameTestHelper helper) {
		Blub blub = blub(helper, 2.5, 2.5);
		helper.assertTrue(blub.is(ModTags.CANNOT_CROSS), "no blub walks through a membrane on its own");
		helper.succeed();
	}

	@GameTest
	public void spawnRulesFollowTheMeadowAndTheTide(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		BlockPos floor = helper.absolutePos(new BlockPos(2, 0, 2));
		BlockPos at = floor.above();
		for (var block : List.of(ModBlocks.TIDE_SAND, ModBlocks.HEALTHY_SCULK)) {
			level.setBlockAndUpdate(floor, block.defaultBlockState());
			helper.assertTrue(Blub.checkBlubSpawnRules(ModEntities.BLUB, level, EntitySpawnReason.SPAWN_ITEM_USE, at, level.getRandom()),
					"blubs spawn on " + block);
		}
		level.setBlockAndUpdate(floor, Blocks.STONE.defaultBlockState());
		helper.assertFalse(Blub.checkBlubSpawnRules(ModEntities.BLUB, level, EntitySpawnReason.SPAWN_ITEM_USE, at, level.getRandom()),
				"only on healthy sculk or tide sand");
		helper.assertFalse(Blub.naturalSpawnAllowed(Tide.ENDURE), "no natural spawns in Endure");
		helper.assertTrue(Blub.naturalSpawnAllowed(Tide.THRIVE) && Blub.naturalSpawnAllowed(Tide.FLOW_RISING), "the other Tides spawn");
		helper.succeed();
	}

	@GameTest
	public void ownersBlubsCrossWithThem(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub follower = blub(helper, 3.5, 1.5);
		Blub sitter = blub(helper, 4.5, 2.5);
		Blub knotted = blub(helper, 5.5, 3.5);
		Blub rider = blub(helper, 2.5, 6.5); // 5 blocks from the player: never befriended
		play(helper, player);
		play(helper, player);
		play(helper, player);
		play(helper, player);
		helper.assertTrue(follower.isTame() && sitter.isTame() && knotted.isTame(), "three befriended");
		helper.assertFalse(rider.isTame(), "one untamed");
		sitter.setOrderedToSit(true);
		helper.setBlock(new BlockPos(6, 1, 6), Blocks.OAK_FENCE);
		knotted.setLeashedTo(LeashFenceKnotEntity.getOrCreateKnot(helper.getLevel(), helper.absolutePos(new BlockPos(6, 1, 6))), true);
		helper.assertTrue(rider.startRiding(follower, true, false), "an untamed blub rides the follower");

		ServerLevel sift = helper.getLevel().getServer().getLevel(SiftKeys.LEVEL);
		helper.assertTrue(sift != null, "the Sift exists");
		Vec3 arrival = Vec3.atBottomCenterOf(helper.absolutePos(BlockPos.ZERO).atY(200));
		List<Entity> moved = BlubCrossing.bring(player, helper.getLevel(), player.position(), sift, arrival);
		try {
			helper.assertValueEqual(moved.size(), 1, "only the free, owner-led blub comes along");
			Entity arrived = moved.get(0);
			helper.assertTrue(arrived instanceof Blub b && b.isTame() && arrived.level() == sift && arrived.getPassengers().isEmpty(),
					"the owner's blub arrives in the Sift, still befriended, with no rider");
			helper.assertFalse(follower.isAlive(), "and is gone from here");
			helper.assertTrue(sitter.isAlive() && knotted.isAlive() && rider.isAlive(), "sitting, knot-leashed and untamed blubs stay");
			helper.assertFalse(rider.isPassenger(), "the tower toppled before the crossing");
		} finally {
			moved.forEach(Entity::discard);
		}
		helper.succeed();
	}

	@GameTest
	public void hurtingTheBottomBlubTopplesTheTower(GameTestHelper helper) {
		stage(helper, 0);
		Blub bottom = blub(helper, 3.5, 3.5);
		Blub middle = blub(helper, 3.5, 3.5);
		Blub top = blub(helper, 3.5, 3.5);
		helper.assertTrue(middle.startRiding(bottom, true, false) && top.startRiding(middle, true, false), "a tower of three");
		bottom.hurtServer(helper.getLevel(), helper.getLevel().damageSources().generic(), 1.0F);
		helper.assertFalse(middle.isPassenger() || top.isPassenger(), "everyone tumbles off");
		helper.succeed();
	}

	/**
	 * WP-051's cost check: 50 blubs against 50 rabbits on the same Meadow floor, each entity ticked
	 * by hand in alternating order after a warm-up. The ratio goes in the PLAN log; the assertion is
	 * only a guard against a gross regression (machines differ).
	 */
	@GameTest(dimension = "thesift:the_sift", structure = SiftBasinTest.BIG, maxTicks = 400)
	public void fiftyBlubsCostAboutAsMuchAsFiftyRabbits(GameTestHelper helper) {
		for (int x = 0; x < 17; x++) {
			for (int z = 0; z < 17; z++) {
				helper.setBlock(new BlockPos(x, 0, z), ModBlocks.HEALTHY_SCULK);
			}
		}
		List<Blub> blubs = new java.util.ArrayList<>();
		List<net.minecraft.world.entity.animal.rabbit.Rabbit> rabbits = new java.util.ArrayList<>();
		for (int i = 0; i < 50; i++) {
			double x = 1.5 + (i % 7) * 2;
			double z = 1.5 + (i / 7) * 2;
			blubs.add(helper.spawn(ModEntities.BLUB, new Vec3(x, 1, z)));
			rabbits.add(helper.spawn(net.minecraft.world.entity.EntityTypes.RABBIT, new Vec3(x + 1, 1, z + 1)));
		}
		// Busy blubs, not idle ones: half befriended (owner tracking, herald), all listening to music.
		ServerPlayer owner = (ServerPlayer) helper.makeMockServerPlayer(GameType.SURVIVAL);
		owner.setPos(helper.absoluteVec(new Vec3(8.5, 1, 8.5)));
		for (int i = 0; i < blubs.size(); i += 2) {
			blubs.get(i).tame(owner);
		}
		helper.getLevel().gameEvent(null, GameEvent.JUKEBOX_PLAY, helper.absolutePos(new BlockPos(8, 1, 8)));
		long[] cost = new long[2];
		for (int round = 0; round < 400; round++) {
			boolean blubsFirst = round % 2 == 0;
			for (int pass = 0; pass < 2; pass++) {
				boolean doBlubs = (pass == 0) == blubsFirst;
				long t0 = System.nanoTime();
				for (Entity e : doBlubs ? blubs : rabbits) {
					e.tickCount++; // as ServerLevel.tickNonPassenger does
					e.tick();
				}
				if (round >= 100) { // the first 100 rounds warm the JIT up
					cost[doBlubs ? 0 : 1] += System.nanoTime() - t0;
				}
			}
		}
		double ratio = (double) cost[0] / Math.max(1, cost[1]);
		thesift.TheSift.LOGGER.info("Tick cost, 300 rounds: 50 blubs {} ms, 50 rabbits {} ms, ratio {}",
				cost[0] / 1_000_000, cost[1] / 1_000_000, String.format(java.util.Locale.ROOT, "%.2f", ratio));
		helper.assertTrue(ratio < 3.0, "50 blubs cost " + ratio + "x 50 rabbits");
		blubs.forEach(Entity::discard);
		rabbits.forEach(Entity::discard);
		helper.succeed();
	}

	/**
	 * AI on (the review's probe): eight listening blubs in Thrive build towers on their own. No blub
	 * ever rides itself, no tower passes five, and the server keeps ticking.
	 */
	@GameTest(dimension = "thesift:the_sift", structure = SiftBasinTest.BIG, maxTicks = 500)
	public void listeningBlubsStackOnTheirOwn(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		for (int x = 0; x < 17; x++) {
			for (int z = 0; z < 17; z++) {
				helper.setBlock(new BlockPos(x, 0, z), ModBlocks.HEALTHY_SCULK);
			}
		}
		helper.assertValueEqual(Tide.current(level), Tide.THRIVE, "the test server's Tide clock waits at Thrive");
		List<Blub> blubs = new java.util.ArrayList<>();
		for (int i = 0; i < 8; i++) {
			blubs.add(helper.spawn(ModEntities.BLUB, new Vec3(6.5 + (i % 3), 1, 6.5 + (i / 3))));
		}
		BlockPos music = helper.absolutePos(new BlockPos(8, 1, 8));
		int[] tallest = {1};
		helper.onEachTick(() -> {
			if (level.getGameTime() % 40 == 0) {
				level.gameEvent(null, GameEvent.JUKEBOX_PLAY, music);
			}
			for (Blub b : blubs) {
				helper.assertFalse(b.getVehicle() == b, "a blub never rides itself");
				if (!b.isPassenger()) {
					int h = 1;
					for (Entity e = b; !e.getPassengers().isEmpty() && h < 10; h++) { // capped: a loop must fail, not hang
						e = e.getPassengers().get(0);
					}
					helper.assertTrue(h <= 5, "towers stop at five: " + h);
					tallest[0] = Math.max(tallest[0], h);
				}
			}
		});
		helper.runAfterDelay(400, () -> {
			helper.assertTrue(tallest[0] >= 2, "listening blubs climbed onto each other (tallest " + tallest[0] + ")");
			helper.succeed();
		});
	}

	/**
	 * The real crossing path: SiftGates records the entry, the level-change event consumes it. A
	 * record older than 5 ticks moves nobody; an owner-held leash comes along.
	 */
	@GameTest(maxTicks = 100)
	public void blubsFollowOnlyAFreshCrossing(GameTestHelper helper) {
		ServerPlayer player = stage(helper, 0);
		Blub leashed = blub(helper, 3.5, 1.5);
		play(helper, player);
		play(helper, player);
		helper.assertTrue(leashed.isTame(), "befriended");
		leashed.setLeashedTo(player, true);
		ServerLevel overworld = helper.getLevel();
		ServerLevel sift = overworld.getServer().getLevel(SiftKeys.LEVEL);
		BlubCrossing.recordEntry(player, overworld);
		helper.runAfterDelay(10, () -> {
			net.fabricmc.fabric.api.entity.event.v1.ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL.invoker().afterChangeLevel(player, overworld, sift);
			helper.assertTrue(leashed.isAlive() && leashed.level() == overworld, "a stale record (10 ticks) brings no one");
			BlubCrossing.recordEntry(player, overworld);
			player.setPos(helper.absoluteVec(new Vec3(2.5, 1, 1.5)).add(0, 200, 0));
			net.fabricmc.fabric.api.entity.event.v1.ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL.invoker().afterChangeLevel(player, overworld, sift);
			helper.assertFalse(leashed.isAlive(), "a fresh crossing brings the owner's blub, leash and all");
			List<Blub> arrived = sift.getEntitiesOfClass(Blub.class, new net.minecraft.world.phys.AABB(player.blockPosition()).inflate(2));
			arrived.forEach(Entity::discard);
			helper.succeed();
		});
	}

	/** Natural spawns stop in Endure; generation spawns don't (a lit spot in the Sift). */
	@GameTest(dimension = "thesift:the_sift", structure = SiftBasinTest.BIG, maxTicks = 100)
	public void naturalSpawnsWaitOutEndure(GameTestHelper helper) {
		ServerLevel level = helper.getLevel();
		helper.setBlock(new BlockPos(4, 0, 4), ModBlocks.TIDE_SAND);
		helper.setBlock(new BlockPos(5, 1, 4), Blocks.GLOWSTONE);
		BlockPos at = helper.absolutePos(new BlockPos(4, 1, 4));
		var server = level.getServer();
		// Wait for the glowstone's light to spread (the light engine can lag a few ticks under load).
		boolean[] checked = {false};
		helper.onEachTick(() -> {
			if (!checked[0] && level.getRawBrightness(at, 0) > 8) {
				checked[0] = true;
				checkSpawnsAcrossTides(helper, level, at, server);
			}
		});
	}

	private static void checkSpawnsAcrossTides(GameTestHelper helper, ServerLevel level, BlockPos at, net.minecraft.server.MinecraftServer server) {
		helper.assertTrue(level.getRawBrightness(at, 0) > 8, "the spot is lit");
		try {
			server.clockManager().setTotalTicks(thesift.world.TideClock.clock(server), Tide.ENDURE.startTick() + 10);
			helper.assertValueEqual(Tide.current(level), Tide.ENDURE, "Endure");
			helper.assertFalse(Blub.checkBlubSpawnRules(ModEntities.BLUB, level, EntitySpawnReason.NATURAL, at, level.getRandom()), "no natural spawns in Endure");
			helper.assertTrue(Blub.checkBlubSpawnRules(ModEntities.BLUB, level, EntitySpawnReason.CHUNK_GENERATION, at, level.getRandom()), "generation still places blubs");
			server.clockManager().setTotalTicks(thesift.world.TideClock.clock(server), Tide.THRIVE.startTick());
			helper.assertTrue(Blub.checkBlubSpawnRules(ModEntities.BLUB, level, EntitySpawnReason.NATURAL, at, level.getRandom()), "natural spawns in Thrive");
		} finally {
			server.clockManager().setTotalTicks(thesift.world.TideClock.clock(server), Tide.THRIVE.startTick());
		}
		helper.succeed();
	}
}
