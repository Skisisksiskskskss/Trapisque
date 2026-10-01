package thesift.registry;

import net.fabricmc.fabric.api.creativetab.v1.FabricCreativeModeTab;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.ItemStack;

import thesift.TheSift;

/** The Sift's creative tab. */
public final class ModCreativeTab {
	public static final CreativeModeTab TAB = Registry.register(BuiltInRegistries.CREATIVE_MODE_TAB, TheSift.id("the_sift"),
			FabricCreativeModeTab.builder()
					.title(Component.translatable("itemGroup.thesift"))
					.icon(() -> new ItemStack(ModBlocks.HEALTHY_SCULK))
					.displayItems((parameters, output) -> ModItems.creativeOrder().forEach(output::accept))
					.build());

	private ModCreativeTab() {
	}

	public static void init() {
		// Class loading registers the tab.
	}
}
