package thesift.entity.blub;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.AgeableMob;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySpawnReason;
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
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.NoteBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModSounds;
import thesift.registry.ModTags;
import thesift.world.Tide;

/**
 * The Blub (mob_blub.md): the Sift's soft blue critter and pet. Befriended by a note played by hand
 * ({@link BlubMusic}); a befriended blub answers its owner's notes at its own interval (the echo),
 * gets restless before each Flow (the Tide herald) and curls up with a glowing belly in Endure.
 */
public class Blub extends TamableAnimal {
	/** Entity events (client animations); vanilla's own ids stay below 100 (EntityEvent ends at 72). */
	public static final byte EVENT_SING = 100;
	public static final byte EVENT_TEETER = 101;
	public static final byte EVENT_TOPPLE = 102;

	/** Listening lasts 10 s after the last music heard. */
	public static final int LISTEN_TICKS = 200;
	/** The echo answers 0.3 s after the note, at most once per 0.5 s. */
	public static final int ECHO_DELAY = 6;
	public static final int ECHO_COOLDOWN = 10;
	/** The herald's warning: the last 30 s before each Flow. */
	public static final int HERALD_TICKS = 600;
	/** Resting heals 1 HP every 30 s. */
	public static final int REST_HEAL_TICKS = 600;
	public static final int[] INTERVALS = {0, 4, 7};

	private static final EntityDataAccessor<Boolean> DATA_LISTENING = SynchedEntityData.defineId(Blub.class, EntityDataSerializers.BOOLEAN);
	private static final EntityDataAccessor<Boolean> DATA_CURLED = SynchedEntityData.defineId(Blub.class, EntityDataSerializers.BOOLEAN);
	private static final EntityDataAccessor<Boolean> DATA_RESTLESS = SynchedEntityData.defineId(Blub.class, EntityDataSerializers.BOOLEAN);
	private static final EntityDataAccessor<Integer> DATA_VARIANT = SynchedEntityData.defineId(Blub.class, EntityDataSerializers.INT);

	// Server state.
	private int echoInterval;
	private long listenUntil;
	private @Nullable Vec3 musicSource;
	private long echoAt = -1;
	private int echoNote;
	private long lastEcho = -ECHO_COOLDOWN; // not MIN_VALUE: "now - lastEcho" would overflow
	private @Nullable Vec3 ownerLastPos;
	private int ownerStillTicks;
	private long nextHeraldCue;
	private int lastSungNote = -1;
	// The tower this blub is the bottom of (BlubGoals.Stack.tickTower).
	@Nullable Vec3 towerOrigin;
	@Nullable Tide towerTide;
	long toppleAt = -1;

	// Client animation timers (ticks left).
	private int singTicks;
	private int teeterTicks;
	private int toppleTicks;
	private float glow;
	private float glowO;

	public Blub(EntityType<? extends Blub> type, Level level) {
		super(type, level);
	}

	public static AttributeSupplier.Builder createAttributes() {
		return Animal.createAnimalAttributes()
				.add(Attributes.MAX_HEALTH, 8.0)
				.add(Attributes.MOVEMENT_SPEED, 0.25)
				.add(Attributes.SAFE_FALL_DISTANCE, 4.0);
	}

	/**
	 * Natural spawns: the vanilla animal rule (sculk or tide sand, raw brightness above 8), plus no
	 * natural spawning in Endure. The light rule alone wouldn't stop it: it reads stored sky light,
	 * which stays 15 under open sky (mob_blub.md, Spawning).
	 */
	public static boolean checkBlubSpawnRules(EntityType<Blub> type, LevelAccessor level, EntitySpawnReason reason, BlockPos pos, RandomSource random) {
		if (!level.getBlockState(pos.below()).is(ModTags.BLUBS_SPAWNABLE_ON)) {
			return false;
		}
		if (!EntitySpawnReason.ignoresLightRequirements(reason) && level.getRawBrightness(pos, 0) <= 8) {
			return false;
		}
		return reason != EntitySpawnReason.NATURAL || !(level instanceof Level l) || naturalSpawnAllowed(Tide.current(l));
	}

	/** The creature spawner adds no blubs in Endure; blubs already out shelter. */
	public static boolean naturalSpawnAllowed(@Nullable Tide tide) {
		return tide != Tide.ENDURE;
	}

	@Override
	protected void defineSynchedData(SynchedEntityData.Builder builder) {
		super.defineSynchedData(builder);
		builder.define(DATA_LISTENING, false);
		builder.define(DATA_CURLED, false);
		builder.define(DATA_RESTLESS, false);
		builder.define(DATA_VARIANT, 0);
	}

