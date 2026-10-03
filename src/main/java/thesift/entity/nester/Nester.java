package thesift.entity.nester;

import java.util.function.BiConsumer;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.resources.Identifier;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.tags.TagKey;
import net.minecraft.util.RandomSource;
import net.minecraft.world.Difficulty;
import net.minecraft.world.DifficultyInstance;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySelector;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.SpawnGroupData;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.monster.illager.AbstractIllager;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.projectile.Projectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.ServerLevelAccessor;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.gameevent.DynamicGameEventListener;
import net.minecraft.world.level.gameevent.EntityPositionSource;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.gameevent.PositionSource;
import net.minecraft.world.level.gameevent.vibrations.VibrationSystem;
import net.minecraft.world.level.pathfinder.PathType;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.TheSift;
import thesift.entity.blub.Blub;
import thesift.entity.hunt.Hunt;
import thesift.registry.ModSounds;
import thesift.registry.ModTags;
import thesift.world.SiftAdvancements;
import thesift.world.SiftKeys;
import thesift.world.Tide;

/**
 * The Nester (mob_nester.md; system_hunt.md): a long-legged listener that surfaces in Endure, hears
 * what a sculk sensor hears out to 16 blocks, gallops to the sound (not to you), sniffs round the spot
 * and duels whatever it finds: lunge, circle with its guard up, lunge again. It digs back into the
 * soil at dawn. Lumen keeps it out. The hearing is one vanilla vibration listener (as the warden's),
 * whose radius is 0 outside Endure, so it costs nothing then.
 */
@SuppressWarnings("this-escape") // the warden and the allay build their listeners the same way
public class Nester extends Monster implements VibrationSystem, Hunt.Hunter {
	private static final EntityDataAccessor<Byte> DATA_STATE = SynchedEntityData.defineId(Nester.class, EntityDataSerializers.BYTE);
	private static final EntityDataAccessor<Boolean> DATA_ENDURING = SynchedEntityData.defineId(Nester.class, EntityDataSerializers.BOOLEAN);
	public static final Identifier ENDURING_ID = TheSift.id("enduring");
	static final int COOLDOWN = 40;
	static final int EMERGE_TICKS = 40;
	static final int DIG_TICKS = 60;
	/** Gallop and hunt: about 5.0 blocks a second at speed 0.3 (mob_nester.md, Stats). */
	static final double GALLOP = 1.12;
	/** Roaming: about 1.4 blocks a second. */
	static final double ROAM = 0.6;
	/** No more Nesters spawn where this many are already within 48 blocks (D-030). */
	static final int LOCAL_CAP = 12;

	private final DynamicGameEventListener<VibrationSystem.Listener> dynamicVibrationListener;
	private VibrationSystem.Data vibrationData = new VibrationSystem.Data();
	private final VibrationSystem.User vibrationUser = new Ears();

	/** Spawned outside the Hollows (decided once at spawn, system §4). */
	private boolean surface = true;
	/** The Tide clock tick of the next Thrive after it appeared; -1 until known. */
	private long returnBy = -1;
	/** Where the last accepted sound was: the gallop's and the search's spot. */
	@Nullable BlockPos soundPos;
	private long cooldownUntil;
	/** Ticks in the current state (server side). */
	int stateTicks;
	/** Dodges left in this guard (1; Hard 2). */
	int dodgesLeft;
	/** Client: ticks since the state last changed, for the model's clips. */
	private int clientStateTicks;
	private NesterState clientLastState = NesterState.ROAM;

	public Nester(EntityType<? extends Nester> type, Level level) {
		super(type, level);
		this.dynamicVibrationListener = new DynamicGameEventListener<>(new VibrationSystem.Listener(this));
		this.xpReward = 5;
		this.setPathfindingMalus(PathType.WATER, 8.0F);
	}

