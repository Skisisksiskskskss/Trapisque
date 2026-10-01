package thesift.client.fog;

import org.joml.Vector3fc;
import org.jspecify.annotations.Nullable;

import net.minecraft.client.Camera;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.renderer.fog.FogData;
import net.minecraft.client.renderer.fog.environment.FogEnvironment;
import net.minecraft.core.BlockPos;
import net.minecraft.util.ARGB;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.level.material.FogType;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModTags;

/**
 * The view from inside ichor (WP-044): a thick violet haze about two blocks deep, like lava's but
 * thinner, so a player who sinks in can still find the bank. Added to vanilla's fog environments
 * through the class tweaker (no mixin).
 */
public final class IchorFogEnvironment extends FogEnvironment {
	private static final Vector3fc COLOR = ARGB.vector3fFromRGB24(0x28174A);

	@Override
	public Vector3fc getBaseColor(ClientLevel level, Camera camera, int renderDistance, float partialTicks) {
		return COLOR;
	}

	@Override
	public void setupFog(FogData fog, Camera camera, ClientLevel level, float renderDistance, DeltaTracker deltaTracker) {
		if (camera.entity().isSpectator()) {
			fog.environmentalStart = -8.0F;
			fog.environmentalEnd = renderDistance * 0.5F;
		} else {
			fog.environmentalStart = 0.25F;
			fog.environmentalEnd = 2.5F;
		}
		fog.skyEnd = fog.environmentalEnd;
		fog.cloudEnd = fog.environmentalEnd;
	}

	@Override
	public boolean isApplicable(@Nullable FogType fogType, Entity entity) {
		return eyesInIchor(entity);
	}

	public static boolean eyesInIchor(Entity entity) {
		Vec3 eye = entity.getEyePosition();
		BlockPos pos = BlockPos.containing(eye);
		FluidState fluid = entity.level().getFluidState(pos);
		return fluid.is(ModTags.ICHOR) && eye.y < pos.getY() + fluid.getHeight(entity.level(), pos);
	}
}