	@Override
	protected void registerGoals() {
		this.goalSelector.addGoal(0, new FloatGoal(this));
		this.goalSelector.addGoal(1, new TamableAnimal.TamableAnimalPanicGoal(1.6));
		this.goalSelector.addGoal(2, new SitWhenOrderedToGoal(this));
		this.goalSelector.addGoal(3, new BlubGoals.Shelter(this));
		this.goalSelector.addGoal(4, new FollowOwnerGoal(this, 1.6, 6.0F, 2.0F));
		this.goalSelector.addGoal(5, new BlubGoals.Waterline(this));
		// STACK ranks above LISTEN: a running higher goal would keep MOVE, and a tower only starts while listening.
		this.goalSelector.addGoal(6, new BlubGoals.Stack(this));
		this.goalSelector.addGoal(7, new BlubGoals.Listen(this));
		this.goalSelector.addGoal(8, new BlubGoals.Bathe(this));
		this.goalSelector.addGoal(9, new WaterAvoidingRandomStrollGoal(this, 1.0));
		this.goalSelector.addGoal(10, new LookAtPlayerGoal(this, Player.class, 6.0F));
		this.goalSelector.addGoal(11, new RandomLookAroundGoal(this));
	}

	// ------------------------------------------------------------------ state

	public boolean isListening() {
		return this.entityData.get(DATA_LISTENING);
	}

	public boolean isCurled() {
		return this.entityData.get(DATA_CURLED);
	}

	public void setCurled(boolean curled) {
		if (curled != this.isCurled()) {
			this.entityData.set(DATA_CURLED, curled);
			if (curled) {
				this.playSound(ModSounds.BLUB_CURL, 0.6F, this.getVoicePitch());
			}
		}
	}

	public boolean isRestless() {
		return this.entityData.get(DATA_RESTLESS);
	}

	public int variant() {
		return this.entityData.get(DATA_VARIANT);
	}

	public int echoInterval() {
		return this.echoInterval;
	}

	@Nullable Vec3 musicSource() {
		return this.isListening() ? this.musicSource : null;
	}

	/** How long the owner has stood still (server side; 0 for an untamed blub). */
	int ownerStillTicks() {
		return this.ownerStillTicks;
	}

	/** The Tide, or null outside the Sift; outside it, night stands in for Endure. */
	@Nullable Tide tide() {
		return Tide.current(this.level());
	}

	boolean isShelterTime() {
		Tide tide = this.tide();
		return tide == null ? this.level().isDarkOutside() : tide == Tide.ENDURE;
	}

	// ------------------------------------------------------------------ music (server)

	/** Heard music at {@code source}: listen for the next 10 s. */
	void hear(Vec3 source, long gameTime) {
		boolean was = this.isListening();
		this.listenUntil = gameTime + LISTEN_TICKS;
		this.musicSource = source;
		if (!was) {
			this.entityData.set(DATA_LISTENING, true);
			this.playSound(ModSounds.BLUB_LISTEN, 0.8F, this.getVoicePitch());
		}
	}

	/** Befriended by {@code player}'s hand-played note: takes the player's next chord interval. */
	void befriend(Player player, int interval) {
		this.tame(player);
		this.echoInterval = interval;
		this.setOrderedToSit(false);
		this.setInSittingPose(false);
		this.navigation.stop();
		this.level().broadcastEntityEvent(this, (byte) 7); // hearts, as vanilla taming
		this.playSound(ModSounds.BLUB_HAPPY, 1.0F, this.getVoicePitch());
		this.getJumpControl().jump();
	}

	/** Its owner played {@code note} (0–24): answer it after {@link #ECHO_DELAY} ticks. */
	void queueEcho(int note, long gameTime) {
		if (gameTime - this.lastEcho < ECHO_COOLDOWN || this.echoAt >= 0) {
			return;
		}
		this.echoNote = note;
		this.echoAt = gameTime + ECHO_DELAY;
	}

	/** The echo's note: the owner's note plus this blub's interval, an octave down past the top. */
	public static int echoNote(int note, int interval) {
		int n = note + interval;
		return n > 24 ? n - 12 : n;
	}

	private void sing(ServerLevel level, long gameTime) {
		int note = echoNote(this.echoNote, this.echoInterval);
		this.lastEcho = gameTime;
		this.echoAt = -1;
		// A plain sound and particle: no game event, so echoes never open frames or set off other blubs.
		level.playSound(null, this.getX(), this.getY(), this.getZ(), ModSounds.BLUB_SING, SoundSource.RECORDS, 1.0F, NoteBlock.getPitchFromNote(note));
		level.sendParticles(ParticleTypes.NOTE, this.getX(), this.getY() + 0.85, this.getZ(), 0, note / 24.0, 0.0, 0.0, 1.0);
		level.broadcastEntityEvent(this, EVENT_SING);
		this.lastSungNote = note;
	}

