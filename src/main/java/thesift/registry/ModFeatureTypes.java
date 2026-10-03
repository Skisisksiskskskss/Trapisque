package thesift.registry;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;

import thesift.TheSift;
import thesift.world.feature.DrapesDecorator;
import thesift.world.feature.HuskFossilFeature;
import thesift.world.feature.HymnstoneSpireFeature;
import thesift.world.feature.EndureBloomsFeature;
import thesift.world.feature.IchorFlatsFeature;
import thesift.world.feature.LumenBloomFeature;
import thesift.world.feature.TideBasinFeature;
import thesift.world.feature.TideRootsShoreFeature;

/** Our feature types (26.3: a feature type is the codec of a feature record). */
public final class ModFeatureTypes {
	static {
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("tide_basin"), TideBasinFeature.CODEC);
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("hymnstone_spire"), HymnstoneSpireFeature.CODEC);
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("ichor_flats"), IchorFlatsFeature.CODEC);
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("endure_blooms"), EndureBloomsFeature.CODEC);
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("lumen_bloom"), LumenBloomFeature.CODEC);
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("tide_roots_shore"), TideRootsShoreFeature.CODEC);
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("husk_fossil"), HuskFossilFeature.CODEC);
	}

	private ModFeatureTypes() {
	}

	public static void init() {
		// Class loading registers the types above.
		DrapesDecorator.init();
	}
}
