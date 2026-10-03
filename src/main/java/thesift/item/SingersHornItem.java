package thesift.item;

import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.phys.AABB;

import thesift.entity.nester.Nester;
import thesift.registry.ModBlocks;
import thesift.registry.ModParticles;
import thesift.registry.ModSounds;
import thesift.world.SiftKeys;

/**
 * The Singer's horn, the gift of song (items.md §1.2): played, it sings. In the Sift a song spends one of
 * the player's charges and, within 12 blocks, grows healthy sculk over bare soil and lulls the hunters
 * (they drop their target and won't take this player again for 10 s). It is still a sound: hunters
 * farther out hear it. Outside the Sift it plays as an instrument, with a goat horn's cooldown and no
 * charge.
 */
public class SingersHornItem extends Item {
	public static final int REACH = 12;
	public static final int LULL_TICKS = 200;
	public static final int COOLDOWN = 140;

	public SingersHornItem(Properties properties) {
		super(properties);
	}

	@Override
	public InteractionResult use(Level level, Player player, InteractionHand hand) {
		if (!(level instanceof ServerLevel server)) {
			return InteractionResult.SUCCESS;
		}
		ItemStack stack = player.getItemInHand(hand);
		boolean sift = SiftKeys.isSift(server);
		if (sift) {
			if (!SongCharges.spend(player)) {
				server.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.SINGERS_HORN_SONG, SoundSource.PLAYERS, 0.4F, 0.5F);
				player.sendOverlayMessage(Component.translatable("item.thesift.singers_horn.no_charges"));
				return InteractionResult.FAIL;
			}
			this.songEffects(server, player);
			player.sendOverlayMessage(Component.translatable("item.thesift.singers_horn.charges", SongCharges.charges(player), SongCharges.MAX));
		}
		player.getCooldowns().addCooldown(stack, sift ? 20 : COOLDOWN);
		server.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.SINGERS_HORN_SONG, SoundSource.RECORDS, 4.0F, 1.0F);
		server.gameEvent(GameEvent.INSTRUMENT_PLAY, player.position(), GameEvent.Context.of(player));
		return InteractionResult.SUCCESS_SERVER;
	}

	private void songEffects(ServerLevel level, Player player) {
		BlockPos c = player.blockPosition();
		for (int i = 0; i < 40; i++) {
			int x = c.getX() + level.getRandom().nextInt(REACH * 2 + 1) - REACH;
			int z = c.getZ() + level.getRandom().nextInt(REACH * 2 + 1) - REACH;
			BlockPos top = new BlockPos(x, level.getHeight(Heightmap.Types.WORLD_SURFACE, x, z) - 1, z);
			if (Math.abs(top.getY() - c.getY()) <= 6 && level.getBlockState(top).is(ModBlocks.SIFT_SOIL)) {
				level.setBlock(top, ModBlocks.HEALTHY_SCULK.defaultBlockState(), Block.UPDATE_ALL);
				level.sendParticles(ModParticles.GLOW_PETAL, x + 0.5, top.getY() + 1.3, z + 0.5, 2, 0.2, 0.2, 0.2, 0.0);
			}
		}
		for (Nester nester : level.getEntitiesOfClass(Nester.class, new AABB(c).inflate(REACH))) {
			nester.lull(level, player, LULL_TICKS);
		}
	}
}