	/** The last note this blub sang (0–24), or -1 (tests and debugging). */
	public int lastSungNote() {
		return this.lastSungNote;
	}

	// ------------------------------------------------------------------ ticking

	@Override
	public void tick() {
		super.tick();
		if (this.level() instanceof ServerLevel level) {
			this.serverTick(level);
		} else {
			this.clientTick();
		}
	}

	private void serverTick(ServerLevel level) {
		long now = level.getGameTime();
		if (!this.isListening() && now < this.listenUntil) {
			this.entityData.set(DATA_LISTENING, true); // loaded mid-tune: still listening, toward no source
		}
		if (this.isListening() && now >= this.listenUntil) {
			this.entityData.set(DATA_LISTENING, false);
			this.musicSource = null;
		}
		if (this.echoAt >= 0 && now >= this.echoAt) {
			this.sing(level, now);
		}
		this.trackOwner();
		this.herald(level, now);
		if ((this.isInSittingPose() || this.isCurled()) && this.getHealth() < this.getMaxHealth() && this.tickCount % REST_HEAL_TICKS == 0) {
			this.heal(1.0F);
		}
		if (this.isPassenger() && this.getVehicle() instanceof Blub && (this.isOrderedToSit() || this.ownerWalkingAway())) {
			this.stopRiding(); // sitting blubs sit; a follower leaves the tower first
		}
		BlubGoals.Stack.tickTower(this, level, now);
	}

	/** Owner standing-still time, for SHELTER (the "is the owner moving" check is ours). */
	private void trackOwner() {
		LivingEntity owner = this.isTame() ? this.getOwner() : null;
		if (owner == null || owner.level() != this.level()) {
			this.ownerLastPos = null;
			this.ownerStillTicks = 0;
			return;
		}
		Vec3 pos = owner.position();
		if (this.ownerLastPos != null && pos.distanceToSqr(this.ownerLastPos) < 0.01) {
			this.ownerStillTicks++;
		} else {
			this.ownerStillTicks = 0;
			this.ownerLastPos = pos;
		}
	}

	boolean ownerWalkingAway() {
		LivingEntity owner = this.isTame() ? this.getOwner() : null;
		return owner != null && owner.level() == this.level() && this.distanceToSqr(owner) > 36.0;
	}

	/**
	 * The Tide herald: a befriended blub in the Sift gets restless in the last 30 s before each Flow
	 * (the end of Thrive and the end of Endure), with a hop, a chirp and a note particle every few
	 * seconds. Restless wakes a curled blub.
	 */
	private void herald(ServerLevel level, long now) {
		boolean restless = false;
		if (this.isTame() && this.tide() != null) {
			long t = Math.floorMod(Tide.clockTicks(level), Tide.PERIOD_TICKS);
			restless = isHeraldTime(t);
		}
		if (restless != this.isRestless()) {
			this.entityData.set(DATA_RESTLESS, restless);
			this.nextHeraldCue = now;
		}
		if (restless && now >= this.nextHeraldCue && !this.isInSittingPose()) {
			this.setCurled(false);
			this.getJumpControl().jump();
			this.playSound(ModSounds.BLUB_RESTLESS, 0.9F, this.getVoicePitch());
			level.sendParticles(ParticleTypes.NOTE, this.getX(), this.getY() + 0.85, this.getZ(), 0, 0.5, 0.0, 0.0, 1.0);
			this.nextHeraldCue = now + 60 + this.random.nextInt(40);
		}
	}

	/** True in the last {@link #HERALD_TICKS} before each Flow begins. */
	public static boolean isHeraldTime(long cycleTick) {
		long t = Math.floorMod(cycleTick, Tide.PERIOD_TICKS);
		return inWindow(t, Tide.FLOW_RISING.startTick()) || inWindow(t, Tide.FLOW_FALLING.startTick());
	}

	private static boolean inWindow(long t, int flowStart) {
		return t >= flowStart - HERALD_TICKS && t < flowStart;
	}

	private void clientTick() {
		if (this.singTicks > 0) {
			this.singTicks--;
		}
		if (this.teeterTicks > 0) {
			this.teeterTicks--;
		}
		if (this.toppleTicks > 0) {
			this.toppleTicks--;
		}
		this.glowO = this.glow;
		boolean glowing = this.isShelterTime() || this.isCurled();
		this.glow = Mth.clamp(this.glow + (glowing ? 0.05F : -0.05F), 0.0F, 1.0F);
	}