	public static AttributeSupplier.Builder createAttributes() {
		return Monster.createMonsterAttributes()
				.add(Attributes.MAX_HEALTH, 20.0)
				.add(Attributes.ARMOR, 2.0)
				.add(Attributes.ATTACK_DAMAGE, 5.0)
				.add(Attributes.MOVEMENT_SPEED, 0.3)
				.add(Attributes.FOLLOW_RANGE, 24.0)
				.add(Attributes.STEP_HEIGHT, 1.0);
	}

	@Override
	protected void defineSynchedData(SynchedEntityData.Builder builder) {
		super.defineSynchedData(builder);
		builder.define(DATA_STATE, (byte) NesterState.ROAM.ordinal());
		builder.define(DATA_ENDURING, false);
	}

	@Override
	protected void registerGoals() {
		this.goalSelector.addGoal(0, new FloatGoal(this));
		this.goalSelector.addGoal(1, new NesterGoals.Emerge(this));
		this.goalSelector.addGoal(1, new NesterGoals.Retreat(this));
		this.goalSelector.addGoal(2, new NesterGoals.LeaveLumen(this));
		this.goalSelector.addGoal(3, new NesterHuntGoal(this));
		this.goalSelector.addGoal(5, new NesterGoals.Roam(this));
		this.goalSelector.addGoal(6, new RandomLookAroundGoal(this));
	}

	// ------------------------------------------------------------------ state

	public NesterState state() {
		return NesterState.byId(this.entityData.get(DATA_STATE));
	}

	void setState(NesterState state) {
		if (state != this.state()) {
			this.entityData.set(DATA_STATE, (byte) state.ordinal());
		}
		this.stateTicks = 0;
	}

	public boolean isEnduring() {
		return this.entityData.get(DATA_ENDURING);
	}

	/** The enduring variant (system §5): health ×1.5, damage ×1.25, knockback resistance +0.2. */
	public void setEnduring(boolean enduring) {
		this.entityData.set(DATA_ENDURING, enduring);
		modifier(this.getAttribute(Attributes.MAX_HEALTH), enduring ? 0.5 : 0, AttributeModifier.Operation.ADD_MULTIPLIED_BASE);
		modifier(this.getAttribute(Attributes.ATTACK_DAMAGE), enduring ? 0.25 : 0, AttributeModifier.Operation.ADD_MULTIPLIED_BASE);
		modifier(this.getAttribute(Attributes.KNOCKBACK_RESISTANCE), enduring ? 0.2 : 0, AttributeModifier.Operation.ADD_VALUE);
		if (enduring) {
			this.setHealth(this.getMaxHealth());
		} else if (this.getHealth() > this.getMaxHealth()) {
			this.setHealth(this.getMaxHealth());
		}
	}

	private static void modifier(@Nullable AttributeInstance attribute, double amount, AttributeModifier.Operation operation) {
		if (attribute == null) {
			return;
		}
		attribute.removeModifier(ENDURING_ID);
		if (amount != 0) {
			attribute.addOrReplacePermanentModifier(new AttributeModifier(ENDURING_ID, amount, operation));
		}
	}

	/** Ticks since the state changed, client side (the model's clips). */
	public int clientStateTicks() {
		return this.clientStateTicks;
	}

	@Override
	public int getBaseExperienceReward(ServerLevel level) {
		return this.isEnduring() ? 10 : 5;
	}

	// ------------------------------------------------------------------ hearing (system_hunt.md §3)

	@Override
	public void updateDynamicGameEventListener(BiConsumer<DynamicGameEventListener<?>, ServerLevel> action) {
		if (this.level() instanceof ServerLevel level) {
			action.accept(this.dynamicVibrationListener, level);
		}
	}

	@Override
	public VibrationSystem.Data getVibrationData() {
		return this.vibrationData;
	}

	@Override
	public VibrationSystem.User getVibrationUser() {
		return this.vibrationUser;
	}

	/** Listens only in Endure, in the Sift. */
	boolean endure() {
		return Tide.current(this.level()) == Tide.ENDURE;
	}

