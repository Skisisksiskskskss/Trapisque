package thesift.datagen;

import java.util.ArrayList;
import java.util.List;
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
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;

/** Blockstates, block models and item models for block set I (textures: WP-041). */
final class ModModelProvider extends FabricModelProvider {
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

		// Nylium-style: petalled top, fringed side, hymnstone bottom; 3 top variants x 4 rotations.
		List<Variant> sculk = new ArrayList<>();
		for (Variant top : textureVariants(g, ModBlocks.HEALTHY_SCULK, ModelTemplates.CUBE_BOTTOM_TOP, 3, sfx -> new TextureMapping()
				.put(TextureSlot.BOTTOM, TextureMapping.getBlockTexture(ModBlocks.HYMNSTONE))
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
		g.createPlantWithDefaultItem(ModBlocks.SONGWOOD_SAPLING, ModBlocks.POTTED_SONGWOOD_SAPLING, BlockModelGenerators.PlantType.NOT_TINTED);

		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.TIDE_SAND, BlockModelGenerators.variants(
				textureVariants(g, ModBlocks.TIDE_SAND, ModelTemplates.CUBE_ALL, 3, sfx -> TextureMapping.cube(TextureMapping.getBlockTexture(ModBlocks.TIDE_SAND, sfx))))));
		g.createTrivialBlock(ModBlocks.TIDE_VENT, TexturedModel.COLUMN);
		g.createTrivialBlock(ModBlocks.GATESTONE, TexturedModel.COLUMN.updateTexture(m -> m
				.put(TextureSlot.SIDE, TextureMapping.getBlockTexture(ModBlocks.GATESTONE))
				.put(TextureSlot.END, TextureMapping.getBlockTexture(ModBlocks.GATESTONE, "_top"))));
		g.createAirLikeBlock(ModBlocks.ICHOR, new Material(TheSift.id("block/ichor_still")));
		// Like the Nether portal: hand-written thin models (assets/thesift/models/block/sift_membrane_{ns,ew}.json).
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.SIFT_MEMBRANE).with(
				PropertyDispatch.initial(BlockStateProperties.HORIZONTAL_AXIS)
						.select(Direction.Axis.X, BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.SIFT_MEMBRANE, "_ns")))
						.select(Direction.Axis.Z, BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.SIFT_MEMBRANE, "_ew")))));
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
	}
}
