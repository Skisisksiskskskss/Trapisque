package thesift.datagen;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.function.Function;

import net.fabricmc.fabric.api.client.datagen.v1.provider.FabricModelProvider;
import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.minecraft.client.data.models.BlockModelGenerators;
import net.minecraft.client.data.models.ItemModelGenerators;
import net.minecraft.client.data.models.blockstates.MultiVariantGenerator;
import net.minecraft.client.data.models.blockstates.PropertyDispatch;
import net.minecraft.client.data.models.model.ModelLocationUtils;
import net.minecraft.client.resources.model.sprite.Material;
import net.minecraft.core.Direction;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.client.data.models.model.ModelTemplate;
import net.minecraft.client.data.models.model.ModelTemplates;
import net.minecraft.client.renderer.block.dispatch.Variant;
import net.minecraft.resources.Identifier;
import net.minecraft.client.data.models.model.TextureMapping;
import net.minecraft.client.data.models.model.TextureSlot;
import net.minecraft.client.data.models.model.TexturedModel;
import net.minecraft.world.level.block.Block;

import thesift.TheSift;
import thesift.block.ChimeBellFlowerBlock;
import thesift.block.TideFloraBlock;
import thesift.block.TideRootsBlock;
import thesift.block.TidewrackBlock;
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;

/** Blockstates, block models and item models for block set I (textures: WP-041). */
final class ModModelProvider extends FabricModelProvider {
	private static final TextureSlot PLANT_EMISSIVE = TextureSlot.create("plant_emissive");
	private static final ModelTemplate FLAT_PLANT = template("template_flat_plant", TextureSlot.PLANT);
	private static final ModelTemplate FLAT_PLANT_CROSS = template("template_flat_plant_cross", TextureSlot.PLANT, TextureSlot.CROSS);
	private static final ModelTemplate FLAT_PLANT_EMISSIVE = template("template_flat_plant_emissive", TextureSlot.PLANT, PLANT_EMISSIVE);

	private static ModelTemplate template(String name, TextureSlot... slots) {
		return new ModelTemplate(Optional.of(TheSift.id("block/" + name)), Optional.empty(), slots);
	}

	ModModelProvider(FabricPackOutput output) {
		super(output);
	}

