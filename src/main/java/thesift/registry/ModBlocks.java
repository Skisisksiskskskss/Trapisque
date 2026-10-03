package thesift.registry;

import java.util.function.Function;
import java.util.function.UnaryOperator;

import net.fabricmc.fabric.api.registry.FlammableBlockRegistry;
import net.minecraft.core.Registry;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.util.random.WeightedList;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.HangingMossBlock;
import net.minecraft.world.level.block.FlowerPotBlock;
import net.minecraft.world.level.block.LanternBlock;
import net.minecraft.world.level.block.LiquidBlock;
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
import thesift.block.ChimeBellFlowerBlock;
import thesift.block.EndureBloomBlock;
import thesift.block.GlowcapBlock;
import thesift.block.HealthySculkBlock;
import thesift.block.HealthySculkGrassBlock;
import thesift.block.IchorLilyBlock;
import thesift.block.LumenBloomBlock;
import thesift.block.SiftMembraneBlock;
import thesift.block.SongwoodLogBlock;
import thesift.block.SongwoodSaplingBlock;
import thesift.block.TideVentBlock;
import thesift.block.TallHealthySculkGrassBlock;
import thesift.block.TidewrackBlock;
import thesift.world.SiftFeatures;

/** Block set I (world.md §3; M1). Registration mirrors vanilla's {@code Blocks.register} (D-019). */
public final class ModBlocks {
	public static final Block HYMNSTONE = register("hymnstone", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.TERRACOTTA_RED).instrument(NoteBlockInstrument.BASEDRUM)
			.requiresCorrectToolForDrops().strength(1.5F, 6.0F).sound(SoundType.CALCITE));
	public static final Block HYMNSTONE_BRICKS = register("hymnstone_bricks", Block::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE));
	public static final Block HYMNSTONE_BRICK_STAIRS = register("hymnstone_brick_stairs",
			p -> new StairBlock(HYMNSTONE_BRICKS.defaultBlockState(), p), BlockBehaviour.Properties.ofFullCopy(HYMNSTONE_BRICKS));
	public static final Block HYMNSTONE_BRICK_SLAB = register("hymnstone_brick_slab", SlabBlock::new, BlockBehaviour.Properties.ofFullCopy(HYMNSTONE_BRICKS));
	public static final Block HYMNSTONE_BRICK_WALL = register("hymnstone_brick_wall", WallBlock::new,
			BlockBehaviour.Properties.ofFullCopy(HYMNSTONE_BRICKS).forceSolidOn());

	/** The Sift's grass (owner rework: the teaser's pink-coral ground), over Sift soil as grass over dirt. */
	public static final Block HEALTHY_SCULK = register("healthy_sculk", HealthySculkBlock::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.COLOR_PINK).strength(0.6F).sound(SoundType.GRASS).randomTicks());
	/** Sift soil: the maroon earth under the grass, the Sift's dirt (the teaser's hill). */
	public static final Block SIFT_SOIL = register("sift_soil", Block::new, BlockBehaviour.Properties.of()
			.mapColor(MapColor.TERRACOTTA_BROWN).strength(0.5F).sound(SoundType.GRAVEL));
	public static final Block HEALTHY_SCULK_GRASS = register("healthy_sculk_grass", HealthySculkGrassBlock::new, plant());
	public static final Block TALL_HEALTHY_SCULK_GRASS = register("tall_healthy_sculk_grass", TallHealthySculkGrassBlock::new, plant());

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
