package thesift.entity.rift;

import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.level.portal.TeleportTransition;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;

import thesift.entry.Rifts;
import thesift.registry.ModParticles;
import thesift.registry.ModSounds;
import thesift.world.SiftAdvancements;

/**
 * A rift (survival_sift.md §2.1; canon: "rifts that appear throughout the world", temporary): a tall
 * shimmering tear between the Overworld and the Sift. A player who walks in is carried through at once
 * to the same x and z on safe ground; whoever follows within 10 s goes too, then it closes. It also
 * closes when its time runs out. Only players cross (D-023).
 */
public class RiftEntity extends Entity {
	/** A natural rift stays 5 minutes; a rift fork's, 1 minute. */
	public static final int NATURAL_LIFE = 6000;
	public static final int FORK_LIFE = 1200;
	/** After the first crossing, 10 s for friends to follow. */
	public static final int FOLLOW = 200;
	/** It opens (and closes) over a second, uncrossable until open. */
	public static final int OPENING = 20;
	private static final EntityDataAccessor<Long> DATA_OPENED = SynchedEntityData.defineId(RiftEntity.class, EntityDataSerializers.LONG);
	private static final EntityDataAccessor<Long> DATA_CLOSES = SynchedEntityData.defineId(RiftEntity.class, EntityDataSerializers.LONG);
	private boolean crossed;
	private int humIn;

	public RiftEntity(EntityType<? extends RiftEntity> type, Level level) {
		super(type, level);
		this.noPhysics = true;
	}

	/** Opens now, for {@code lifetime} ticks. */
	public void open(long now, int lifetime) {
		this.entityData.set(DATA_OPENED, now);
		this.entityData.set(DATA_CLOSES, now + lifetime);
	}

	public long openedAt() {
		return this.entityData.get(DATA_OPENED);
	}

	public long closesAt() {
		return this.entityData.get(DATA_CLOSES);
	}

	public boolean crossed() {
		return this.crossed;
	}

	@Override
	protected void defineSynchedData(SynchedEntityData.Builder builder) {
		builder.define(DATA_OPENED, -1L); // unset: a summoned rift opens on its first tick
		builder.define(DATA_CLOSES, (long) NATURAL_LIFE);
	}

	@Override
	public void tick() {
		if (this.level() instanceof ServerLevel level) {
			this.serverTick(level);
		} else {
			this.clientTick();
		}
	}

	private void serverTick(ServerLevel level) {
		long now = level.getGameTime();
		if (this.openedAt() < 0L) {
			this.open(now, NATURAL_LIFE);
		}
		if (now >= this.closesAt()) {
			level.playSound(null, this.getX(), this.getY() + 1.5, this.getZ(), ModSounds.RIFT_CLOSE, SoundSource.AMBIENT, 2.0F, 1.0F);
			this.discard();
			return;
		}
		if (--this.humIn <= 0) {
			this.humIn = 80;
			level.playSound(null, this.getX(), this.getY() + 1.5, this.getZ(), ModSounds.RIFT_HUM, SoundSource.AMBIENT, 2.0F, 1.0F);
		}
		if (now - this.openedAt() < OPENING) {
			return;
		}
		for (ServerPlayer player : level.getEntitiesOfClass(ServerPlayer.class, this.getBoundingBox())) {
			if (player.isOnPortalCooldown()) {
				continue;
			}
			TeleportTransition to = Rifts.destination(level, player);
			if (to == null) {
				continue;
			}
			if (player.isPassenger()) {
				player.stopRiding(); // the passenger crosses, the vehicle stays (survival_sift.md §8)
			}
			if (player.teleport(to) != null) {
				player.setPortalCooldown();
				SiftAdvancements.award(player, SiftAdvancements.THROUGH_THE_RIFT);
				if (!this.crossed) {
					this.crossed = true;
					this.entityData.set(DATA_CLOSES, Math.min(this.closesAt(), now + FOLLOW));
				}
			}
		}
	}

	private void clientTick() {
		if (this.random.nextInt(2) == 0) {
			double x = this.getX() + (this.random.nextDouble() - 0.5) * 1.2;
			double y = this.getY() + this.random.nextDouble() * 3.0;
			double z = this.getZ() + (this.random.nextDouble() - 0.5) * 1.2;
			this.level().addParticle(ModParticles.GLIMMER, x, y, z, 0.0, 0.02, 0.0);
		}
	}

	@Override
	protected void readAdditionalSaveData(ValueInput input) {
		this.entityData.set(DATA_OPENED, input.getLongOr("Opened", -1L));
		this.entityData.set(DATA_CLOSES, input.getLongOr("Closes", 0L));
		this.crossed = input.getBooleanOr("Crossed", false);
	}

	@Override
	protected void addAdditionalSaveData(ValueOutput output) {
		output.putLong("Opened", this.openedAt());
		output.putLong("Closes", this.closesAt());
		output.putBoolean("Crossed", this.crossed);
	}

	@Override
	public boolean hurtServer(ServerLevel level, DamageSource source, float damage) {
		return false;
	}

	@Override
	public boolean isPickable() {
		return false;
	}

	@Override
	public boolean isPushable() {
		return false;
	}

	@Override
	public PushReaction getPistonPushReaction() {
		return PushReaction.IGNORE_ENTITY;
	}

	@Override
	public boolean isIgnoringBlockTriggers() {
		return true;
	}

	@Override
	protected boolean couldAcceptPassenger() {
		return false;
	}
}
