package thesift.client.entity;

import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.util.Mth;

import thesift.entity.nester.NesterState;

/**
 * The Nester after Dungeons II's render (D-034): a big boxy head split at the mouth, its tan lower jaw
 * hinged at the back so the whole mouth gapes; two feathery antennae on top; a thin upright neck on four
 * long legs, the hind pair slanting back. It gallops leaning forward, and rears on its hind legs with its
 * forelegs up and its mouth wide to pounce. The clips are procedural, driven by the synced state and the
 * ticks since it changed (as the Blub's, D-021).
 */
public class NesterModel extends EntityModel<NesterRenderState> {
	private static final float HIND_SLANT = 0.3F;
	private final ModelPart neck;
	private final ModelPart head;
	private final ModelPart jaw;
	private final ModelPart[] antennae = new ModelPart[2];
	private final ModelPart[] legs = new ModelPart[4];

	public NesterModel(ModelPart root) {
		super(root);
		this.neck = root.getChild("neck");
		this.head = this.neck.getChild("head");
		this.jaw = this.head.getChild("jaw");
		this.antennae[0] = this.head.getChild("left_antenna");
		this.antennae[1] = this.head.getChild("right_antenna");
		String[] names = {"front_left_leg", "front_right_leg", "hind_left_leg", "hind_right_leg"};
		for (int i = 0; i < 4; i++) {
			this.legs[i] = root.getChild(names[i]);
		}
	}

	public static LayerDefinition createBodyLayer() {
		MeshDefinition mesh = new MeshDefinition();
		PartDefinition root = mesh.getRoot();
		// Legs of 10 reach the ground (24) from the hips at 14; the neck rises 9 from the hips into the jaw.
		PartDefinition neck = root.addOrReplaceChild("neck", CubeListBuilder.create().texOffs(40, 0).addBox(-2.5F, -9.0F, -2.0F, 5.0F, 9.0F, 4.0F),
				PartPose.offset(0.0F, 14.0F, 0.0F));
		// The head pivots at the mouth's hinge, at the back of the seam between head and jaw.
		PartDefinition head = neck.addOrReplaceChild("head", CubeListBuilder.create().texOffs(0, 0).addBox(-5.0F, -5.0F, -10.0F, 10.0F, 5.0F, 10.0F),
				PartPose.offset(0.0F, -12.0F, 3.0F));
		head.addOrReplaceChild("jaw", CubeListBuilder.create().texOffs(0, 15).addBox(-5.0F, 0.0F, -10.0F, 10.0F, 5.0F, 10.0F), PartPose.ZERO);
		head.addOrReplaceChild("left_antenna", CubeListBuilder.create().texOffs(16, 30).addBox(0.0F, -8.0F, -2.5F, 0.0F, 8.0F, 5.0F),
				PartPose.offsetAndRotation(2.5F, -5.0F, -2.0F, -0.15F, 0.5F, 0.12F));
		head.addOrReplaceChild("right_antenna", CubeListBuilder.create().texOffs(16, 30).mirror().addBox(0.0F, -8.0F, -2.5F, 0.0F, 8.0F, 5.0F),
				PartPose.offsetAndRotation(-2.5F, -5.0F, -2.0F, -0.15F, -0.5F, -0.12F));
		float[][] hips = {{2.0F, -1.5F}, {-2.0F, -1.5F}, {2.0F, 1.5F}, {-2.0F, 1.5F}};
		String[] names = {"front_left_leg", "front_right_leg", "hind_left_leg", "hind_right_leg"};
		for (int i = 0; i < 4; i++) {
			root.addOrReplaceChild(names[i], CubeListBuilder.create().texOffs(0, 30).addBox(-1.5F, 0.0F, -1.5F, 3.0F, 10.0F, 3.0F),
					PartPose.offset(hips[i][0], 14.0F, hips[i][1]));
		}
		return LayerDefinition.create(mesh, 64, 64);
	}

