package thesift.item;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

import thesift.entity.rift.RiftEntity;
import thesift.entry.Rifts;
import thesift.registry.ModSounds;

/**
 * The rift fork (survival_sift.md §2.4; canon: the staff opens rifts "at will"): strike it and a note
 * rings, and a rift opens 3 blocks ahead for a minute, in the Overworld or the Sift. 8 uses, a 5 s
 * cooldown. Where no rift fits (a wall, a drop, water), it rings dull and nothing is used.
 */
public class RiftForkItem extends Item {
	public static final int COOLDOWN = 100;
	public static final int REACH = 3;

	public RiftForkItem(Properties properties) {
		super(properties);
	}

	@Override
	public InteractionResult use(Level level, Player player, InteractionHand hand) {
		if (!(level instanceof ServerLevel server)) {
			return InteractionResult.SUCCESS;
		}
		ItemStack stack = player.getItemInHand(hand);
		BlockPos spot = Rifts.riftsOpenIn(server) ? spotAhead(server, player) : null;
		if (spot == null) {
			server.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.RIFT_FORK_STRIKE, SoundSource.PLAYERS, 0.6F, 0.5F);
			return InteractionResult.FAIL;
		}
		server.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.RIFT_FORK_STRIKE, SoundSource.PLAYERS, 1.0F, 1.0F);
		Rifts.open(server, Vec3.atBottomCenterOf(spot), RiftEntity.FORK_LIFE);
		player.getCooldowns().addCooldown(stack, COOLDOWN);
		stack.hurtAndBreak(1, player, hand);
		return InteractionResult.SUCCESS_SERVER;
	}

	/** Three blocks ahead along the player's facing, on the ground within a block or two of their feet. */
	private static BlockPos spotAhead(ServerLevel level, Player player) {
		Vec3 look = player.getLookAngle();
		Vec3 flat = new Vec3(look.x, 0.0, look.z);
		flat = flat.lengthSqr() < 1.0E-4 ? Vec3.ZERO : flat.normalize().scale(REACH);
		BlockPos base = BlockPos.containing(player.position().add(flat));
		for (int dy : new int[] {0, 1, -1, 2, -2}) {
			BlockPos feet = base.above(dy);
			if (Rifts.riftFits(level, feet)) {
				return feet;
			}
		}
		return null;
	}
}
