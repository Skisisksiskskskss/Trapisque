package thesift.registry;

import java.util.Set;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.block.entity.BlockEntityType;

import thesift.TheSift;
import thesift.block.entity.TideVentBlockEntity;

/** Block entity types (D-019). */
public final class ModBlockEntities {
	public static final BlockEntityType<TideVentBlockEntity> TIDE_VENT = Registry.register(BuiltInRegistries.BLOCK_ENTITY_TYPE,
			TheSift.id("tide_vent"), new BlockEntityType<>(TideVentBlockEntity::new, Set.of(ModBlocks.TIDE_VENT)));

	private ModBlockEntities() {
	}

	public static void init() {
		// Class loading registers the fields above.
	}
}
