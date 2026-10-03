package thesift.registry;

import java.util.function.Function;
import java.util.function.UnaryOperator;

import net.fabricmc.fabric.api.registry.FlammableBlockRegistry;
import net.minecraft.core.Registry;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.util.ColorRGBA;
import net.minecraft.util.random.WeightedList;
import net.minecraft.util.valueproviders.ConstantInt;
import net.minecraft.util.valueproviders.UniformInt;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.ColoredFallingBlock;
import net.minecraft.world.level.block.DropExperienceBlock;
import net.minecraft.world.level.block.HangingMossBlock;
import net.minecraft.world.level.block.FlowerPotBlock;
import net.minecraft.world.level.block.LanternBlock;
import net.minecraft.world.level.block.LiquidBlock;
import net.minecraft.world.level.block.RedStoneOreBlock;
import net.minecraft.world.level.block.RotatedPillarBlock;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.UntintedParticleLeavesBlock;
import net.minecraft.world.level.block.WallBlock;
import net.minecraft.world.level.block.grower.TreeGrower;
import net.minecraft.world.level.block.sounds.AmbientLeavesBlockSoundPlayer;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.properties.NoteBlockInstrument;
import net.minecraft.world.level.material.MapColor;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.level.storage.loot.providers.number.ints.ContextIntProviders;

import thesift.TheSift;
import thesift.block.CarapaceGrassBlock;
import thesift.block.ChimeBellFlowerBlock;
import thesift.block.ChorusStoneBlock;
import thesift.block.EndureBloomBlock;
import thesift.block.GlowcapBlock;
import thesift.block.GroveHeartBlock;
import thesift.block.HealthySculkBlock;
import thesift.block.HealthySculkGrassBlock;
import thesift.block.IchorLilyBlock;
import thesift.block.LumenBloomBlock;
import thesift.block.SiftMembraneBlock;
import thesift.block.SongwoodLogBlock;
import thesift.block.SongwoodSaplingBlock;
import thesift.block.TideRootsBlock;
import thesift.block.TideVentBlock;
import thesift.block.TallHealthySculkGrassBlock;
import thesift.block.TidewrackBlock;
import thesift.world.SiftFeatures;

