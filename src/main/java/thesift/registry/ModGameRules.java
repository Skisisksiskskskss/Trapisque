package thesift.registry;

import com.mojang.brigadier.arguments.BoolArgumentType;
import com.mojang.serialization.Codec;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.flag.FeatureFlagSet;
import net.minecraft.world.level.gamerules.GameRule;
import net.minecraft.world.level.gamerules.GameRuleCategory;
import net.minecraft.world.level.gamerules.GameRuleType;
import net.minecraft.world.level.gamerules.GameRuleTypeVisitor;

import thesift.TheSift;

/** Game rules (survival_sift.md §2.2, §3): set them in Create World → Game Rules, or with /gamerule. */
public final class ModGameRules {
	/** Natural rifts open near players in the Overworld and the Sift. */
	public static final GameRule<Boolean> SPAWN_RIFTS = bool("spawn_rifts", GameRuleCategory.SPAWNING, true);
	/** A player joining for the first time starts on the Sift's surface near 0, 0, their respawn point there. */
	public static final GameRule<Boolean> START_IN_SIFT = bool("start_in_sift", GameRuleCategory.PLAYER, false);

	private ModGameRules() {
	}

	private static GameRule<Boolean> bool(String name, GameRuleCategory category, boolean defaultValue) {
		return Registry.register(BuiltInRegistries.GAME_RULE, TheSift.id(name), new GameRule<>(category, GameRuleType.BOOL, BoolArgumentType.bool(),
				GameRuleTypeVisitor::visitBoolean, Codec.BOOL, b -> b ? 1 : 0, defaultValue, FeatureFlagSet.of()));
	}

	public static void init() {
		// Class loading registers the rules above.
	}
}