	/** Whether a sound with this cause is one it would react to now (run when made and again on arrival). */
	private boolean accepts(ServerLevel level, BlockPos pos, Holder<GameEvent> event, @Nullable Entity source, @Nullable Entity owner) {
		if (this.isNoAi() || this.isDeadOrDying() || !this.endure() || level.getGameTime() < this.cooldownUntil
				|| !this.state().listening() || this.getTarget() != null) {
			return false;
		}
		for (Entity cause : new Entity[] {source, owner}) {
			if (cause != null && (cause.is(ModTags.HUNTERS) || !EntitySelector.NO_CREATIVE_OR_SPECTATOR.test(cause))) {
				return false;
			}
		}
		return !event.is(GameEvent.JUKEBOX_PLAY.key()) || pos.distToCenterSqr(this.position()) <= Hunt.JUKEBOX_RANGE * Hunt.JUKEBOX_RANGE;
	}

	private java.util.@Nullable UUID lulledAgainst;
	private long lulledUntil;

	/**
	 * A Singer's horn sang near it (items.md §1.2): it drops its target and its sound, stops hunting, and
	 * won't take the singer again, nor hear their song, for {@code ticks}.
	 */
	public void lull(ServerLevel level, Entity singer, int ticks) {
		this.lulledAgainst = singer.getUUID();
		this.lulledUntil = level.getGameTime() + ticks;
		this.setTarget(null);
		this.soundPos = null;
		NesterState state = this.state();
		if (state != NesterState.EMERGE && state != NesterState.DIG && state != NesterState.ROAM) {
			this.setState(NesterState.ROAM);
		}
		this.getNavigation().stop();
		level.sendParticles(net.minecraft.core.particles.ParticleTypes.NOTE, this.getX(), this.getY() + 2.0, this.getZ(), 4, 0.4, 0.3, 0.4, 1.0);
		this.playSound(ModSounds.NESTER_LULLED, 1.0F, 1.0F);
	}

	/** Whether a horn's lull still keeps it off {@code entity}. */
	public boolean lulledAgainst(@Nullable Entity entity) {
		return entity != null && entity.getUUID().equals(this.lulledAgainst) && this.level().getGameTime() < this.lulledUntil;
	}

	/** A sound arrived and was accepted: roam hears it (the tell); a gallop or search re-aims (§3). */
	void hear(ServerLevel level, BlockPos pos, @Nullable Entity cause) {
		this.cooldownUntil = level.getGameTime() + COOLDOWN;
		this.soundPos = pos.immutable();
		if (this.state() == NesterState.ROAM) {
			this.setState(NesterState.TELL);
			this.getNavigation().stop();
			this.playSound(ModSounds.NESTER_HEAR, 1.0F, this.getVoicePitch());
		} else {
			this.setState(NesterState.GALLOP);
		}
		if (cause instanceof ServerPlayer player) {
			SiftAdvancements.award(player, SiftAdvancements.HEARD_YOU);
		}
	}

	private final class Ears implements VibrationSystem.User {
		private final PositionSource positionSource = new EntityPositionSource(Nester.this, Nester.this.getEyeHeight());

		@Override
		public int getListenerRadius() {
			return Nester.this.endure() ? Hunt.HEAR_RANGE : 0;
		}

		@Override
		public PositionSource getPositionSource() {
			return this.positionSource;
		}

		@Override
		public TagKey<GameEvent> getListenableEvents() {
			return ModTags.HUNTER_CAN_LISTEN;
		}

		@Override
		public boolean canTriggerAvoidVibration() {
			return true;
		}

		@Override
		public boolean canReceiveVibration(ServerLevel level, BlockPos pos, Holder<GameEvent> event, GameEvent.Context context) {
			Entity source = context.sourceEntity();
			Entity owner = source instanceof Projectile projectile ? projectile.getOwner() : null;
			return Nester.this.accepts(level, pos, event, source, owner);
		}

