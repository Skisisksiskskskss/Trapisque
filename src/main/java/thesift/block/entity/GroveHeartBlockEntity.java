package thesift.block.entity;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.core.UUIDUtil;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.gameevent.BlockPositionSource;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.gameevent.GameEventListener;
import net.minecraft.world.level.gameevent.PositionSource;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import thesift.block.GroveHeartBlock;
import thesift.entity.singer.Singer;
import thesift.registry.ModBlockEntities;
import thesift.registry.ModBlocks;
import thesift.registry.ModItems;
import thesift.registry.ModParticles;
import thesift.registry.ModSounds;
import thesift.world.Tide;

/**
 * The grove heart's state and ears (items.md §1.1): whether the grove is restored, and which players it
 * rewarded (as the trial vault's rewarded players). Music played by hand within 16 blocks makes its
 * Singer hum (stones not yet filled) or, with all three filled, sing the whole song once: the grove
 * blooms outward, and every player within 16 who hasn't had one gets a Singer's horn.
 */
public class GroveHeartBlockEntity extends BlockEntity implements GameEventListener.Provider<GroveHeartBlockEntity.Ears> {
	public static final int HEARING = 16;
	public static final int STONES = 3;
	public static final int BLOOM_RADIUS = 12;
	private final Ears ears;
	private boolean restored;
	private final Set<UUID> rewarded = new HashSet<>();

	public GroveHeartBlockEntity(BlockPos pos, BlockState state) {
		super(ModBlockEntities.GROVE_HEART, pos, state);
		this.ears = new Ears(new BlockPositionSource(pos));
	}

	public boolean restored() {
		return this.restored;
	}

	public boolean rewarded(UUID player) {
		return this.rewarded.contains(player);
	}

	@Override
	public Ears getListener() {
		return this.ears;
	}

	/** Music by {@code player} reached the grove. */
	public void heard(ServerLevel level, ServerPlayer player) {
		if (Tide.current(level) == Tide.ENDURE) {
			return; // silent in Endure
		}
		List<Singer> singers = level.getEntitiesOfClass(Singer.class, new AABB(this.worldPosition).inflate(HEARING), s -> !s.faded());
		Singer singer = singers.isEmpty() ? null : singers.getFirst();
		if (this.restored) {
			if (singer != null) {
				singer.sing(ModSounds.SINGER_SING, 60, 1.0F);
			}
			return;
		}
		int filled = GroveHeartBlock.filledStones(level, this.worldPosition, 8);
		if (filled < STONES) {
			if (singer != null) {
				singer.sing(ModSounds.SINGER_HUM, 20 + 15 * filled, 0.8F + 0.12F * filled); // one broken phrase
			}
			return;
		}
		if (singer == null || singer.silent()) {
			return; // the song needs its Singer, and a Singer that will sing
		}
		this.song(level, singer);
	}

	private void song(ServerLevel level, Singer singer) {
		this.restored = true;
		this.setChanged();
		singer.setRestored(true);
		singer.sing(ModSounds.SINGER_SONG, 160, 1.0F);
		level.playSound(null, this.worldPosition, ModSounds.SINGER_SONG, SoundSource.NEUTRAL, 3.0F, 1.0F);
		BlockPos c = this.worldPosition;
		for (BlockPos p : BlockPos.betweenClosed(c.offset(-8, -3, -8), c.offset(8, 3, 8))) {
			if (level.getBlockState(p).is(ModBlocks.CHORUS_STONE)) {
				level.sendParticles(ParticleTypes.NOTE, p.getX() + 0.5, p.getY() + 1.4, p.getZ() + 0.5, 8, 0.3, 0.5, 0.3, 1.0);
			}
		}
		// Healthy sculk blooms outward over the grove's soil.
		for (int dx = -BLOOM_RADIUS; dx <= BLOOM_RADIUS; dx++) {
			for (int dz = -BLOOM_RADIUS; dz <= BLOOM_RADIUS; dz++) {
				if (dx * dx + dz * dz > BLOOM_RADIUS * BLOOM_RADIUS) {
					continue;
				}
				int x = c.getX() + dx;
				int z = c.getZ() + dz;
				BlockPos top = new BlockPos(x, level.getHeight(Heightmap.Types.WORLD_SURFACE, x, z) - 1, z);
				if (level.getBlockState(top).is(ModBlocks.SIFT_SOIL)) {
					level.setBlock(top, ModBlocks.HEALTHY_SCULK.defaultBlockState(), Block.UPDATE_ALL);
				}
				if (level.getRandom().nextInt(6) == 0) {
					level.sendParticles(ModParticles.GLOW_PETAL, x + 0.5, top.getY() + 1.3, z + 0.5, 1, 0.2, 0.2, 0.2, 0.0);
				}
			}
		}
		for (ServerPlayer player : level.getEntitiesOfClass(ServerPlayer.class, new AABB(c).inflate(HEARING))) {
			if (this.rewarded.add(player.getUUID())) {
				ItemStack horn = new ItemStack(ModItems.SINGERS_HORN);
				if (!player.getInventory().add(horn)) {
					player.spawnAtLocation(level, horn);
				}
			}
		}
		this.setChanged();
	}

	@Override
	protected void saveAdditional(ValueOutput output) {
		super.saveAdditional(output);
		output.putBoolean("Restored", this.restored);
		output.store("Rewarded", UUIDUtil.CODEC_SET, this.rewarded);
	}

	@Override
	protected void loadAdditional(ValueInput input) {
		super.loadAdditional(input);
		this.restored = input.getBooleanOr("Restored", false);
		this.rewarded.clear();
		input.read("Rewarded", UUIDUtil.CODEC_SET).ifPresent(this.rewarded::addAll);
	}

	/** Hears note blocks and instruments played by a player within 16 blocks (items.md §1.1, step 4). */
	public final class Ears implements GameEventListener {
		private final PositionSource source;

		Ears(PositionSource source) {
			this.source = source;
		}

		@Override
		public PositionSource getListenerSource() {
			return this.source;
		}

		@Override
		public int getListenerRadius() {
			return HEARING;
		}

		@Override
		public boolean handleGameEvent(ServerLevel level, Holder<GameEvent> event, GameEvent.Context context, Vec3 sourcePosition) {
			if ((event.is(GameEvent.NOTE_BLOCK_PLAY) || event.is(GameEvent.INSTRUMENT_PLAY))
					&& context.sourceEntity() instanceof ServerPlayer player) {
				GroveHeartBlockEntity.this.heard(level, player);
				return true;
			}
			return false;
		}
	}
}
