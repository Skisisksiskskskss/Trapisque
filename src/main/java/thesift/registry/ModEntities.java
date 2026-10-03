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
import thesift.entity.rift.RiftEntity;
import thesift.entity.singer.Singer;

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

	public static final ResourceKey<EntityType<?>> SINGER_KEY = ResourceKey.create(Registries.ENTITY_TYPE, TheSift.id("singer"));
	/** 0.9 × 2.4 blocks: tall, its tiny face high on a long neck (canon look, RESEARCH.md S-I8). One per grove; never spawns naturally. */
	public static final EntityType<Singer> SINGER = Registry.register(BuiltInRegistries.ENTITY_TYPE, SINGER_KEY,
			EntityType.Builder.of(Singer::new, MobCategory.CREATURE).sized(0.9F, 2.4F).eyeHeight(2.15F).clientTrackingRange(10).build(SINGER_KEY));
	public static final ResourceKey<EntityType<?>> RIFT_KEY = ResourceKey.create(Registries.ENTITY_TYPE, TheSift.id("rift"));
	/** 1.5 × 3 blocks: a tear a player walks into (survival_sift.md §2.1). Seen from 10 chunks off. */
	public static final EntityType<RiftEntity> RIFT = Registry.register(BuiltInRegistries.ENTITY_TYPE, RIFT_KEY,
			EntityType.Builder.<RiftEntity>of(RiftEntity::new, MobCategory.MISC).sized(1.5F, 3.0F).fireImmune().noLootTable()
					.clientTrackingRange(10).updateInterval(20).build(RIFT_KEY));

	private ModEntities() {
	}

	public static void init() {
		FabricDefaultAttributeRegistry.register(BLUB, Blub.createAttributes());
		SpawnPlacements.register(BLUB, SpawnPlacementTypes.ON_GROUND, Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, Blub::checkBlubSpawnRules);
		FabricDefaultAttributeRegistry.register(NESTER, Nester.createAttributes());
		FabricDefaultAttributeRegistry.register(SINGER, Singer.createAttributes());
		SpawnPlacements.register(NESTER, SpawnPlacementTypes.ON_GROUND, Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, Nester::checkNesterSpawnRules);
	}
}
