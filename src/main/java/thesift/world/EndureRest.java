package thesift.world;

import java.util.List;

import net.fabricmc.fabric.api.entity.event.v1.EntitySleepEvents;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.stats.Stats;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

/**
 * Resting in a bed during Endure resets the phantom timer, as sleeping at night does at home (rules.md).
 * Nobody sleeps in the Sift, so this hooks the spawn-setting step of a bed use, which vanilla reaches
 * only after its range and obstruction checks. Like vanilla sleep, rest is refused while monsters that
 * prevent rest are near (the same box as {@code ServerPlayer.startSleepInBed}).
 */
public final class EndureRest {
	private EndureRest() {
	}

	public static void init() {
		EntitySleepEvents.ALLOW_SETTING_SPAWN.register(EndureRest::onBedUse);
	}

	private static boolean onBedUse(Player player, BlockPos bedPos) {
		if (player instanceof ServerPlayer serverPlayer && SiftKeys.isSift(serverPlayer.level())
				&& Tide.current(serverPlayer.level()) == Tide.ENDURE) {
			if (serverPlayer.isCreative() || !monstersNear(serverPlayer, bedPos)) {
				serverPlayer.resetStat(Stats.CUSTOM.get(Stats.TIME_SINCE_REST));
				if (serverPlayer.connection != null) { // null only for GameTest mock players
					serverPlayer.sendSystemMessage(Component.translatable("thesift.bed.rested"));
				}
			}
		}
		return true; // never blocks the spawn point: beds always set spawn in the Sift
	}

	static boolean monstersNear(ServerPlayer player, BlockPos bedPos) {
		Vec3 c = Vec3.atBottomCenterOf(bedPos);
		List<Monster> monsters = player.level().getEntitiesOfClass(Monster.class,
				new AABB(c.x() - 8.0, c.y() - 5.0, c.z() - 8.0, c.x() + 8.0, c.y() + 5.0, c.z() + 8.0),
				monster -> monster.isPreventingPlayerRest(player.level(), player));
		return !monsters.isEmpty();
	}
}
