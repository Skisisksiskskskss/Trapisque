package thesift.loot;

import java.util.Set;

import com.mojang.serialization.MapCodec;

import net.minecraft.util.context.ContextKey;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.loot.LootContext;
import net.minecraft.world.level.storage.loot.parameters.LootContextParams;
import net.minecraft.world.level.storage.loot.predicates.LootItemCondition;

import thesift.block.TideFloraBlock;

/**
 * {@code thesift:tide_flora_ready}: the broken block is a tide plant that is ready (open, not picked
 * this cycle, in its own Tide; block_flora_ii.md). The cycle stamp can't be compared by any vanilla
 * predicate, so the plants' block loot tables use this one.
 */
public record TideFloraReady() implements LootItemCondition {
	public static final TideFloraReady INSTANCE = new TideFloraReady();
	public static final MapCodec<TideFloraReady> CODEC = MapCodec.unit(INSTANCE);

	@Override
	public MapCodec<TideFloraReady> codec() {
		return CODEC;
	}

	@Override
	public Set<ContextKey<?>> getReferencedContextParams() {
		return Set.of(LootContextParams.BLOCK_STATE);
	}

	@Override
	public boolean test(LootContext context) {
		BlockState state = context.getOptional(LootContextParams.BLOCK_STATE);
		return state != null && state.getBlock() instanceof TideFloraBlock flora && flora.isReady(state, context.getLevel());
	}

	public static LootItemCondition.Builder ready() {
		return () -> INSTANCE;
	}
}
