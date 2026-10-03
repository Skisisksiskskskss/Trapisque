package thesift.entity.singer;

import java.util.Optional;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.MoveTowardsRestrictionGoal;
import net.minecraft.world.entity.ai.goal.PanicGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;

import thesift.registry.ModSounds;
import thesift.world.Tide;

/**
 * The Singer (bible creatures.md §2, items.md §1.1; canon: "Singers are passive and can only communicate
 * through song"; the look from Dungeons II's ad, RESEARCH.md S-I8): a tall, shaggy, mint-green native,
 * one per grove. It hums broken phrases while its grove is silent and sings once the grove is restored;
 * it is silent in Endure. Hurt, it flees and falls silent for a full Tide cycle. It can't die: at zero
 * health it fades into its grove and returns at the next Thrive. It drops nothing.
 */
public class Singer extends PathfinderMob {
	private static final EntityDataAccessor<Boolean> DATA_FADED = SynchedEntityData.defineId(Singer.class, EntityDataSerializers.BOOLEAN);
	private static final EntityDataAccessor<Boolean> DATA_RESTORED = SynchedEntityData.defineId(Singer.class, EntityDataSerializers.BOOLEAN);
	private static final EntityDataAccessor<Integer> DATA_SINGING = SynchedEntityData.defineId(Singer.class, EntityDataSerializers.INT);
	/** It keeps within this many blocks of its grove heart. */
	public static final int HOME_RADIUS = 8;
	private @Nullable BlockPos home;
	private long silentUntil;
	private long returnAtClock = -1L;

	public Singer(EntityType<? extends Singer> type, Level level) {
		super(type, level);
		this.setPersistenceRequired();
	}

	public static AttributeSupplier.Builder createAttributes() {
		return PathfinderMob.createMobAttributes()
				.add(Attributes.MAX_HEALTH, 40.0)
				.add(Attributes.MOVEMENT_SPEED, 0.2)
				.add(Attributes.FOLLOW_RANGE, 16.0);
	}

	@Override
	protected void registerGoals() {
		this.goalSelector.addGoal(0, new FloatGoal(this));
		this.goalSelector.addGoal(1, new PanicGoal(this, 1.6));
		this.goalSelector.addGoal(2, new MoveTowardsRestrictionGoal(this, 0.8));
		this.goalSelector.addGoal(3, new LookAtPlayerGoal(this, Player.class, 10.0F));
		this.goalSelector.addGoal(4, new WaterAvoidingRandomStrollGoal(this, 0.6, 0.002F));
		this.goalSelector.addGoal(5, new RandomLookAroundGoal(this));
	}

	@Override
	protected void defineSynchedData(SynchedEntityData.Builder builder) {
		super.defineSynchedData(builder);
		builder.define(DATA_FADED, false);
		builder.define(DATA_RESTORED, false);
		builder.define(DATA_SINGING, 0);
	}

	/** Its grove heart: it keeps near it, and fades back to it. */
	public void setHome(BlockPos pos) {
		this.home = pos.immutable();
		this.setHomeTo(this.home, HOME_RADIUS);
	}

	public Optional<BlockPos> home() {
		return Optional.ofNullable(this.home);
	}

	public boolean faded() {
		return this.entityData.get(DATA_FADED);
	}

	public boolean restored() {
		return this.entityData.get(DATA_RESTORED);
	}

	public void setRestored(boolean restored) {
		this.entityData.set(DATA_RESTORED, restored);
	}

	/** Ticks of singing left (the arms lift, notes rise). */
	public int singing() {
		return this.entityData.get(DATA_SINGING);
	}

	/** Silent: faded, hurt within a Tide cycle, or in Endure. */
	public boolean silent() {
		return this.faded() || this.level().getGameTime() < this.silentUntil || Tide.current(this.level()) == Tide.ENDURE;
	}

	/** Sings {@code sound} for {@code ticks}, unless silent; returns whether it did. */
	public boolean sing(SoundEvent sound, int ticks, float pitch) {
		if (this.silent()) {
			return false;
		}
		this.playSound(sound, 2.0F, pitch);
		this.entityData.set(DATA_SINGING, ticks);
		return true;
	}

