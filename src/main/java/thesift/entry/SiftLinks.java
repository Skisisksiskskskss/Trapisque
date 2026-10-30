package thesift.entry;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;

import net.minecraft.core.BlockPos;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.saveddata.SavedData;
import net.minecraft.world.level.saveddata.SavedDataType;

import thesift.TheSift;

/**
 * Every known frame, its offered charge, and the Sift-side gate it links to (entry_path.md §6;
 * D-019: links are stored explicitly, never rediscovered through a POI search).
 */
public final class SiftLinks extends SavedData {
	/** A frame in the Overworld, the XP offered to it so far, and its gate once someone has crossed. */
	public record FrameLink(SiftFrame frame, int charge, Optional<SiftFrame> gate) {
		static final Codec<FrameLink> CODEC = RecordCodecBuilder.create(i -> i.group(
				SiftFrame.CODEC.fieldOf("frame").forGetter(FrameLink::frame),
				Codec.INT.optionalFieldOf("charge", 0).forGetter(FrameLink::charge),
				SiftFrame.CODEC.optionalFieldOf("gate").forGetter(FrameLink::gate)
		).apply(i, FrameLink::new));

		public boolean awake() {
			return this.charge >= Offering.PRICE;
		}
	}

	private static final Codec<SiftLinks> CODEC = FrameLink.CODEC.listOf().optionalFieldOf("frames", List.of())
			.xmap(SiftLinks::new, s -> new ArrayList<>(s.frames.values())).codec();

	public static final SavedDataType<SiftLinks> TYPE = new SavedDataType<>(TheSift.id("sift_links"), SiftLinks::new, CODEC, null);

	private final Map<BlockPos, FrameLink> frames = new LinkedHashMap<>();

	public SiftLinks() {
	}

	private SiftLinks(List<FrameLink> frames) {
		frames.forEach(f -> this.frames.put(f.frame().origin(), f));
	}

	public static SiftLinks get(MinecraftServer server) {
		return server.getDataStorage().computeIfAbsent(TYPE);
	}

	public Collection<FrameLink> frames() {
		return Collections.unmodifiableCollection(this.frames.values());
	}

	public Optional<FrameLink> frameWithBorder(BlockPos pos) {
		return this.frames.values().stream().filter(f -> f.frame().isBorder(pos)).findFirst();
	}

	public Optional<FrameLink> frameWithOpening(BlockPos pos) {
		return this.frames.values().stream().filter(f -> f.frame().inOpening(pos)).findFirst();
	}

	public Optional<FrameLink> frameWithGateOpening(BlockPos pos) {
		return this.frames.values().stream().filter(f -> f.gate().isPresent() && f.gate().get().inOpening(pos)).findFirst();
	}

	public FrameLink add(SiftFrame frame) {
		return this.frames.computeIfAbsent(frame.origin(), o -> {
			this.setDirty();
			return new FrameLink(frame, 0, Optional.empty());
		});
	}

	public FrameLink addCharge(SiftFrame frame, int points) {
		FrameLink old = this.add(frame);
		FrameLink updated = new FrameLink(frame, Math.min(Offering.PRICE, old.charge() + points), old.gate());
		this.frames.put(frame.origin(), updated);
		this.setDirty();
		return updated;
	}

	public FrameLink setGate(SiftFrame frame, SiftFrame gate) {
		FrameLink updated = new FrameLink(frame, this.add(frame).charge(), Optional.of(gate));
		this.frames.put(frame.origin(), updated);
		this.setDirty();
		return updated;
	}
}
