package thesift.block;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

import thesift.TheSift;
import thesift.registry.ModBlocks;
import thesift.registry.ModSounds;
import thesift.world.Tide;

/**
 * The Endure bloom (block_flora_ii.md §2): a flat star of petals on the waterline that opens in
 * Endure. It gives no block light (world.md §3.1); its open model's centre and petal edges are
 * emissive, as vanilla's open eyeblossom, so a patch shows in the dark.
 */
public class EndureBloomBlock extends TideFloraBlock {
	public static final ResourceKey<LootTable> HARVEST = ResourceKey.create(Registries.LOOT_TABLE, TheSift.id("harvest/endure_bloom"));
	private static final VoxelShape SHAPE = Block.column(14.0, 0.0, 3.0);

	public EndureBloomBlock(Properties properties) {
		super(properties);
	}

	@Override
	protected Tide openTide() {
		return Tide.ENDURE;
	}

	@Override
	protected ResourceKey<LootTable> harvestTable() {
		return HARVEST;
	}

	@Override
	protected SoundEvent openSound() {
		return ModSounds.ENDURE_BLOOM_OPEN;
	}

	@Override
	protected SoundEvent closeSound() {
		return ModSounds.ENDURE_BLOOM_CLOSE;
	}

	@Override
	protected int switchColour(boolean opening) {
		return opening ? 0xB9B6F0 : 0x6E7F74;
	}

	@Override
	protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
		return SHAPE;
	}

	/** The waterline's ground: healthy sculk, Sift Soil (in #dirt) and tide sand. */
	@Override
	protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos) {
		return SiftPlants.isSiftGround(state) || state.is(ModBlocks.TIDE_SAND);
	}
}