	@Override
	public void setupAnim(NesterRenderState state) {
		super.setupAnim(state);
		float t = state.ageInTicks;
		float s = state.stateTime;
		float walk = Math.min(1.0F, state.walkAnimationSpeed * 1.6F);
		float pos = state.walkAnimationPos;
		NesterState st = state.state;

		// Looking: the head turns toward what it looks at; idle, it bobs and its antennae sway.
		this.head.yRot = state.yRot * Mth.DEG_TO_RAD * 0.8F;
		this.head.xRot = state.xRot * Mth.DEG_TO_RAD * 0.5F + Mth.sin(t * 0.09F) * 0.03F;
		this.neck.xRot = 0.0F;
		this.neck.zRot = Mth.sin(t * 0.05F) * 0.02F;
		this.jaw.xRot = 0.0F;
		for (int i = 0; i < 2; i++) {
			this.antennae[i].xRot = -0.15F + Mth.sin(t * 0.11F + i * 1.7F) * 0.06F;
		}

		// Legs: a long-legged walk (diagonal pairs), or the gallop's bound (front pair, then hind pair),
		// leaning forward into it.
		boolean gallop = st == NesterState.GALLOP && walk > 0.4F;
		float rate = gallop ? 0.45F : 0.6F;
		for (int i = 0; i < 4; i++) {
			boolean front = i < 2;
			float phase = gallop ? (front ? 0.0F : Mth.PI) : (i == 0 || i == 3 ? 0.0F : Mth.PI);
			this.legs[i].xRot = Mth.cos(pos * rate + phase) * (gallop ? 0.9F : 0.6F) * walk + (front ? 0.0F : HIND_SLANT);
		}
		if (gallop) {
			this.neck.xRot = 0.45F + Mth.sin(pos * 0.9F) * 0.06F;
			this.head.xRot -= 0.45F;
			for (ModelPart antenna : this.antennae) {
				antenna.xRot = 0.35F; // swept back
			}
		}

		switch (st) {
			case TELL -> {
				// It heard something: antennae up and forward, head raised, mouth just open.
				float k = Math.min(1.0F, s / 5.0F);
				for (ModelPart antenna : this.antennae) {
					antenna.xRot = Mth.lerp(k, -0.15F, -0.55F);
				}
				this.head.xRot -= 0.2F * k;
				this.jaw.xRot = 0.15F * k;
			}
			case SEARCH -> {
				// Head low and sweeping, sniffing, the jaw chattering.
				this.neck.xRot = 0.35F;
				this.head.xRot = 0.25F;
				this.head.yRot = Mth.sin(s * 0.25F) * 0.6F;
				this.jaw.xRot = Math.max(0.0F, Mth.sin(s * 1.6F)) * 0.2F;
			}
			case GUARD -> {
				// Circling: forelegs half raised, antennae quivering.
				this.legs[0].xRot = this.legs[1].xRot = -0.3F + Mth.sin(t * 0.3F) * 0.1F;
				for (int i = 0; i < 2; i++) {
					this.antennae[i].zRot = Mth.sin(t * 2.6F + i) * 0.12F;
				}
			}
			case WINDUP -> {
				// Rearing back onto its hind legs, forelegs lifting, the mouth opening: the read.
				float k = Math.min(1.0F, s / 4.0F);
				this.neck.xRot = -0.3F * k;
				this.legs[0].xRot = this.legs[1].xRot = -1.0F * k;
				this.legs[2].xRot = this.legs[3].xRot = HIND_SLANT + 0.2F * k;
				this.head.xRot = 0.1F;
				this.jaw.xRot = 0.5F * k;
			}
			case LEAP, BITE -> {
				// The pounce: stretched forward, forelegs reaching, the head thrown back and the mouth wide;
				// the bite snaps it shut.
				this.neck.xRot = 0.7F;
				this.legs[0].xRot = this.legs[1].xRot = -1.5F;
				this.legs[2].xRot = this.legs[3].xRot = 0.9F;
				boolean snapped = st == NesterState.BITE && s >= 6.0F;
				this.head.xRot = snapped ? -0.5F : -0.95F;
				this.jaw.xRot = snapped ? 0.0F : 1.1F;
			}
			case RECOVERY -> this.neck.zRot = Mth.sin(s * 1.4F) * 0.25F * Math.max(0.0F, 1.0F - s / 12.0F); // a head shake
			case STAGGER -> {
				// Reeling: head low and swaying, the jaw hanging, antennae drooped.
				this.neck.xRot = 0.4F;
				this.neck.zRot = Mth.sin(s * 0.5F) * 0.3F;
				this.jaw.xRot = 0.35F;
				for (ModelPart antenna : this.antennae) {
					antenna.xRot = 0.6F;
				}
			}
			case DODGE -> {
				this.neck.zRot = 0.35F;
				this.legs[0].xRot = this.legs[1].xRot = -0.4F;
			}
			default -> {
			}
		}

		// Emerging and digging: the whole model rises out of the soil, or sinks into it.
		if (st == NesterState.EMERGE) {
			this.root().y = (1.0F - Math.min(1.0F, s / 40.0F)) * 26.0F;
			this.neck.zRot = Mth.sin(s * 1.2F) * 0.15F; // shaking off the soil
		} else if (st == NesterState.DIG) {
			this.root().y = Math.min(1.0F, s / 60.0F) * 26.0F;
			this.legs[0].xRot = Mth.sin(s * 1.1F) * 0.8F; // the forelegs paw
			this.legs[1].xRot = -this.legs[0].xRot;
		} else {
			this.root().y = 0.0F;
		}
	}
}
