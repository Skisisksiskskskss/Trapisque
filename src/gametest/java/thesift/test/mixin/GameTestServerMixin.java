package thesift.test.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import com.llamalad7.mixinextras.sugar.Local;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

import net.minecraft.core.Registry;
import net.minecraft.core.registries.Registries;
import net.minecraft.gametest.framework.GameTestServer;
import net.minecraft.server.WorldLoader;
import net.minecraft.world.level.dimension.LevelStem;
import net.minecraft.world.level.levelgen.WorldDimensions;

/**
 * Test-only (never shipped): vanilla's GameTest server bakes its world with an empty dimension
 * registry, so datapack dimensions such as {@code thesift:the_sift} don't exist there. This hands it
 * the datapack dimensions, so {@code @GameTest(dimension = "thesift:the_sift")} can run.
 */
@Mixin(GameTestServer.class)
abstract class GameTestServerMixin {
	@WrapOperation(method = "*", at = @At(value = "INVOKE",
			target = "Lnet/minecraft/world/level/levelgen/WorldDimensions;bake(Lnet/minecraft/core/Registry;)Lnet/minecraft/world/level/levelgen/WorldDimensions$Complete;"))
	private static WorldDimensions.Complete thesift$includeDatapackDimensions(WorldDimensions dimensions, Registry<LevelStem> ignored,
			Operation<WorldDimensions.Complete> original, @Local(argsOnly = true) WorldLoader.DataLoadContext context) {
		return original.call(dimensions, context.datapackDimensions().lookupOrThrow(Registries.LEVEL_STEM));
	}
}
