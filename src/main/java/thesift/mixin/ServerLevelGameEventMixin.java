package thesift.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.core.Holder;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.Vec3;

import thesift.entry.FrameMusic;

/**
 * Lets awake frames hear music (entry_path.md §5). Every game event in a server level passes
 * here; {@link FrameMusic#onGameEvent} returns at once unless it is a note block, goat horn or
 * jukebox. Fabric API has no game-event hook, and a listener block entity per frame would mean
 * adding blocks to the Ancient City.
 */
@Mixin(ServerLevel.class)
abstract class ServerLevelGameEventMixin {
	@Inject(method = "gameEvent(Lnet/minecraft/core/Holder;Lnet/minecraft/world/phys/Vec3;Lnet/minecraft/world/level/gameevent/GameEvent$Context;)V", at = @At("HEAD"))
	private void thesift$hearMusic(Holder<GameEvent> gameEvent, Vec3 position, GameEvent.Context context, CallbackInfo ci) {
		FrameMusic.onGameEvent((ServerLevel) (Object) this, gameEvent, position);
	}
}
