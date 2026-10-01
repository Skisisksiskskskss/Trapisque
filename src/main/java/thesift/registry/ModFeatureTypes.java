package thesift.registry;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;

import thesift.TheSift;
import thesift.world.feature.TideBasinFeature;

/** Our feature types (26.3: a feature type is the codec of a feature record). */
public final class ModFeatureTypes {
	static {
		Registry.register(BuiltInRegistries.FEATURE_TYPE, TheSift.id("tide_basin"), TideBasinFeature.CODEC);
	}

	private ModFeatureTypes() {
	}

	public static void init() {
		// Class loading registers the types above.
	}
}
