package thesift.test.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

import net.minecraft.gametest.framework.GameTestServer;
import net.minecraft.util.RandomSource;

/**
 * Test-only (never shipped): vanilla's GameTest server lays its tests out from a random point (its world
 * seed is fixed), so each run builds them in different ground. In the Sift, at y 4, that ground can be
 * an aquifer of ichor or unlit stone, and a few tests failed only now and then. A fixed start makes
 * every run build in the same ground, so a test passes or fails the same way each time.
 */
@Mixin(GameTestServer.class)
abstract class GameTestStartMixin {
	private static final int START = 1_000_000;

	@WrapOperation(method = "startTests", at = @At(value = "INVOKE",
			target = "Lnet/minecraft/util/RandomSource;nextIntBetweenInclusive(II)I"))
	private int thesift$fixedStart(RandomSource random, int from, int to, Operation<Integer> original) {
		return START;
	}
}