		@Override
		public void onReceiveVibration(ServerLevel level, BlockPos pos, Holder<GameEvent> event, @Nullable Entity sourceEntity,
				@Nullable Entity projectileOwner, float receivingDistance) {
			// The state can change during the travel time: the filters run again on arrival.
			if (Nester.this.accepts(level, pos, event, sourceEntity, projectileOwner) && !Nester.this.lulledAgainst(sourceEntity)
					&& !Nester.this.lulledAgainst(projectileOwner)) {
				Nester.this.hear(level, pos, projectileOwner != null ? projectileOwner : sourceEntity);
			}
		}
	}

	// ------------------------------------------------------------------ targets and the duel

	/** What a search finds and a hunt keeps (§3): survival and adventure players, illagers, blubs. */
	public static boolean isPrey(LivingEntity entity) {
		return entity.isAlive() && EntitySelector.NO_CREATIVE_OR_SPECTATOR.test(entity)
				&& (entity instanceof Player || entity instanceof AbstractIllager || entity instanceof Blub);
	}

	@Override
	public boolean hurtServer(ServerLevel level, DamageSource source, float damage) {
		Entity attacker = source.getEntity();
		if (this.state() == NesterState.GUARD && this.dodgesLeft > 0 && attacker != null && attacker == this.getTarget()
				&& (source.is(DamageTypeTags.IS_PLAYER_ATTACK) || source.is(DamageTypes.MOB_ATTACK))) {
			this.dodge(level, attacker);
			return false;
		}
		boolean hurt = super.hurtServer(level, source, damage);
		if (hurt && attacker instanceof LivingEntity living && living != this.getTarget() && isPrey(living)
				&& this.state() != NesterState.EMERGE && this.state() != NesterState.DIG) {
			// It turns on whoever last hurt it, and the duel starts over (mob_nester.md, several players).
			this.setTarget(living);
			this.setState(NesterState.GALLOP);
		}
		return hurt;
	}

	/** The guard's dodge (canon): the hit misses, it hops 2 blocks sideways, and its crest drops. */
	private void dodge(ServerLevel level, Entity attacker) {
		this.dodgesLeft--;
		Vec3 away = this.position().subtract(attacker.position()).multiply(1, 0, 1);
		Vec3 side = new Vec3(-away.z, 0, away.x);
		if (side.lengthSqr() < 1.0E-4) {
			side = new Vec3(1, 0, 0);
		}
		side = side.normalize().scale(this.random.nextBoolean() ? 1 : -1);
		Vec3 landing = this.position().add(side.scale(2.0));
		if (Hunt.standable(level, BlockPos.containing(landing)) == null || Hunt.inLumen(level, landing)
				|| !level.getFluidState(BlockPos.containing(landing)).isEmpty()) {
			side = side.scale(-1); // the other side, or a duck in place
			landing = this.position().add(side.scale(2.0));
			if (Hunt.standable(level, BlockPos.containing(landing)) == null || Hunt.inLumen(level, landing)) {
				side = Vec3.ZERO;
			}
		}
		this.setDeltaMovement(side.x * 0.45, 0.25, side.z * 0.45);
		this.needsSync = true;
		this.playSound(ModSounds.NESTER_DODGE, 1.0F, this.getVoicePitch());
		this.setState(NesterState.DODGE);
	}

	/** A shield blocked its bite: it staggers for 30 ticks (the ravager's stun, every time). */
	@Override
	protected void blockedByItem(LivingEntity defender, DamageSource source, float damage, boolean fullyBlocked) {
		NesterState state = this.state();
		if (state == NesterState.LEAP || state == NesterState.BITE) {
			this.setState(NesterState.STAGGER);
			this.getNavigation().stop();
			this.playSound(ModSounds.NESTER_STAGGER, 1.0F, this.getVoicePitch());
		}
	}

	// ------------------------------------------------------------------ spawning, emerging, the tide