/** Block set I (world.md §3; M1). Registration mirrors vanilla's {@code Blocks.register} (D-019). */
public final class ModBlocks {
	/**
	 * Tide roots (survival_sift.md §1): the crop of the ichor shores; its item is the root
	 * ({@link ModItems#TIDE_ROOT}). Declared first: ModItems initializes during the first block-item
	 * registration below, and its tide root needs this block to exist by then.
	 */
	public static final Block TIDE_ROOTS = registerNoItem("tide_roots", TideRootsBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.PLANT).noCollision().randomTicks().instabreak().sound(SoundType.CROP).pushReaction(PushReaction.POPPED));

	public static final Block HYMNSTONE = register("hymnstone", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.TERRACOTTA_RED).instrument(NoteBlockInstrument.BASEDRUM)
			.requiresCorrectToolForDrops().strength(1.5F, 6.0F).sound(SoundType.CALCITE));
	public static final Block HYMNSTONE_BRICKS = register("hymnstone_bricks", Block::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE));
	public static final Block HYMNSTONE_BRICK_STAIRS = register("hymnstone_brick_stairs",
			p -> new StairBlock(HYMNSTONE_BRICKS.defaultBlockState(), p), BlockBehaviour.Properties.ofFullCopy(HYMNSTONE_BRICKS));
	public static final Block HYMNSTONE_BRICK_SLAB = register("hymnstone_brick_slab", SlabBlock::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE_BRICKS));
	public static final Block HYMNSTONE_BRICK_WALL = register("hymnstone_brick_wall", WallBlock::new,
			BlockBehaviour.Properties.ofFullCopy(HYMNSTONE_BRICKS).forceSolidOn());
	public static final Block CRACKED_HYMNSTONE_BRICKS = register("cracked_hymnstone_bricks", Block::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE));
	public static final Block CHISELED_HYMNSTONE_BRICKS = register("chiseled_hymnstone_bricks", Block::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE));

	// The rest of the family (owner: hymnstone works as stone): mined, it breaks to cobbled hymnstone, which crafts
	// the stone tools and furnace and smelts back; smelted again it turns smooth. Polished is cut or crafted 2x2.
	public static final Block HYMNSTONE_STAIRS = stairs("hymnstone_stairs", HYMNSTONE);
	public static final Block HYMNSTONE_SLAB = slab("hymnstone_slab", HYMNSTONE);
	public static final Block COBBLED_HYMNSTONE = register("cobbled_hymnstone", Block::new,
			BlockBehaviour.Properties.ofFullCopy(HYMNSTONE).strength(2.0F, 6.0F));
	public static final Block COBBLED_HYMNSTONE_STAIRS = stairs("cobbled_hymnstone_stairs", COBBLED_HYMNSTONE);
	public static final Block COBBLED_HYMNSTONE_SLAB = slab("cobbled_hymnstone_slab", COBBLED_HYMNSTONE);
	public static final Block COBBLED_HYMNSTONE_WALL = wall("cobbled_hymnstone_wall", COBBLED_HYMNSTONE);
	public static final Block SMOOTH_HYMNSTONE = register("smooth_hymnstone", Block::new,
			BlockBehaviour.Properties.ofFullCopy(HYMNSTONE).strength(2.0F, 6.0F));
	public static final Block SMOOTH_HYMNSTONE_SLAB = slab("smooth_hymnstone_slab", SMOOTH_HYMNSTONE);
	public static final Block POLISHED_HYMNSTONE = register("polished_hymnstone", Block::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE));
	public static final Block POLISHED_HYMNSTONE_STAIRS = stairs("polished_hymnstone_stairs", POLISHED_HYMNSTONE);
	public static final Block POLISHED_HYMNSTONE_SLAB = slab("polished_hymnstone_slab", POLISHED_HYMNSTONE);
	public static final Block POLISHED_HYMNSTONE_WALL = wall("polished_hymnstone_wall", POLISHED_HYMNSTONE);

	// The Carapace (canon: "a flat, dry biome composed of dark blue stone and vast fields of sand and dust",
	// "red and yellow grass patches", "colossal fossils"; D-035).
	public static final Block CARAPACE_STONE = register("carapace_stone", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_BLUE).instrument(NoteBlockInstrument.BASEDRUM).requiresCorrectToolForDrops().strength(1.5F, 6.0F)
			.sound(SoundType.STONE));
	public static final Block SIFT_DUST = register("sift_dust", p -> new ColoredFallingBlock(new ColorRGBA(0xB8D8D9), p),
			BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_LIGHT_BLUE).instrument(NoteBlockInstrument.SNARE).strength(0.5F).sound(SoundType.SAND));
	public static final Block HUSK_BONE_BLOCK = register("husk_bone_block", RotatedPillarBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.SAND).instrument(NoteBlockInstrument.XYLOPHONE).requiresCorrectToolForDrops().strength(2.0F).sound(SoundType.BONE_BLOCK));

	// The Singer's grove (items.md §1.1, world.md §3; canon: soul blocks, "Lost Harmonies: Find the stolen soul blocks").
	/** A soul block: condensed souls, pale and glowing (as in Dungeons II's ad, at the Singer's feet). */
	public static final Block SOUL_BLOCK = register("soul_block", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_LIGHT_BLUE).strength(1.5F).lightLevel(s -> 10).sound(SoundType.AMETHYST));
	public static final Block CHORUS_STONE = register("chorus_stone", ChorusStoneBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.TERRACOTTA_RED).strength(-1.0F, 3_600_000.0F).noLootTable().sound(SoundType.CALCITE)
			.lightLevel(s -> s.getValue(ChorusStoneBlock.FILLED) ? 10 : 0));
	public static final Block GROVE_HEART = register("grove_heart", GroveHeartBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_PINK).strength(-1.0F, 3_600_000.0F).noLootTable().sound(SoundType.SCULK).lightLevel(s -> 6));

	/** The Sift's grass (owner rework: the teaser's pink-coral ground), over Sift soil as grass over dirt. */
	public static final Block HEALTHY_SCULK = register("healthy_sculk", HealthySculkBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_PINK).strength(0.6F).sound(SoundType.GRASS).randomTicks());
	/** Sift soil: the maroon earth under the grass, the Sift's dirt (the teaser's hill). */
	public static final Block SIFT_SOIL = register("sift_soil", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.TERRACOTTA_BROWN).strength(0.5F).sound(SoundType.GRAVEL));
	public static final Block HEALTHY_SCULK_GRASS = register("healthy_sculk_grass", HealthySculkGrassBlock::new, plant());
	public static final Block TALL_HEALTHY_SCULK_GRASS = register("tall_healthy_sculk_grass", TallHealthySculkGrassBlock::new, plant());
	public static final Block RED_CARAPACE_GRASS = register("red_carapace_grass", CarapaceGrassBlock::new, plant().mapColor(MapColor.COLOR_MAGENTA));
	public static final Block YELLOW_CARAPACE_GRASS = register("yellow_carapace_grass", CarapaceGrassBlock::new, plant().mapColor(MapColor.COLOR_YELLOW));

	public static final Block SONGWOOD_LOG = register("songwood_log", SongwoodLogBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_PURPLE).instrument(NoteBlockInstrument.BASS).strength(2.0F).sound(SoundType.CHERRY_WOOD).ignitedByLava());
	/** Pale strands hanging under the canopy, as the teaser's drooping leaves (vanilla's hanging moss rules). */
	public static final Block SONGWOOD_DRAPES = register("songwood_drapes", HangingMossBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.SNOW).replaceable().noCollision().instabreak().sound(SoundType.MOSS_CARPET).ignitedByLava()
			.pushReaction(PushReaction.POPPED));
	public static final Block SONGWOOD_PLANKS = register("songwood_planks", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_LIGHT_BLUE).instrument(NoteBlockInstrument.BASS).strength(2.0F, 3.0F).sound(SoundType.CHERRY_WOOD).ignitedByLava());
	public static final Block SONGWOOD_LEAVES = register("songwood_leaves",
			p -> new UntintedParticleLeavesBlock(0.02F, ParticleTypes.PALE_OAK_LEAVES, AmbientLeavesBlockSoundPlayer.noAmbientSound(), p),
			BlockBehaviour.Properties.of().mapColor(MapColor.SNOW).strength(0.2F).randomTicks().sound(SoundType.CHERRY_LEAVES)
					.noOcclusion().isSuffocating(ModBlocks::never).ignitedByLava()
					.pushReaction(PushReaction.POPPED).isRedstoneConductor(ModBlocks::never));
	public static final TreeGrower SONGWOOD_GROWER = new TreeGrower(TheSift.MOD_ID + ":songwood",
			WeightedList.of(SiftFeatures.SONGWOOD_TREE), WeightedList.of(), WeightedList.of(), SiftFeatures.SONGWOOD_TREE);
	public static final Block SONGWOOD_SAPLING = register("songwood_sapling", p -> new SongwoodSaplingBlock(SONGWOOD_GROWER, p),
			BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_LIGHT_BLUE).noCollision().randomTicks().instabreak()
					.sound(SoundType.CHERRY_SAPLING).pushReaction(PushReaction.POPPED));
	public static final Block POTTED_SONGWOOD_SAPLING = registerNoItem("potted_songwood_sapling",
			p -> new FlowerPotBlock(SONGWOOD_SAPLING, p), BlockBehaviour.Properties.of().instabreak().noOcclusion().pushReaction(PushReaction.POPPED));

	public static final Block TIDE_SAND = register("tide_sand", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_LIGHT_GRAY).instrument(NoteBlockInstrument.SNARE).strength(0.5F).sound(SoundType.MUD));
	public static final Block TIDE_VENT = register("tide_vent", TideVentBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.TERRACOTTA_RED).instrument(NoteBlockInstrument.BASEDRUM)
			.requiresCorrectToolForDrops().strength(1.5F, 6.0F).sound(SoundType.CALCITE));
	// Flora II (block_flora_ii.md, D-027). The tide plants and the lumen bloom are wild-only: their
	// block items exist for creative and pick-block, but no loot, recipe or trade gives them.
	public static final Block TIDEWRACK = register("tidewrack", TidewrackBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.WATER).noCollision().instabreak().sound(SoundType.WET_GRASS).offsetType(BlockBehaviour.OffsetType.XZ)
			.randomTicks().pushReaction(PushReaction.POPPED));
	public static final Block ENDURE_BLOOM = register("endure_bloom", EndureBloomBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.PLANT).noCollision().instabreak().sound(SoundType.GRASS).offsetType(BlockBehaviour.OffsetType.XZ)
			.randomTicks().pushReaction(PushReaction.POPPED));
	public static final Block GLOWCAP = register("glowcap", GlowcapBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_LIGHT_GREEN).noCollision().instabreak().sound(SoundType.FUNGUS).offsetType(BlockBehaviour.OffsetType.XZ)
			.lightLevel(s -> 10).pushReaction(PushReaction.POPPED), ModBlocks::compostMedium);
	public static final Block POTTED_GLOWCAP = registerNoItem("potted_glowcap", p -> new FlowerPotBlock(GLOWCAP, p),
			BlockBehaviour.Properties.of().instabreak().noOcclusion().lightLevel(s -> 10).pushReaction(PushReaction.POPPED));
	public static final Block CHIME_BELL_FLOWER = register("chime_bell_flower", ChimeBellFlowerBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.PLANT).noCollision().instabreak().sound(SoundType.SMALL_AMETHYST_BUD).offsetType(BlockBehaviour.OffsetType.XZ)
			.ignitedByLava().pushReaction(PushReaction.POPPED), ModBlocks::compostMedium);
	public static final Block POTTED_CHIME_BELL_FLOWER = registerNoItem("potted_chime_bell_flower", p -> new FlowerPotBlock(CHIME_BELL_FLOWER, p),
			BlockBehaviour.Properties.of().instabreak().noOcclusion().pushReaction(PushReaction.POPPED));
	public static final Block LUMEN_BLOOM = register("lumen_bloom", LumenBloomBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_LIGHT_BLUE).noCollision().instabreak().sound(SoundType.SPORE_BLOSSOM).lightLevel(s -> 12)
			.pushReaction(PushReaction.POPPED).noLootTable());
	// Living in the Sift (survival_sift.md §1, §4): hymnstone ores drop vanilla's items, as deepslate's do.
	public static final Block HYMNSTONE_COAL_ORE = ore("hymnstone_coal_ore", p -> new DropExperienceBlock(UniformInt.of(0, 2), p));
	public static final Block HYMNSTONE_COPPER_ORE = ore("hymnstone_copper_ore", p -> new DropExperienceBlock(ConstantInt.of(0), p));
	public static final Block HYMNSTONE_IRON_ORE = ore("hymnstone_iron_ore", p -> new DropExperienceBlock(ConstantInt.of(0), p));
	public static final Block HYMNSTONE_GOLD_ORE = ore("hymnstone_gold_ore", p -> new DropExperienceBlock(ConstantInt.of(0), p));
	public static final Block HYMNSTONE_REDSTONE_ORE = register("hymnstone_redstone_ore", RedStoneOreBlock::new, oreProperties()
			.randomTicks().lightLevel(s -> s.getValue(RedStoneOreBlock.LIT) ? 9 : 0));
	public static final Block HYMNSTONE_LAPIS_ORE = ore("hymnstone_lapis_ore", p -> new DropExperienceBlock(UniformInt.of(2, 5), p));
	public static final Block HYMNSTONE_DIAMOND_ORE = ore("hymnstone_diamond_ore", p -> new DropExperienceBlock(UniformInt.of(3, 7), p));
	public static final Block HYMNSTONE_EMERALD_ORE = ore("hymnstone_emerald_ore", p -> new DropExperienceBlock(UniformInt.of(3, 7), p));
	/** Echo ore: the Sift's own, deep in the Hollows; a faint glow, as deepslate ores are hard. Echo shards. */
	public static final Block ECHO_ORE = register("echo_ore", p -> new DropExperienceBlock(UniformInt.of(3, 7), p), oreProperties()
			.strength(4.5F, 3.0F).lightLevel(s -> 3));

	/** The ichor lily (D-029): the Ichor Flats' own plant, a glowing lily pad on ichor. */
	public static final Block ICHOR_LILY = register("ichor_lily", IchorLilyBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_CYAN).instabreak().sound(SoundType.LILY_PAD).noOcclusion().lightLevel(s -> 9)
			.pushReaction(PushReaction.POPPED), ModBlocks::compostMedium);
	/** The lumen lantern (items_m2.md): vanilla's lantern, its light lumen (it joins the {@code thesift:lumen} POI). */
	public static final Block LUMEN_LANTERN = register("lumen_lantern", LanternBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_LIGHT_BLUE).forceSolidOn().strength(3.5F).sound(SoundType.LANTERN).lightLevel(s -> 15)
			.noOcclusion().pushReaction(PushReaction.POPPED));

	/** The Sift-side gate's frame: unbreakable in survival, like the end portal frame. */
	public static final Block GATESTONE = register("gatestone", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_BLACK).instrument(NoteBlockInstrument.BASEDRUM)
			.strength(-1.0F, 3_600_000.0F).noLootTable().sound(SoundType.CALCITE).isValidSpawn((s, l, p, e) -> false));

	/** Fills an open frame or gate; unbreakable in survival like a Nether portal, and it drops nothing. */
	public static final Block SIFT_MEMBRANE = registerNoItem("sift_membrane", SiftMembraneBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_CYAN).noCollision().strength(-1.0F).sound(SoundType.GLASS).lightLevel(s -> 11)
			.pushReaction(PushReaction.IMMOVEABLE).noLootTable());

	public static final Block ICHOR = registerNoItem("ichor", p -> new LiquidBlock(ModFluids.ICHOR, p), BlockBehaviour.Properties.of()
			.mapColor(MapColor.WATER).replaceable().noCollision().strength(100.0F).lightLevel(s -> 4)
			.pushReaction(PushReaction.POPPED).noLootTable().liquid().sound(SoundType.EMPTY));

	private ModBlocks() {
	}

	/** Hymnstone ores: as vanilla's stone ores (3.0), with hymnstone's sound. */
	private static BlockBehaviour.Properties oreProperties() {
		return BlockBehaviour.Properties.of().mapColor(MapColor.TERRACOTTA_PINK).instrument(NoteBlockInstrument.BASEDRUM)
				.requiresCorrectToolForDrops().strength(3.0F, 3.0F).sound(SoundType.CALCITE);
	}

	private static Block ore(String name, Function<BlockBehaviour.Properties, Block> factory) {
		return register(name, factory, oreProperties());
	}

	private static Block stairs(String name, Block base) {
		return register(name, p -> new StairBlock(base.defaultBlockState(), p), BlockBehaviour.Properties.ofFullCopy(base));
	}

	private static Block slab(String name, Block base) {
		return register(name, SlabBlock::new, BlockBehaviour.Properties.ofFullCopy(base));
	}

	private static Block wall(String name, Block base) {
		return register(name, WallBlock::new, BlockBehaviour.Properties.ofFullCopy(base).forceSolidOn());
	}

	private static BlockBehaviour.Properties plant() {
		return BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_ORANGE).replaceable().noCollision().instabreak()
				.sound(SoundType.PINK_PETALS).offsetType(BlockBehaviour.OffsetType.XYZ).ignitedByLava().pushReaction(PushReaction.POPPED);
	}

	private static boolean never(net.minecraft.world.level.block.state.BlockState s, net.minecraft.world.level.BlockGetter l, net.minecraft.core.BlockPos p) {
		return false;
	}

	private static Block register(String name, Function<BlockBehaviour.Properties, Block> factory, BlockBehaviour.Properties properties) {
		return register(name, factory, properties, UnaryOperator.identity());
	}

	private static Block register(String name, Function<BlockBehaviour.Properties, Block> factory, BlockBehaviour.Properties properties,
			UnaryOperator<Item.Properties> item) {
		Block block = registerNoItem(name, factory, properties);
		ModItems.registerBlockItem(block, item);
		return block;
	}

	/** Composts as flowers and mushrooms do. */
	private static Item.Properties compostMedium(Item.Properties properties) {
		return properties.compostable(ContextIntProviders.COMPOSTABLE_MEDIUM);
	}

	private static Block registerNoItem(String name, Function<BlockBehaviour.Properties, Block> factory, BlockBehaviour.Properties properties) {
		ResourceKey<Block> key = ResourceKey.create(Registries.BLOCK, TheSift.id(name));
		return Registry.register(BuiltInRegistries.BLOCK, key, factory.apply(properties.setId(key)));
	}

	public static void init() {
		// Class loading registers the fields above. The chime bell burns as poppies do (FireBlock: ignite 60, burn 100);
		// the tide plants, the glowcap and the lumen bloom don't burn (block_flora_ii.md).
		FlammableBlockRegistry.getDefaultInstance().add(CHIME_BELL_FLOWER, 60, 100);
	}
}