	@Override
	public void generateBlockStateModels(BlockModelGenerators g) {
		// Ground blocks get texture variants (and sculk tops random rotations) so no grid shows (palette.md).
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.HYMNSTONE, BlockModelGenerators.variants(
				textureVariants(g, ModBlocks.HYMNSTONE, ModelTemplates.CUBE_ALL, 3, sfx -> TextureMapping.cube(TextureMapping.getBlockTexture(ModBlocks.HYMNSTONE, sfx))))));
		g.family(ModBlocks.HYMNSTONE_BRICKS)
				.stairs(ModBlocks.HYMNSTONE_BRICK_STAIRS)
				.slab(ModBlocks.HYMNSTONE_BRICK_SLAB)
				.wall(ModBlocks.HYMNSTONE_BRICK_WALL);
		g.createTrivialCube(ModBlocks.CRACKED_HYMNSTONE_BRICKS);
		g.createTrivialCube(ModBlocks.CHISELED_HYMNSTONE_BRICKS);
		hymnstoneCuts(g);
		// The Carapace (D-035).
		g.createTrivialCube(ModBlocks.CARAPACE_STONE);
		g.createTrivialCube(ModBlocks.SIFT_DUST);
		g.createAxisAlignedPillarBlock(ModBlocks.HUSK_BONE_BLOCK, TexturedModel.COLUMN);
		g.createCrossBlockWithDefaultItem(ModBlocks.RED_CARAPACE_GRASS, BlockModelGenerators.PlantType.NOT_TINTED);
		g.createCrossBlockWithDefaultItem(ModBlocks.YELLOW_CARAPACE_GRASS, BlockModelGenerators.PlantType.NOT_TINTED);
		g.family(ModBlocks.COBBLED_HYMNSTONE)
				.stairs(ModBlocks.COBBLED_HYMNSTONE_STAIRS)
				.slab(ModBlocks.COBBLED_HYMNSTONE_SLAB)
				.wall(ModBlocks.COBBLED_HYMNSTONE_WALL);
		g.family(ModBlocks.SMOOTH_HYMNSTONE).slab(ModBlocks.SMOOTH_HYMNSTONE_SLAB);
		g.family(ModBlocks.POLISHED_HYMNSTONE)
				.stairs(ModBlocks.POLISHED_HYMNSTONE_STAIRS)
				.slab(ModBlocks.POLISHED_HYMNSTONE_SLAB)
				.wall(ModBlocks.POLISHED_HYMNSTONE_WALL);

		// Grass-style: speckled top, fringed side, soil bottom; 3 top variants x 4 rotations.
		g.createTrivialCube(ModBlocks.SIFT_SOIL);
		List<Variant> sculk = new ArrayList<>();
		for (Variant top : textureVariants(g, ModBlocks.HEALTHY_SCULK, ModelTemplates.CUBE_BOTTOM_TOP, 3, sfx -> new TextureMapping()
				.put(TextureSlot.BOTTOM, TextureMapping.getBlockTexture(ModBlocks.SIFT_SOIL))
				.put(TextureSlot.TOP, TextureMapping.getBlockTexture(ModBlocks.HEALTHY_SCULK, "_top" + sfx))
				.put(TextureSlot.SIDE, TextureMapping.getBlockTexture(ModBlocks.HEALTHY_SCULK, "_side")))) {
			sculk.addAll(List.of(top, top.with(BlockModelGenerators.Y_ROT_90), top.with(BlockModelGenerators.Y_ROT_180), top.with(BlockModelGenerators.Y_ROT_270)));
		}
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.HEALTHY_SCULK, BlockModelGenerators.variants(sculk.toArray(Variant[]::new))));
		g.createCrossBlockWithDefaultItem(ModBlocks.HEALTHY_SCULK_GRASS, BlockModelGenerators.PlantType.NOT_TINTED);
		g.createDoublePlantWithDefaultItem(ModBlocks.TALL_HEALTHY_SCULK_GRASS, BlockModelGenerators.PlantType.NOT_TINTED);

		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.SONGWOOD_LOG, BlockModelGenerators.variants(
				textureVariants(g, ModBlocks.SONGWOOD_LOG, ModelTemplates.CUBE_COLUMN, 2, sfx -> new TextureMapping()
						.put(TextureSlot.SIDE, TextureMapping.getBlockTexture(ModBlocks.SONGWOOD_LOG, sfx))
						.put(TextureSlot.END, TextureMapping.getBlockTexture(ModBlocks.SONGWOOD_LOG, "_top")))))
				.with(BlockModelGenerators.createRotatedPillar()));
		g.createTrivialCube(ModBlocks.SONGWOOD_PLANKS);
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.SONGWOOD_LEAVES, BlockModelGenerators.variants(
				textureVariants(g, ModBlocks.SONGWOOD_LEAVES, ModelTemplates.LEAVES, 2, sfx -> TextureMapping.cube(TextureMapping.getBlockTexture(ModBlocks.SONGWOOD_LEAVES, sfx))))));
		g.createHangingMoss(ModBlocks.SONGWOOD_DRAPES);
		g.createPlantWithDefaultItem(ModBlocks.SONGWOOD_SAPLING, ModBlocks.POTTED_SONGWOOD_SAPLING, BlockModelGenerators.PlantType.NOT_TINTED);

		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.TIDE_SAND, BlockModelGenerators.variants(
				textureVariants(g, ModBlocks.TIDE_SAND, ModelTemplates.CUBE_ALL, 3, sfx -> TextureMapping.cube(TextureMapping.getBlockTexture(ModBlocks.TIDE_SAND, sfx))))));
		g.createTrivialBlock(ModBlocks.TIDE_VENT, TexturedModel.COLUMN);
		g.createTrivialBlock(ModBlocks.GATESTONE, TexturedModel.COLUMN.updateTexture(m -> m
				.put(TextureSlot.SIDE, TextureMapping.getBlockTexture(ModBlocks.GATESTONE))
				.put(TextureSlot.END, TextureMapping.getBlockTexture(ModBlocks.GATESTONE, "_top"))));
		g.createAirLikeBlock(ModBlocks.ICHOR, new Material(TheSift.id("block/ichor_still")));
		flora(g);
		// Like the Nether portal: hand-written thin models (assets/thesift/models/block/sift_membrane_{ns,ew}.json).
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.SIFT_MEMBRANE).with(
				PropertyDispatch.initial(BlockStateProperties.HORIZONTAL_AXIS)
						.select(Direction.Axis.X, BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.SIFT_MEMBRANE, "_ns")))
						.select(Direction.Axis.Z, BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.SIFT_MEMBRANE, "_ew")))));
	}

	/** Flora II (block_flora_ii.md): flat plants lie on the ground (hand-written parents in assets/thesift/models/block). */
	private static void flora(BlockModelGenerators g) {
		// Tidewrack: a flat knot with a low cross when closed; ribbons spread flat when open; bare stems when picked.
		Identifier wrackClosed = FLAT_PLANT_CROSS.createWithSuffix(ModBlocks.TIDEWRACK, "_closed", new TextureMapping()
				.put(TextureSlot.PLANT, TextureMapping.getBlockTexture(ModBlocks.TIDEWRACK, "_closed"))
				.put(TextureSlot.CROSS, TextureMapping.getBlockTexture(ModBlocks.TIDEWRACK, "_knot")), g.modelOutput);
		Identifier wrackOpen = FLAT_PLANT.create(ModBlocks.TIDEWRACK, plant(ModBlocks.TIDEWRACK, ""), g.modelOutput);
		Identifier wrackPicked = FLAT_PLANT.createWithSuffix(ModBlocks.TIDEWRACK, "_picked", plant(ModBlocks.TIDEWRACK, "_picked"), g.modelOutput);
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.TIDEWRACK).with(
				PropertyDispatch.initial(TideFloraBlock.OPEN, TideFloraBlock.PICKED_CYCLE, TidewrackBlock.SUBMERGED).generate((open, picked, submerged) ->
						BlockModelGenerators.plainVariant(!open ? wrackClosed : picked == 0 ? wrackOpen : wrackPicked))));
		g.registerSimpleFlatItemModel(ModBlocks.TIDEWRACK);

		// The Endure bloom: a flat rosette when closed; open, a star whose centre and petal edges are emissive.
		Identifier bloomClosed = FLAT_PLANT.createWithSuffix(ModBlocks.ENDURE_BLOOM, "_closed", plant(ModBlocks.ENDURE_BLOOM, "_closed"), g.modelOutput);
		Identifier bloomOpen = FLAT_PLANT_EMISSIVE.create(ModBlocks.ENDURE_BLOOM, plant(ModBlocks.ENDURE_BLOOM, "")
				.put(PLANT_EMISSIVE, TextureMapping.getBlockTexture(ModBlocks.ENDURE_BLOOM, "_emissive")), g.modelOutput);
		Identifier bloomPicked = FLAT_PLANT.createWithSuffix(ModBlocks.ENDURE_BLOOM, "_picked", plant(ModBlocks.ENDURE_BLOOM, "_picked"), g.modelOutput);
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.ENDURE_BLOOM).with(
				PropertyDispatch.initial(TideFloraBlock.OPEN, TideFloraBlock.PICKED_CYCLE).generate((open, picked) ->
						BlockModelGenerators.plainVariant(!open ? bloomClosed : picked == 0 ? bloomOpen : bloomPicked))));
		g.registerSimpleFlatItemModel(ModBlocks.ENDURE_BLOOM);

		g.createPlantWithDefaultItem(ModBlocks.GLOWCAP, ModBlocks.POTTED_GLOWCAP, BlockModelGenerators.PlantType.NOT_TINTED);

		// The chime bell: its bells swing while it rings.
		Identifier chime = ModelTemplates.CROSS.create(ModBlocks.CHIME_BELL_FLOWER, TextureMapping.cross(ModBlocks.CHIME_BELL_FLOWER), g.modelOutput);
		Identifier chimeRinging = ModelTemplates.CROSS.createWithSuffix(ModBlocks.CHIME_BELL_FLOWER, "_ringing",
				TextureMapping.cross(TextureMapping.getBlockTexture(ModBlocks.CHIME_BELL_FLOWER, "_ringing")), g.modelOutput);
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.CHIME_BELL_FLOWER).with(
				PropertyDispatch.initial(ChimeBellFlowerBlock.RINGING).generate(ringing -> BlockModelGenerators.plainVariant(ringing ? chimeRinging : chime))));
		g.registerSimpleFlatItemModel(ModBlocks.CHIME_BELL_FLOWER);
		Identifier pottedChime = ModelTemplates.FLOWER_POT_CROSS.create(ModBlocks.POTTED_CHIME_BELL_FLOWER,
				TextureMapping.plant(ModBlocks.CHIME_BELL_FLOWER), g.modelOutput);
		g.blockStateOutput.accept(BlockModelGenerators.createSimpleBlock(ModBlocks.POTTED_CHIME_BELL_FLOWER, BlockModelGenerators.plainVariant(pottedChime)));

		// The lumen bloom: glassy petals splayed flat around a low core.
		Identifier lumen = FLAT_PLANT_CROSS.create(ModBlocks.LUMEN_BLOOM, plant(ModBlocks.LUMEN_BLOOM, "")
				.put(TextureSlot.CROSS, TextureMapping.getBlockTexture(ModBlocks.LUMEN_BLOOM, "_core")), g.modelOutput);
		g.blockStateOutput.accept(BlockModelGenerators.createSimpleBlock(ModBlocks.LUMEN_BLOOM, BlockModelGenerators.plainVariant(lumen)));
		g.registerSimpleFlatItemModel(ModBlocks.LUMEN_BLOOM);
		g.createLantern(ModBlocks.LUMEN_LANTERN);
		// Living in the Sift: ores, the tide-root crop.
		for (Block ore : new Block[] {ModBlocks.HYMNSTONE_COAL_ORE, ModBlocks.HYMNSTONE_COPPER_ORE, ModBlocks.HYMNSTONE_IRON_ORE, ModBlocks.HYMNSTONE_GOLD_ORE,
				ModBlocks.HYMNSTONE_REDSTONE_ORE, ModBlocks.HYMNSTONE_LAPIS_ORE, ModBlocks.HYMNSTONE_DIAMOND_ORE, ModBlocks.HYMNSTONE_EMERALD_ORE, ModBlocks.ECHO_ORE}) {
			g.createTrivialCube(ore);
		}
		g.createCropBlock(ModBlocks.TIDE_ROOTS, TideRootsBlock.AGE, 0, 1, 2, 3);
		// The ichor lily: a hand-made model (a pad with a glowing bud), turned at random as lily pads are.
		g.createRotatedVariantBlock(ModBlocks.ICHOR_LILY, TheSift.id("block/ichor_lily"));
		g.registerSimpleFlatItemModel(ModBlocks.ICHOR_LILY.asItem());
	}

	private static TextureMapping plant(Block block, String suffix) {
		return new TextureMapping().put(TextureSlot.PLANT, TextureMapping.getBlockTexture(block, suffix));
	}

	/** Hymnstone's stairs and slab: by hand, as hymnstone's own blockstate picks among texture variants (no family full block). */
	private static void hymnstoneCuts(BlockModelGenerators g) {
		TextureMapping hymnstone = TextureMapping.cube(ModBlocks.HYMNSTONE);
		Block stairs = ModBlocks.HYMNSTONE_STAIRS;
		Identifier straight = ModelTemplates.STAIRS_STRAIGHT.create(stairs, hymnstone, g.modelOutput);
		g.blockStateOutput.accept(BlockModelGenerators.createStairs(stairs,
				BlockModelGenerators.plainVariant(ModelTemplates.STAIRS_INNER.create(stairs, hymnstone, g.modelOutput)),
				BlockModelGenerators.plainVariant(straight),
				BlockModelGenerators.plainVariant(ModelTemplates.STAIRS_OUTER.create(stairs, hymnstone, g.modelOutput))));
		g.registerSimpleItemModel(stairs, straight);
		Block slab = ModBlocks.HYMNSTONE_SLAB;
		Identifier bottom = ModelTemplates.SLAB_BOTTOM.create(slab, hymnstone, g.modelOutput);
		g.blockStateOutput.accept(BlockModelGenerators.createSlab(slab, BlockModelGenerators.plainVariant(bottom),
				BlockModelGenerators.plainVariant(ModelTemplates.SLAB_TOP.create(slab, hymnstone, g.modelOutput)),
				BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.HYMNSTONE))));
		g.registerSimpleItemModel(slab, bottom);
	}

	/**
	 * Models for texture variants {@code <name>}, {@code <name>_2}, ... of one template; the first keeps
	 * the plain name, so the item model still finds it.
	 */
	private static Variant[] textureVariants(BlockModelGenerators g, Block block, ModelTemplate template, int count,
			Function<String, TextureMapping> mapping) {
		Variant[] out = new Variant[count];
		for (int i = 0; i < count; i++) {
			String suffix = i == 0 ? "" : "_" + (i + 1);
			Identifier model = i == 0
					? template.create(block, mapping.apply(suffix), g.modelOutput)
					: template.createWithSuffix(block, suffix, mapping.apply(suffix), g.modelOutput);
			out[i] = BlockModelGenerators.plainModel(model);
		}
		return out;
	}

	@Override
	public void generateItemModels(ItemModelGenerators g) {
		g.generateFlatItem(ModItems.ICHOR_BUCKET, ModelTemplates.FLAT_ITEM);
		g.generateFlatItem(ModItems.BLUB_SPAWN_EGG, ModelTemplates.FLAT_ITEM);
		// The tide root's flat item model comes with its crop (createCropBlock), as the carrot's does.
		for (Item food : new Item[] {ModItems.BAKED_TIDE_ROOT, ModItems.SONGFRUIT, ModItems.GLOWCAP_STEW}) {
			g.generateFlatItem(food, ModelTemplates.FLAT_ITEM);
		}
		g.generateFlatItem(ModItems.NESTER_SPAWN_EGG, ModelTemplates.FLAT_ITEM);
		g.generateFlatItem(ModItems.RIFT_FORK, ModelTemplates.FLAT_HANDHELD_ITEM);
		g.generateFlatItem(ModItems.TIDEWRACK_FROND, ModelTemplates.FLAT_ITEM);
		g.generateFlatItem(ModItems.ENDURE_PETAL, ModelTemplates.FLAT_ITEM);
	}
}
