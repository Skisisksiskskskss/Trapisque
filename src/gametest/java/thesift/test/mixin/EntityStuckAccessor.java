package thesift.test.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;

import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.Vec3;

/** Test-only: reads the wading slowdown that ichor sets. */
@Mixin(Entity.class)
public interface EntityStuckAccessor {
	@Accessor("stuckSpeedMultiplier")
	Vec3 thesift$stuckSpeedMultiplier();
}