	@Override
	public void handleEntityEvent(byte id) {
		switch (id) {
			case EVENT_SING -> this.singTicks = 8;
			case EVENT_TEETER -> this.teeterTicks = 60;
			case EVENT_TOPPLE -> this.toppleTicks = 10;
			default -> super.handleEntityEvent(id);
		}
	}

	/** 0..1 through the 0.4 s sing clip (client). */
	public float singProgress(float partialTick) {
		return this.singTicks <= 0 ? 0.0F : 1.0F - (this.singTicks - partialTick) / 8.0F;
	}

	/** 0..1 as a teetering tower nears its fall (client). */
	public float teeter(float partialTick) {
		return this.teeterTicks <= 0 ? 0.0F : 1.0F - (this.teeterTicks - partialTick) / 60.0F;
	}

	public float glow(float partialTick) {
		return Mth.lerp(partialTick, this.glowO, this.glow);
	}

	void teeterSoon() {
		this.level().broadcastEntityEvent(this, EVENT_TEETER);
	}

	void toppled() {
		this.level().broadcastEntityEvent(this, EVENT_TOPPLE);
	}

	// ------------------------------------------------------------------ interaction

	/**
	 * Use with an empty hand toggles sitting, as with a cat; sneak-use with an empty hand on a
	 * sitting blub releases it (vanilla pets have none; mob_blub.md, Befriending 5).
	 */
	@Override
	public InteractionResult mobInteract(Player player, InteractionHand hand) {
		ItemStack stack = player.getItemInHand(hand);
		if (this.isTame() && this.isOwnedBy(player) && stack.isEmpty() && hand == InteractionHand.MAIN_HAND) {
			if (!this.level().isClientSide()) {
				if (player.isSecondaryUseActive()) {
					if (this.isOrderedToSit()) {
						this.release(player);
					}
				} else {
					boolean sit = !this.isOrderedToSit();
					this.setOrderedToSit(sit);
					this.setInSittingPose(sit);
					this.navigation.stop();
					this.setCurled(false);
					if (sit) {
						this.stopRiding();
						this.ejectPassengers();
					}
				}
			}
			return InteractionResult.SUCCESS;
		}
		return super.mobInteract(player, hand);
	}

	private void release(Player player) {
		this.setOrderedToSit(false);
		this.setInSittingPose(false);
		this.setTame(false, false);
		this.setOwnerReference(null);
		this.echoInterval = 0;
		this.playSound(ModSounds.BLUB_HAPPY, 0.8F, this.getVoicePitch() * 0.9F);
		Vec3 away = this.position().subtract(player.position()).multiply(1, 0, 1);
		if (away.lengthSqr() > 1.0E-4) {
			away = away.normalize().scale(0.3);
			this.setDeltaMovement(away.x, 0.35, away.z);
		}
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

	@Override
	protected boolean canAddPassenger(Entity passenger) {
		return passenger instanceof Blub && this.getPassengers().isEmpty();
	}

	@Override
	public boolean hurtServer(ServerLevel level, DamageSource source, float damage) {
		boolean hurt = super.hurtServer(level, source, damage);
		if (hurt) {
			this.setCurled(false);
			BlubGoals.Stack.topple(this.getRootVehicle(), level);
		}
		return hurt;
	}

	// ------------------------------------------------------------------ sounds

	@Override
	protected @Nullable SoundEvent getAmbientSound() {
		return this.isCurled() ? ModSounds.BLUB_CURL : ModSounds.BLUB_AMBIENT;
	}

	@Override
	protected SoundEvent getHurtSound(DamageSource source) {
		return ModSounds.BLUB_HURT;
	}

	@Override
	protected @Nullable SoundEvent getDeathSound() {
		return ModSounds.BLUB_DEATH;
	}

	@Override
	public void jumpFromGround() {
		super.jumpFromGround();
		this.playSound(ModSounds.BLUB_HOP, 0.4F, this.getVoicePitch());
	}

	@Override
	protected void playStepSound(BlockPos pos, BlockState blockState) {
		this.playSound(ModSounds.BLUB_STEP, 0.15F, 1.0F);
	}

	// ------------------------------------------------------------------ saving

	@Override
	protected void addAdditionalSaveData(ValueOutput output) {
		super.addAdditionalSaveData(output);
		output.putInt("EchoInterval", this.echoInterval);
		output.putLong("ListenUntil", this.listenUntil);
		output.putInt("Variant", this.variant());
	}

	@Override
	protected void readAdditionalSaveData(ValueInput input) {
		super.readAdditionalSaveData(input);
		int interval = input.getIntOr("EchoInterval", 0);
		this.echoInterval = interval == 4 || interval == 7 ? interval : 0;
		this.listenUntil = input.getLongOr("ListenUntil", 0L);
		this.entityData.set(DATA_VARIANT, input.getIntOr("Variant", 0));
	}
}
