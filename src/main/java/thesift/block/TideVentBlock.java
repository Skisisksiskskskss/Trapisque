package thesift.block;

import org.jspecify.annotations.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.IntegerProperty;

import thesift.block.entity.TideVentBlockEntity;
import thesift.registry.ModBlockEntities;

/**
 * The tide vent at the bottom of a tide basin: it floods its basin in Endure and drains it in
 * Thrive. {@link #BASIN} is the basin's inner half-width plus one, as worldgen carved it; 0 (any
 * vent a player places) is inert, so nobody floods a base by placing one.
 */
public class TideVentBlock extends BaseEntityBlock {
	public static final IntegerProperty BASIN = IntegerProperty.create("basin", 0, 5);

	public static int basinValue(int inner) {
		return inner + 1;
	}

	public static int inner(BlockState state) {
		return state.getValue(BASIN) - 1;
	}

	@SuppressWarnings("this-escape") // vanilla blocks register their default state the same way
	public TideVentBlock(BlockBehaviour.Properties properties) {
		super(properties);
		this.registerDefaultState(this.stateDefinition.any().setValue(BASIN, 0));
	}

	@Override
	public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
		return new TideVentBlockEntity(pos, state);
	}

	@Override
	public <T extends BlockEntity> @Nullable BlockEntityTicker<T> getTicker(Level level, BlockState state, BlockEntityType<T> type) {
		return level.isClientSide() || state.getValue(BASIN) == 0
				? null
				: createTickerHelper(type, ModBlockEntities.TIDE_VENT, TideVentBlockEntity::serverTick);
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
		builder.add(BASIN);
	}
}
