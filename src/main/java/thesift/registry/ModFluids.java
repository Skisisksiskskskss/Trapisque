package thesift.registry;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.material.FlowingFluid;

import thesift.TheSift;
import thesift.fluid.IchorFluid;

/** Fluids (D-019). */
public final class ModFluids {
	public static final FlowingFluid ICHOR = Registry.register(BuiltInRegistries.FLUID, TheSift.id("ichor"), new IchorFluid.Source());
	public static final FlowingFluid FLOWING_ICHOR = Registry.register(BuiltInRegistries.FLUID, TheSift.id("flowing_ichor"), new IchorFluid.Flowing());

	private ModFluids() {
	}

	public static void init() {
		// Class loading registers the fields above.
	}
}