	/**
	 * Natural spawns (§7, mob_nester.md Spawning): Endure only, dark, on soil, no lumen within 8, and
	 * fewer than LOCAL_CAP Nesters within 48 blocks (D-030).
	 */
	public static boolean checkNesterSpawnRules(EntityType<Nester> type, ServerLevelAccessor level, EntitySpawnReason reason, BlockPos pos,
			RandomSource random) {
		if (reason == EntitySpawnReason.NATURAL && Tide.current(level.getLevel()) != Tide.ENDURE) {
			return false;
		}
		if (!Monster.checkMonsterSpawnRules(type, level, reason, pos, random) || !Hunt.isSoil(level.getBlockState(pos.below()))) {
			return false;
		}
		if (level.getEntitiesOfClass(Nester.class, new AABB(pos).inflate(48.0)).size() >= LOCAL_CAP) {
			return false;
		}
		return Hunt.lumenWithin(level.getLevel(), Vec3.atBottomCenterOf(pos), Hunt.NO_SPAWN) == null;
	}

	@Override
	public @Nullable SpawnGroupData finalizeSpawn(ServerLevelAccessor level, DifficultyInstance difficulty, EntitySpawnReason reason,
			@Nullable SpawnGroupData groupData) {
		ServerLevel server = level.getLevel();
		this.surface = !level.getBiome(this.blockPosition()).is(SiftKeys.SIFT_HOLLOWS);
		if (server.dimension().equals(SiftKeys.LEVEL)) {
			this.returnBy = Hunt.nextThrive(server);
		}
		if (reason == EntitySpawnReason.NATURAL || reason == EntitySpawnReason.CHUNK_GENERATION) {
			this.setState(NesterState.EMERGE); // it surfaces (spawn eggs and /summon skip this)
			if (Tide.current(server) == Tide.ENDURE
					&& this.random.nextFloat() < (level.getDifficulty() == Difficulty.HARD ? 0.35F : 0.25F)) {
				this.setEnduring(true);
			}
		}
		return super.finalizeSpawn(level, difficulty, reason, groupData);
	}

	/** Persistent hunters (a name tag, a boat, a leash) never retreat, as vanilla never despawns them (§4). */
	boolean persistent() {
		return this.isPersistenceRequired() || this.requiresCustomPersistence();
	}

	/** The dawn and the Thrive sweep (§4, §5): past its return-by it leaves with the tide, or, if persistent, stops enduring. */
	@Override
	public void tideCheck(ServerLevel level) {
		if (this.returnBy < 0 || !level.dimension().equals(SiftKeys.LEVEL)) {
			return;
		}
		long clock = Tide.clockTicks(level);
		if (this.returnBy - clock > Tide.PERIOD_TICKS) {
			this.returnBy = Hunt.nextThrive(level); // the clock was set back
			return;
		}
		if (clock < this.returnBy) {
			return;
		}
		if (this.persistent()) {
			if (this.isEnduring()) {
				this.setEnduring(false);
				level.sendParticles(ParticleTypes.SOUL, this.getX(), this.getY() + 1.0, this.getZ(), 6, 0.3, 0.4, 0.3, 0.02);
			}
			this.returnBy = Hunt.nextThrive(level);
			return;
		}
		// The tide takes it: a burst of soul wisps and the burrow sound; no drops, no XP.
		level.sendParticles(ParticleTypes.SOUL, this.getX(), this.getY() + 0.8, this.getZ(), 14, 0.4, 0.5, 0.4, 0.03);
		level.playSound(null, this.blockPosition(), ModSounds.NESTER_BURROW, SoundSource.HOSTILE, 1.0F, 1.0F);
		this.discard();
	}

	/** Falling Flow, past its moment (§4): time to go home. */
	boolean dawn() {
		if (this.persistent() || this.returnBy < 0) {
			return false;
		}
		return Tide.current(this.level()) == Tide.FLOW_FALLING && Hunt.cycleTick(this.level()) >= Hunt.retreatMoment(this.getUUID());
	}

	/** Leaves at the end of the dig: no drops, no XP (it left; it wasn't killed). */
	void burrowedAway() {
		this.discard();
	}

