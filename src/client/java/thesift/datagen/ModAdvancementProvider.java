package thesift.datagen;

import java.util.concurrent.CompletableFuture;
import java.util.function.Consumer;

import net.fabricmc.fabric.api.datagen.v1.FabricPackOutput;
import net.fabricmc.fabric.api.datagen.v1.provider.FabricAdvancementProvider;
import net.minecraft.advancements.Advancement;
import net.minecraft.advancements.AdvancementHolder;
import net.minecraft.advancements.AdvancementRequirements;
import net.minecraft.advancements.AdvancementType;
import net.minecraft.advancements.triggers.CriteriaTriggers;
import net.minecraft.advancements.triggers.ChangeDimensionTrigger;
import net.minecraft.advancements.triggers.ImpossibleTrigger;
import net.minecraft.advancements.triggers.InventoryChangeTrigger;
import net.minecraft.advancements.predicates.LocationPredicate;
import net.minecraft.advancements.triggers.PlayerTrigger;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.levelgen.structure.BuiltinStructures;

import thesift.TheSift;
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;
import thesift.world.SiftAdvancements;
import thesift.world.SiftKeys;

/** The Sift advancement tab (items.md §5): the four M1 entries, in vanilla's voice. */
final class ModAdvancementProvider extends FabricAdvancementProvider {
	ModAdvancementProvider(FabricPackOutput output, CompletableFuture<HolderLookup.Provider> registries) {
		super(output, registries);
	}

	@Override
	public void generateAdvancement(HolderLookup.Provider registries, Consumer<AdvancementHolder> out) {
		// The root: "be noticed by a frame" (FrameCues awards it), or simply walking an Ancient City, so
		// a city whose frame can't be found still opens the tab.
		AdvancementHolder root = Advancement.Builder.advancement()
				.rootDisplay(Items.REINFORCED_DEEPSLATE,
						Component.translatable("advancements.thesift.root.title"),
						Component.translatable("advancements.thesift.root.description"),
						TheSift.id("block/hymnstone_bricks"), AdvancementType.TASK, false, false, false)
				.addCriterion(SiftAdvancements.AWARDED, CriteriaTriggers.IMPOSSIBLE.createCriterion(new ImpossibleTrigger.TriggerInstance()))
				.addCriterion("in_ancient_city", PlayerTrigger.TriggerInstance.located(
						LocationPredicate.Builder.inStructure(registries.lookupOrThrow(Registries.STRUCTURE).getOrThrow(BuiltinStructures.ANCIENT_CITY))))
				.requirements(AdvancementRequirements.Strategy.OR)
				.build(SiftAdvancements.ROOT);
		out.accept(root);
		AdvancementHolder offering = Advancement.Builder.advancement()
				.parent(root)
				.display(Items.EXPERIENCE_BOTTLE,
						Component.translatable("advancements.thesift.an_offering.title"),
						Component.translatable("advancements.thesift.an_offering.description"),
						AdvancementType.TASK, true, true, false)
				.addCriterion(SiftAdvancements.AWARDED, CriteriaTriggers.IMPOSSIBLE.createCriterion(new ImpossibleTrigger.TriggerInstance()))
				.build(SiftAdvancements.OFFERING);
		out.accept(offering);
		AdvancementHolder enter = Advancement.Builder.advancement()
				.parent(offering)
				.display(ModBlocks.HEALTHY_SCULK.asItem(),
						Component.translatable("advancements.thesift.where_souls_drift.title"),
						Component.translatable("advancements.thesift.where_souls_drift.description"),
						AdvancementType.TASK, true, true, false)
				.addCriterion("entered_sift", ChangeDimensionTrigger.TriggerInstance.changedDimensionTo(SiftKeys.LEVEL))
				.build(SiftAdvancements.ENTER);
		out.accept(enter);
		AdvancementHolder tideTurns = Advancement.Builder.advancement()
				.parent(enter)
				.display(ModItems.ICHOR_BUCKET,
						Component.translatable("advancements.thesift.the_tide_turns.title"),
						Component.translatable("advancements.thesift.the_tide_turns.description"),
						AdvancementType.TASK, true, true, false)
				.addCriterion(SiftAdvancements.AWARDED, CriteriaTriggers.IMPOSSIBLE.createCriterion(new ImpossibleTrigger.TriggerInstance()))
				.build(SiftAdvancements.TIDE_TURNS);
		out.accept(tideTurns);
		AdvancementHolder lowTide = Advancement.Builder.advancement()
				.parent(enter)
				.display(ModItems.TIDEWRACK_FROND,
						Component.translatable("advancements.thesift.low_tide.title"),
						Component.translatable("advancements.thesift.low_tide.description"),
						AdvancementType.TASK, true, true, false)
				.addCriterion("has_frond", InventoryChangeTrigger.TriggerInstance.hasItems(ModItems.TIDEWRACK_FROND))
				.build(SiftAdvancements.LOW_TIDE);
		out.accept(lowTide);
	}
}
