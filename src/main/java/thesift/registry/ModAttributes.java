package thesift.registry;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.attribute.AttributeTypes;
import net.minecraft.world.attribute.EnvironmentAttribute;

import thesift.TheSift;

/**
 * The Sift's own environment attributes (systems.md §1, D-013). They are keyframed by the
 * {@code thesift:tides} timeline and read with {@code level.environmentAttributes()}.
 */
public final class ModAttributes {
	/** The scope gate: true in the Sift in every Tide, false everywhere else. */
	public static final EnvironmentAttribute<Boolean> SIFT_LIFE = register("gameplay/sift_life",
			EnvironmentAttribute.builder(AttributeTypes.BOOLEAN).defaultValue(false).notPositional().syncable().build());

	/** A rate only: Thrive 1.0, Flow 0.25, Endure 0.0. It never switches a feature off. */
	public static final EnvironmentAttribute<Float> SOUL_FLOW = register("gameplay/soul_flow",
			EnvironmentAttribute.builder(AttributeTypes.FLOAT).defaultValue(0.0F).notPositional().syncable().build());

	/** The current Tide as {@link thesift.world.Tide#ordinal()}; -1 outside the Sift. */
	public static final EnvironmentAttribute<Integer> TIDE = register("gameplay/tide",
			EnvironmentAttribute.builder(AttributeTypes.INTEGER).defaultValue(-1).notPositional().syncable().build());

	private ModAttributes() {
	}

	private static <T> EnvironmentAttribute<T> register(String path, EnvironmentAttribute<T> attribute) {
		return Registry.register(BuiltInRegistries.ENVIRONMENT_ATTRIBUTE, TheSift.id(path), attribute);
	}

	public static void init() {
		// Class loading registers the fields above.
	}
}