	@Override
	public void tick() {
		super.tick();
		if (this.level() instanceof ServerLevel level) {
			VibrationSystem.Ticker.tick(level, this.vibrationData, this.vibrationUser);
			this.stateTicks++;
			if (this.returnBy < 0 && level.dimension().equals(SiftKeys.LEVEL)) {
				this.returnBy = Hunt.nextThrive(level); // spawned without finalizeSpawn (a summon with data)
			}
			Tide tide = Tide.current(level);
			if ((tide == Tide.THRIVE || tide == Tide.FLOW_RISING) && this.tickCount % 20 == 0) {
				this.tideCheck(level);
			}
		} else {
			NesterState state = this.state();
			if (state != this.clientLastState) {
				this.clientLastState = state;
				this.clientStateTicks = 0;
			} else {
				this.clientStateTicks++;
			}
			if (this.isEnduring() && this.tickCount % 10 == 0) { // the trail of soul wisps
				this.level().addParticle(ParticleTypes.SOUL, this.getRandomX(0.6), this.getY() + 0.6 + this.random.nextDouble() * 0.6,
						this.getRandomZ(0.6), 0.0, 0.02, 0.0);
			}
			if (state == NesterState.EMERGE || state == NesterState.DIG) {
				BlockState below = this.level().getBlockState(this.blockPosition().below());
				if (!below.isAir()) {
					for (int i = 0; i < 2; i++) {
						this.level().addParticle(new BlockParticleOption(ParticleTypes.BLOCK, below), this.getRandomX(0.7), this.getY() + 0.1,
								this.getRandomZ(0.7), 0.0, 0.05, 0.0);
					}
				}
			}
		}
	}

	// ------------------------------------------------------------------ sounds

	@Override
	protected @Nullable SoundEvent getAmbientSound() {
		if (this.state() == NesterState.EMERGE || this.state() == NesterState.DIG) {
			return null;
		}
		return this.isEnduring() ? ModSounds.NESTER_AMBIENT_ENDURING : ModSounds.NESTER_AMBIENT;
	}

	@Override
	protected SoundEvent getHurtSound(DamageSource source) {
		return ModSounds.NESTER_HURT;
	}

	@Override
	protected SoundEvent getDeathSound() {
		return ModSounds.NESTER_DEATH;
	}

	/** Ordinary steps are quiet (0.15, as vanilla mobs'); the gallop plays its own loud thuds. */
	@Override
	protected void playStepSound(BlockPos pos, BlockState state) {
		if (this.state() != NesterState.GALLOP) {
			this.playSound(ModSounds.NESTER_STEP, 0.15F, 1.0F);
		}
	}

	// ------------------------------------------------------------------ saving

	@Override
	protected void addAdditionalSaveData(ValueOutput output) {
		super.addAdditionalSaveData(output);
		output.putBoolean("Surface", this.surface);
		output.putBoolean("Enduring", this.isEnduring());
		output.putLong("ReturnBy", this.returnBy);
		output.store("listener", VibrationSystem.Data.CODEC, this.vibrationData);
	}

	@Override
	protected void readAdditionalSaveData(ValueInput input) {
		super.readAdditionalSaveData(input);
		this.surface = input.getBooleanOr("Surface", true);
		this.entityData.set(DATA_ENDURING, input.getBooleanOr("Enduring", false));
		this.returnBy = input.getLongOr("ReturnBy", -1L);
		this.vibrationData = input.read("listener", VibrationSystem.Data.CODEC).orElseGet(VibrationSystem.Data::new);
	}

	/** For GameTests: put it on guard against {@code target}, as after a bite. */
	public void guardAgainst(LivingEntity target) {
		this.setTarget(target);
		this.dodgesLeft = 1;
		this.setState(NesterState.GUARD);
	}

	/** For GameTests: the Tide tick it leaves at. */
	public long returnBy() {
		return this.returnBy;
	}

	public void setReturnBy(long tick) {
		this.returnBy = tick;
	}

	public boolean isSurface() {
		return this.surface;
	}

	/** The gallop's thud, loud on purpose (1.5: heard about 24 blocks out). */
	void gallopStep() {
		this.playSound(ModSounds.NESTER_GALLOP, 1.5F, 0.9F + this.random.nextFloat() * 0.2F);
	}
}