	@Override
	public void aiStep() {
		super.aiStep();
		int singing = this.singing();
		if (singing > 0 && !this.level().isClientSide()) {
			this.entityData.set(DATA_SINGING, singing - 1);
		}
		if (this.level().isClientSide() && singing > 0 && this.random.nextInt(4) == 0) {
			this.level().addParticle(ParticleTypes.NOTE, this.getX() + (this.random.nextDouble() - 0.5), this.getY() + 2.9,
					this.getZ() + (this.random.nextDouble() - 0.5), this.random.nextInt(24) / 24.0, 0.0, 0.0);
		}
		if (this.level() instanceof ServerLevel level && this.faded() && Tide.clockTicks(level) >= this.returnAtClock) {
			this.returnFromFade(level);
		}
	}

	@Override
	public boolean hurtServer(ServerLevel level, DamageSource source, float damage) {
		if (this.faded()) {
			return false;
		}
		if (!source.is(DamageTypeTags.BYPASSES_INVULNERABILITY) && damage >= this.getHealth()) {
			this.fade(level);
			return true;
		}
		boolean hurt = super.hurtServer(level, source, damage);
		if (hurt) {
			this.silentUntil = level.getGameTime() + Tide.PERIOD_TICKS; // silent for a full Tide cycle
			this.entityData.set(DATA_SINGING, 0);
		}
		return hurt;
	}

	/** At zero health: it fades into its grove (soul wisps, "Singer fades") until the next Thrive. */
	private void fade(ServerLevel level) {
		level.sendParticles(ParticleTypes.SOUL, this.getX(), this.getY() + 1.5, this.getZ(), 30, 0.4, 1.0, 0.4, 0.02);
		this.playSound(ModSounds.SINGER_FADE, 2.0F, 1.0F);
		this.entityData.set(DATA_FADED, true);
		this.entityData.set(DATA_SINGING, 0);
		this.setHealth(this.getMaxHealth());
		this.setInvisible(true);
		this.getNavigation().stop();
		this.home().ifPresent(h -> this.snapTo(h.getX() + 0.5, h.getY() + 1.0, h.getZ() + 0.5));
		long t = Tide.clockTicks(level);
		this.returnAtClock = t - Math.floorMod(t, Tide.PERIOD_TICKS) + Tide.PERIOD_TICKS; // the next Thrive
	}

	private void returnFromFade(ServerLevel level) {
		this.entityData.set(DATA_FADED, false);
		this.setInvisible(false);
		this.returnAtClock = -1L;
		level.sendParticles(ParticleTypes.SOUL, this.getX(), this.getY() + 1.5, this.getZ(), 20, 0.4, 1.0, 0.4, 0.02);
	}

	@Override
	public boolean isPickable() {
		return !this.faded() && super.isPickable();
	}

	@Override
	public boolean isPushable() {
		return !this.faded() && super.isPushable();
	}

	@Override
	protected void doPush(net.minecraft.world.entity.Entity entity) {
		if (!this.faded()) {
			super.doPush(entity);
		}
	}

	@Override
	public boolean removeWhenFarAway(double distSqr) {
		return false;
	}

	@Override
	protected @Nullable SoundEvent getAmbientSound() {
		if (this.silent()) {
			return null;
		}
		return this.restored() ? ModSounds.SINGER_SING : ModSounds.SINGER_HUM;
	}

	@Override
	public int getAmbientSoundInterval() {
		return 240;
	}

	@Override
	public void playAmbientSound() {
		super.playAmbientSound();
		if (!this.silent()) {
			this.entityData.set(DATA_SINGING, this.restored() ? 60 : 25);
		}
	}

	@Override
	protected SoundEvent getHurtSound(DamageSource source) {
		return ModSounds.SINGER_HURT;
	}

	@Override
	protected void addAdditionalSaveData(ValueOutput output) {
		super.addAdditionalSaveData(output);
		output.storeNullable("Home", BlockPos.CODEC, this.home);
		output.putLong("SilentUntil", this.silentUntil);
		output.putLong("ReturnAt", this.returnAtClock);
		output.putBoolean("Faded", this.faded());
		output.putBoolean("Restored", this.restored());
	}

	@Override
	protected void readAdditionalSaveData(ValueInput input) {
		super.readAdditionalSaveData(input);
		input.read("Home", BlockPos.CODEC).ifPresent(this::setHome);
		this.silentUntil = input.getLongOr("SilentUntil", 0L);
		this.returnAtClock = input.getLongOr("ReturnAt", -1L);
		this.entityData.set(DATA_FADED, input.getBooleanOr("Faded", false));
		this.entityData.set(DATA_RESTORED, input.getBooleanOr("Restored", false));
		this.setInvisible(this.faded());
	}
}
