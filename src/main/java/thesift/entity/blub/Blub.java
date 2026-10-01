package thesift.entity.blub;

import org.jspecify.annotations.Nullable;

import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.AgeableMob;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.TamableAnimal;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.FollowOwnerGoal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.ai.goal.SitWhenOrderedToGoal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.animal.Animal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;

/**
 * The Blub (mob_blub.md): the Sift's soft blue critter and pet. This is the WP-049 skeleton (body,
 * stats, vanilla pet goals); befriending by music, the echo, the Tide behaviours and stacking land in
 * WP-051 once the design is frozen.
 */
public class Blub extends TamableAnimal {
	public Blub(EntityType<? extends Blub> type, Level level) {
		super(type, level);
	}

	public static AttributeSupplier.Builder createAttributes() {
		return Animal.createAnimalAttributes()
				.add(Attributes.MAX_HEALTH, 8.0)
				.add(Attributes.MOVEMENT_SPEED, 0.25);
	}

	@Override
	protected void registerGoals() {
		this.goalSelector.addGoal(1, new FloatGoal(this));
		this.goalSelector.addGoal(1, new TamableAnimal.TamableAnimalPanicGoal(1.6));
		this.goalSelector.addGoal(2, new SitWhenOrderedToGoal(this));
		this.goalSelector.addGoal(3, new FollowOwnerGoal(this, 1.6, 6.0F, 2.0F));
		this.goalSelector.addGoal(8, new WaterAvoidingRandomStrollGoal(this, 1.0));
		this.goalSelector.addGoal(9, new LookAtPlayerGoal(this, Player.class, 6.0F));
		this.goalSelector.addGoal(10, new RandomLookAroundGoal(this));
	}

	/** No food until M2's tidewrack treats (mob_blub.md). */
	@Override
	public boolean isFood(ItemStack itemStack) {
		return false;
	}

	@Override
	public @Nullable AgeableMob getBreedOffspring(ServerLevel level, AgeableMob partner) {
		return null;
	}

	/** Blubs stack by riding each other, but a rider never steers the blub below (mob_blub.md, tech notes). */
	@Override
	public @Nullable LivingEntity getControllingPassenger() {
		return null;
	}
}
