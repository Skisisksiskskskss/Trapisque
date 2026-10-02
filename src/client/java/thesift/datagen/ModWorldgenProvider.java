package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricDynamicRegistryProvider;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;

/** Writes our entries of every data-driven registry that {@link SiftWorldgen} bootstraps. */
final class ModWorldgenProvider extends FabricDynamicRegistryProvider {
	ModWorldgenProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries);
	}

	@Override
	protected void configure(HolderLookup.Provider registries, Entries entries) {
		entries.addAll(registries.lookupOrThrow(Registries.WORLD_CLOCK));
		entries.addAll(registries.lookupOrThrow(Registries.TIMELINE));
		entries.addAll(registries.lookupOrThrow(Registries.DIMENSION_TYPE));
		entries.addAll(registries.lookupOrThrow(Registries.DENSITY_FUNCTION));
		entries.addAll(registries.lookupOrThrow(Registries.MATERIAL_RULE));
		entries.addAll(registries.lookupOrThrow(Registries.NOISE_SETTINGS));
		entries.addAll(registries.lookupOrThrow(Registries.FEATURE));
		entries.addAll(registries.lookupOrThrow(Registries.PLACED_FEATURE));
		entries.addAll(registries.lookupOrThrow(Registries.BIOME));
		entries.addAll(registries.lookupOrThrow(Registries.LEVEL_STEM));
	}

	@Override
	public String getName() {
		return "The Sift worldgen";
	}
}
