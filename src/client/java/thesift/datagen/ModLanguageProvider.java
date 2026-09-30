package thesift.datagen;

import java.util.concurrent.CompletableFuture;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricLanguageProvider;
import net.minecraft.core.HolderLookup;

/** English (en_us) strings. Every player-facing string in the mod is added here. */
final class ModLanguageProvider extends FabricLanguageProvider {
	ModLanguageProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, "en_us", registries);
	}

	@Override
	public void generateTranslations(HolderLookup.Provider registries, TranslationBuilder builder) {
		builder.add("thesift.disclaimer", "Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.");
		builder.add("thesift.bed.no_sleep", "You can't sleep here: the Sift never goes quiet");
		builder.add("thesift.bed.rested", "You rest a while. The Tide keeps turning.");
	}
}
