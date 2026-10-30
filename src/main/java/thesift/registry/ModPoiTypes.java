package thesift.registry;

import net.fabricmc.fabric.api.object.builder.v1.world.poi.PoiHelper;
import net.minecraft.world.entity.ai.village.poi.PoiType;

import thesift.TheSift;

/**
 * {@code thesift:lumen} (system_hunt.md §6, §11): the blocks hunters keep away from. A hunter asks the
 * POI index "is there lumen within 6 of here?" for each destination; the lumen lantern (WP-065)
 * joins the lumen bloom here.
 */
public final class ModPoiTypes {
	public static final PoiType LUMEN = PoiHelper.register(TheSift.id("lumen"), 0, 1, ModBlocks.LUMEN_BLOOM, ModBlocks.LUMEN_LANTERN);

	private ModPoiTypes() {
	}

	public static void init() {
		// Class loading registers the field above.
	}
}
