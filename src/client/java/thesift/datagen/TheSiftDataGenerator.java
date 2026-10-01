package thesift.datagen;

import net.fabricmc.fabric.api.datagen.v1.DataGeneratorEntrypoint;
import net.fabricmc.fabric.api.datagen.v1.FabricDataGenerator;
import net.minecraft.core.RegistrySetBuilder;
import net.minecraft.core.registries.Registries;

/**
 * Data generation entrypoint (D-019). Every JSON file the mod ships is produced here and committed
 * under {@code src/main/generated}; {@code tools/dev/datagen-check.sh} fails if a second run differs.
 */
public final class TheSiftDataGenerator implements DataGeneratorEntrypoint {
	@Override
	public void onInitializeDataGenerator(FabricDataGenerator generator) {
		FabricDataGenerator.Pack pack = generator.createPack();
		pack.addProvider(ModLanguageProvider::new);
		pack.addProvider(ModWorldgenProvider::new);
		pack.addProvider(ModModelProvider::new);
		pack.addProvider(ModLootProvider::new);
		pack.addProvider(ModTagProviders.Blocks::new);
		pack.addProvider(ModTagProviders.Items::new);
		pack.addProvider(ModTagProviders.EntityTypes::new);
		pack.addProvider(ModTagProviders.Fluids::new);
		pack.addProvider(ModRecipeProvider::new);
	}

	@Override
	public void buildRegistry(RegistrySetBuilder builder) {
		builder.add(Registries.WORLD_CLOCK, SiftWorldgen::clocks);
		builder.add(Registries.TIMELINE, SiftWorldgen::timelines);
		builder.add(Registries.DIMENSION_TYPE, SiftWorldgen::dimensionTypes);
		builder.add(Registries.MATERIAL_RULE, SiftWorldgen::materialRules);
		builder.add(Registries.NOISE_SETTINGS, SiftWorldgen::noiseSettings);
		builder.add(Registries.FEATURE, SiftWorldgen::features);
		builder.add(Registries.PLACED_FEATURE, SiftWorldgen::placedFeatures);
		builder.add(Registries.BIOME, SiftWorldgen::biomes);
		builder.add(Registries.LEVEL_STEM, SiftWorldgen::levelStems);
	}
}
