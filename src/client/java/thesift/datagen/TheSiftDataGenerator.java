package thesift.datagen;

import net.fabricmc.fabric.api.datagen.v1.DataGeneratorEntrypoint;
import net.fabricmc.fabric.api.datagen.v1.FabricDataGenerator;

/**
 * Data generation entrypoint (D-019). Every JSON file the mod ships is produced here and committed
 * under {@code src/main/generated}; {@code tools/dev/datagen-check.sh} fails if a second run differs.
 */
public final class TheSiftDataGenerator implements DataGeneratorEntrypoint {
	@Override
	public void onInitializeDataGenerator(FabricDataGenerator generator) {
		FabricDataGenerator.Pack pack = generator.createPack();
		pack.addProvider(ModLanguageProvider::new);
	}
}
