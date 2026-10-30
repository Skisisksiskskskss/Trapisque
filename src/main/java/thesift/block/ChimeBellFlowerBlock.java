package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.FlowerBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModSounds;

/**
 * The chime bell flower (block_flora_ii.md §4; system_hunt.md §9): a living thing moving through it
 * rings it, unless it steps carefully (sneaking). A ring is a {@code block_activate} vibration with
 * the walker as source, so in Endure a careless step is heard. It rings at most once per 10 ticks,
 * held by a state with a scheduled reset (no block entity). Near music it hums on the client only,
 * with its own sound and subtitle, so the harmless hum never reads as a ring.
 */
public class ChimeBellFlowerBlock extends FlowerBlock {
	public static final BooleanProperty RINGING = BooleanProperty.create("ringing");
	public static final int RING_COOLDOWN = 10;
	/** The sweet berry bush's threshold for "moving", per tick, on either horizontal axis. */
	private static final double MOVING = 0.003;

	@SuppressWarnings("this-escape") // vanilla blocks register their default state the same way
	public ChimeBellFlowerBlock(Properties properties) {
		super(MobEffects.SLOW_FALLING, 7.0F, properties);
		this.registerDefaultState(this.stateDefinition.any().setValue(RINGING, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		builder.add(RINGING);
	}

	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.isSiftGround(state);
	}

	@Override
	protected void entityInside(BlockState state, Level level, BlockPos pos, Entity entity, InsideBlockEffectApplier effectApplier,
			boolean isPrecise) {
		if (!(level instanceof ServerLevel serverLevel) || state.getValue(RINGING) || !(entity instanceof LivingEntity)
				|| entity.isSpectator() || entity.isSteppingCarefully() || !moving(entity)) {
			return;
		}
		serverLevel.setBlock(pos, state.setValue(RINGING, true), Block.UPDATE_CLIENTS);
		serverLevel.scheduleTick(pos, this, RING_COOLDOWN);
		serverLevel.playSound(null, pos, ModSounds.CHIME_BELL_RING, SoundSource.BLOCKS, 0.6F, 0.85F + serverLevel.getRandom().nextFloat() * 0.3F);
		serverLevel.gameEvent(entity, GameEvent.BLOCK_ACTIVATE, pos);
	}

	/** The sweet berry bush's test: players' movement is known from the client, other entities' from their last move. */
	private static boolean moving(Entity entity) {
		Vec3 movement = entity.isClientAuthoritative() ? entity.getKnownMovement() : entity.oldPosition().subtract(entity.position());
		return Math.abs(movement.x()) >= MOVING || Math.abs(movement.z()) >= MOVING;
	}

	@Override
	protected void tick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
		if (state.getValue(RINGING)) {
			level.setBlock(pos, state.setValue(RINGING, false), Block.UPDATE_CLIENTS);
		}
	}

	/** A flower placed already ringing (a command, a structure) still resets. */
	@Override
	protected void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean movedByPiston) {
		if (state.getValue(RINGING) && !oldState.is(this)) {
			level.scheduleTick(pos, this, RING_COOLDOWN);
		}
	}

	/** The music reaction (world.md §3.2): a soft hum and a note, on the client alone. */
	@Override
	public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
		if (random.nextInt(40) == 0 && MusicNearby.near(pos)) {
			level.playLocalSound(pos, ModSounds.CHIME_BELL_HUM, SoundSource.BLOCKS, 0.3F, 0.9F + random.nextFloat() * 0.2F, false);
			level.addParticle(ParticleTypes.NOTE, pos.getX() + 0.5, pos.getY() + 0.7, pos.getZ() + 0.5, random.nextInt(25) / 24.0, 0.0, 0.0);
		}
	}
}
