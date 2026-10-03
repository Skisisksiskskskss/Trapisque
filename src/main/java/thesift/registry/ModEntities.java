package thesift.registry;

import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.entity.SpawnPlacementTypes;
import net.minecraft.world.entity.SpawnPlacements;
import net.minecraft.world.level.levelgen.Heightmap;

import thesift.TheSift;
import thesift.entity.blub.Blub;
import thesift.entity.nester.Nester;

/** Entity types (D-019). */
public final class ModEntities {
	public static final ResourceKey<EntityType<?>> BLUB_KEY = ResourceKey.create(Registries.ENTITY_TYPE, TheSift.id("blub"));
	/** 0.5 x 0.5 blocks: a third of a player's height (mob_blub.md). */
	public static final EntityType<Blub> BLUB = Registry.register(BuiltInRegistries.ENTITY_TYPE, BLUB_KEY,
			EntityType.Builder.of(Blub::new, MobCategory.CREATURE).sized(0.55F, 0.5F).eyeHeight(0.35F)
					.passengerAttachments(0.5F).clientTrackingRange(8).build(BLUB_KEY));

	public static final ResourceKey<EntityType<?>> NESTER_KEY = ResourceKey.create(Registries.ENTITY_TYPE, TheSift.id("nester"));
	/** 0.8 x 1.75 blocks: a boxy head on a thin neck and long legs, its eyes at a player's eyes (D-034). Gone in Peaceful. */
	public static final EntityType<Nester> NESTER = Registry.register(BuiltInRegistries.ENTITY_TYPE, NESTER_KEY,
			EntityType.Builder.of(Nester::new, MobCategory.MONSTER).sized(0.8F, 1.75F).eyeHeight(1.45F).notInPeaceful()
					.clientTrackingRange(8).build(NESTER_KEY));

	private ModEntities() {
	}

	public static void init() {
		FabricDefaultAttributeRegistry.register(BLUB, Blub.createAttributes());
		SpawnPlacements.register(BLUB, SpawnPlacementTypes.ON_GROUND, Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, Blub::checkBlubSpawnRules);
		FabricDefaultAttributeRegistry.register(NESTER, Nester.createAttributes());
		SpawnPlacements.register(NESTER, SpawnPlacementTypes.ON_GROUND, Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, Nester::checkNesterSpawnRules);
	}
}
