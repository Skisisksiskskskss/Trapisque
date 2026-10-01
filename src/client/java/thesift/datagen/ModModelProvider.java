package thesift.datagen;

import net.fabricmc.fabric.api.client.datagen.v1.provider.FabricModelProvider;
import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.minecraft.client.data.models.BlockModelGenerators;
import net.minecraft.client.data.models.ItemModelGenerators;
import net.minecraft.client.data.models.blockstates.MultiVariantGenerator;
import net.minecraft.client.data.models.blockstates.PropertyDispatch;
import net.minecraft.client.data.models.model.ModelLocationUtils;
import net.minecraft.core.Direction;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.client.data.models.model.ModelTemplates;
import net.minecraft.client.data.models.model.TextureMapping;
import net.minecraft.client.data.models.model.TextureSlot;
import net.minecraft.client.data.models.model.TexturedModel;
import net.minecraft.world.level.block.Block;

import thesift.registry.ModBlocks;

/** Blockstates, block models and item models for block set I (textures: WP-041). */
final class ModModelProvider extends FabricModelProvider {
	ModModelProvider(FabricPackOutput output) {
		super(output);
	}

	@Override
	public void generateBlockStateModels(BlockModelGenerators g) {
		g.createTrivialCube(ModBlocks.HYMNSTONE);
		g.family(ModBlocks.HYMNSTONE_BRICKS)
				.stairs(ModBlocks.HYMNSTONE_BRICK_STAIRS)
				.slab(ModBlocks.HYMNSTONE_BRICK_SLAB)
				.wall(ModBlocks.HYMNSTONE_BRICK_WALL);

		// Nylium-style: petalled top, fringed side, hymnstone bottom.
		cubeBottomTop(g, ModBlocks.HEALTHY_SCULK, new TextureMapping()
				.put(TextureSlot.BOTTOM, TextureMapping.getBlockTexture(ModBlocks.HYMNSTONE))
				.put(TextureSlot.TOP, TextureMapping.getBlockTexture(ModBlocks.HEALTHY_SCULK, "_top"))
				.put(TextureSlot.SIDE, TextureMapping.getBlockTexture(ModBlocks.HEALTHY_SCULK, "_side")));
		g.createCrossBlockWithDefaultItem(ModBlocks.HEALTHY_SCULK_GRASS, BlockModelGenerators.PlantType.NOT_TINTED);
		g.createDoublePlantWithDefaultItem(ModBlocks.TALL_HEALTHY_SCULK_GRASS, BlockModelGenerators.PlantType.NOT_TINTED);

		g.woodProvider(ModBlocks.SONGWOOD_LOG).log(ModBlocks.SONGWOOD_LOG);
		g.createTrivialCube(ModBlocks.SONGWOOD_PLANKS);
		g.createTrivialBlock(ModBlocks.SONGWOOD_LEAVES, TexturedModel.LEAVES);
		g.createPlantWithDefaultItem(ModBlocks.SONGWOOD_SAPLING, ModBlocks.POTTED_SONGWOOD_SAPLING, BlockModelGenerators.PlantType.NOT_TINTED);

		g.createTrivialCube(ModBlocks.TIDE_SAND);
		g.createTrivialBlock(ModBlocks.TIDE_VENT, TexturedModel.COLUMN);
		g.createTrivialBlock(ModBlocks.GATESTONE, TexturedModel.COLUMN.updateTexture(m -> m
				.put(TextureSlot.SIDE, TextureMapping.getBlockTexture(ModBlocks.GATESTONE))
				.put(TextureSlot.END, TextureMapping.getBlockTexture(ModBlocks.GATESTONE, "_top"))));
		// Like the Nether portal: hand-written thin models (assets/thesift/models/block/sift_membrane_{ns,ew}.json).
		g.blockStateOutput.accept(MultiVariantGenerator.dispatch(ModBlocks.SIFT_MEMBRANE).with(
				PropertyDispatch.initial(BlockStateProperties.HORIZONTAL_AXIS)
						.select(Direction.Axis.X, BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.SIFT_MEMBRANE, "_ns")))
						.select(Direction.Axis.Z, BlockModelGenerators.plainVariant(ModelLocationUtils.getModelLocation(ModBlocks.SIFT_MEMBRANE, "_ew")))));
	}

	private static void cubeBottomTop(BlockModelGenerators g, Block block, TextureMapping mapping) {
		g.blockStateOutput.accept(BlockModelGenerators.createSimpleBlock(block,
				BlockModelGenerators.plainVariant(ModelTemplates.CUBE_BOTTOM_TOP.create(block, mapping, g.modelOutput))));
	}

	@Override
	public void generateItemModels(ItemModelGenerators g) {
	}
}
