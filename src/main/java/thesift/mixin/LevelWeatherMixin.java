package thesift.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.world.level.Level;

import thesift.world.SiftKeys;

/**
 * D-008: the Sift has no weather, and must not count down the server-global weather timers a second
 * time each tick. {@code Level.canHaveWeather()} gates both; the data-only route ({@code has_ceiling})
 * was rejected because it also changes maps and world-generation spawns.
 */
@Mixin(Level.class)
abstract class LevelWeatherMixin {
	@Inject(method = "canHaveWeather", at = @At("HEAD"), cancellable = true)
	private void thesift$noWeatherInTheSift(CallbackInfoReturnable<Boolean> cir) {
		if (SiftKeys.isSift((Level) (Object) this)) {
			cir.setReturnValue(false);
		}
	}
}
