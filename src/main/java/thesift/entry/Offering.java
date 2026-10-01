package thesift.entry;

import net.fabricmc.fabric.api.event.player.UseBlockCallback;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;

import thesift.registry.ModSounds;
import thesift.world.SoulPoints;

/**
 * Step 3 of the entry (entry_path.md): holding <i>use</i> on an Ancient City frame with an empty
 * hand streams the player's experience into it. Nothing is taken without that deliberate action.
 */
public final class Offering {
	/** XP to reach level 30 from zero: the level-30 enchanting milestone (entry_path.md §3). */
	public static final int PRICE = 1395;
	/**
	 * Points per use. A held use key repeats every 4 ticks on the client (vanilla's right-click
	 * delay), so this streams about 50 points a second and the whole price in about half a minute.
	 */
	public static final int POINTS_PER_USE = 10;

	private Offering() {
	}

	public static void init() {
		UseBlockCallback.EVENT.register(Offering::onUse);
	}

	private static InteractionResult onUse(Player player, Level level, InteractionHand hand, BlockHitResult hit) {
		if (hand != InteractionHand.MAIN_HAND || !player.getMainHandItem().isEmpty() || player.isSpectator()
				|| level.dimension() != Level.OVERWORLD || !level.getBlockState(hit.getBlockPos()).is(Blocks.REINFORCED_DEEPSLATE)) {
			return InteractionResult.PASS;
		}
		if (!(level instanceof ServerLevel serverLevel) || !(player instanceof ServerPlayer serverPlayer)) {
			return InteractionResult.SUCCESS; // the server decides whether this is a frame
		}
		return offer(serverPlayer, serverLevel, hit.getBlockPos()) ? InteractionResult.SUCCESS : InteractionResult.PASS;
	}

	/** One use on {@code touched}. Returns false when the block is not part of a frame. */
	public static boolean offer(ServerPlayer player, ServerLevel level, BlockPos touched) {
		SiftLinks links = SiftLinks.get(level.getServer());
		SiftLinks.FrameLink link = links.frameWithBorder(touched).orElse(null);
		if (link == null) {
			SiftFrame frame = FrameShapes.find(level, touched, Blocks.REINFORCED_DEEPSLATE, SiftFrame.CITY_WIDTH, SiftFrame.CITY_HEIGHT).orElse(null);
			if (frame == null) {
				return false;
			}
			link = links.add(frame);
		}
		if (link.awake()) {
			tell(player, Component.translatable("thesift.frame.awake"));
			level.sendParticles(ParticleTypes.NOTE, touched.getX() + 0.5, touched.getY() + 1.2, touched.getZ() + 0.5, 1, 0.3, 0.2, 0.3, 0.0);
			return true;
		}

		int take = Math.min(POINTS_PER_USE, PRICE - link.charge());
		if (!player.getAbilities().instabuild) {
			take = SoulPoints.take(player, take);
			if (take <= 0) {
				tell(player, Component.translatable("thesift.frame.no_soul"));
				return true;
			}
		}
		SiftLinks.FrameLink updated = links.addCharge(link.frame(), take);
		streamSouls(player, level, touched, updated);
		level.gameEvent(player, GameEvent.BLOCK_ACTIVATE, touched);
		if (updated.awake()) {
			wake(level, updated.frame());
			tell(player, Component.translatable("thesift.frame.woke"));
		} else {
			tell(player, Component.translatable("thesift.frame.offering", updated.charge() * 100 / PRICE));
		}
		return true;
	}

	private static void streamSouls(ServerPlayer player, ServerLevel level, BlockPos touched, SiftLinks.FrameLink link) {
		Vec3 from = player.getEyePosition().add(0, -0.4, 0);
		Vec3 dir = Vec3.atCenterOf(touched).subtract(from).normalize().scale(0.12);
		for (int i = 0; i < 2; i++) {
			// count 0: the offsets are the particle's velocity
			level.sendParticles(ParticleTypes.SCULK_SOUL, from.x + (level.getRandom().nextDouble() - 0.5) * 0.4, from.y,
					from.z + (level.getRandom().nextDouble() - 0.5) * 0.4, 0, dir.x, dir.y, dir.z, 1.0);
		}
		// The charge shows on the frame as faint cyan specks, more of them as it fills.
		int specks = 1 + link.charge() * 6 / PRICE;
		var border = link.frame().border();
		for (int i = 0; i < specks; i++) {
			BlockPos p = border.get(level.getRandom().nextInt(border.size()));
			level.sendParticles(ParticleTypes.GLOW, p.getX() + 0.5, p.getY() + 0.5, p.getZ() + 0.5, 1, 0.4, 0.4, 0.4, 0.0);
		}
		if (level.getGameTime() % 8 == 0) {
			level.playSound(null, touched, ModSounds.FRAME_OFFER, SoundSource.BLOCKS, 0.8F, 0.85F + link.charge() * 0.5F / PRICE);
		}
	}

	private static void wake(ServerLevel level, SiftFrame frame) {
		Vec3 c = frame.center();
		level.playSound(null, BlockPos.containing(c), ModSounds.FRAME_WAKE, SoundSource.BLOCKS, 2.0F, 1.0F);
		for (BlockPos p : frame.border()) {
			level.sendParticles(ParticleTypes.GLOW, p.getX() + 0.5, p.getY() + 0.5, p.getZ() + 0.5, 2, 0.3, 0.3, 0.3, 0.0);
		}
		level.sendParticles(ParticleTypes.NOTE, c.x, c.y, c.z, 12, frame.width() / 4.0, 1.5, frame.width() / 4.0, 0.0);
	}

	private static void tell(ServerPlayer player, Component message) {
		if (player.connection != null) { // GameTest mock players have none
			player.sendOverlayMessage(message);
		}
	}
}
