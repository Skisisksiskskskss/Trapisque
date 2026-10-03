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
 * The Nester (mob_nester.md, Silhouette and look): a body high on four long two-jointed legs, a neck
 * thrust forward to a long snout with a hinged jaw, three fins folded along the neck that fan upright
 * when it hears, a short tail tuft; an enduring one grows a row of spikes down its back. The clips are
 * procedural, driven by the synced state and the ticks since it changed (as the Blub's, D-021).
 */
public class NesterModel extends EntityModel<NesterRenderState> {
	private final ModelPart body;
	private final ModelPart neck;
	private final ModelPart head;
	private final ModelPart jaw;
	private final ModelPart[] fins = new ModelPart[3];
	private final ModelPart tail;
	private final ModelPart spikes;
	private final ModelPart[] thighs = new ModelPart[4];
	private final ModelPart[] shins = new ModelPart[4];

	public NesterModel(ModelPart root) {
		super(root);
		this.body = root.getChild("body");
		this.neck = this.body.getChild("neck");
		this.head = this.neck.getChild("head");
		this.jaw = this.head.getChild("jaw");
		for (int i = 0; i < 3; i++) {
			this.fins[i] = this.neck.getChild("fin_" + i);
		}
		this.tail = this.body.getChild("tail");
		this.spikes = this.body.getChild("spikes");
		String[] legs = {"front_left", "front_right", "back_left", "back_right"};
		for (int i = 0; i < 4; i++) {
			this.thighs[i] = root.getChild(legs[i] + "_thigh");
			this.shins[i] = this.thighs[i].getChild("shin");
		}
	}

	public static LayerDefinition createBodyLayer() {
		MeshDefinition mesh = new MeshDefinition();
		PartDefinition root = mesh.getRoot();
		// The body pivots at its centre, 11 pixels up; legs of 6 + 6 reach the ground (24).
		PartDefinition body = root.addOrReplaceChild("body", CubeListBuilder.create().texOffs(0, 0).addBox(-5.0F, -4.0F, -7.0F, 10.0F, 8.0F, 14.0F),
				PartPose.offset(0.0F, 9.0F, 0.0F));
		PartDefinition neck = body.addOrReplaceChild("neck", CubeListBuilder.create().texOffs(0, 22).addBox(-2.0F, -8.0F, -2.0F, 4.0F, 8.0F, 4.0F),
				PartPose.offsetAndRotation(0.0F, -2.0F, -6.0F, 0.6F, 0.0F, 0.0F));
		PartDefinition head = neck.addOrReplaceChild("head", CubeListBuilder.create().texOffs(16, 22).addBox(-2.5F, -4.0F, -4.0F, 5.0F, 5.0F, 6.0F)
				.texOffs(38, 22).addBox(-1.5F, -2.5F, -8.0F, 3.0F, 3.0F, 4.0F), PartPose.offsetAndRotation(0.0F, -8.0F, 0.0F, -0.6F, 0.0F, 0.0F));
		head.addOrReplaceChild("jaw", CubeListBuilder.create().texOffs(38, 29).addBox(-1.5F, 0.0F, -4.0F, 3.0F, 1.0F, 4.0F),
				PartPose.offset(0.0F, 0.5F, -4.0F));
		for (int i = 0; i < 3; i++) {
			neck.addOrReplaceChild("fin_" + i, CubeListBuilder.create().texOffs(34, 34).addBox(0.0F, -4.0F, 0.0F, 0.0F, 4.0F, 3.0F),
					PartPose.offset(0.0F, -1.5F - i * 2.6F, 2.0F));
		}
		body.addOrReplaceChild("tail", CubeListBuilder.create().texOffs(20, 34).addBox(-1.0F, -1.0F, 0.0F, 2.0F, 2.0F, 5.0F),
				PartPose.offsetAndRotation(0.0F, -2.0F, 7.0F, -0.4F, 0.0F, 0.0F));
		CubeListBuilder spikes = CubeListBuilder.create();
		for (int z = -4; z <= 5; z += 3) {
			spikes.texOffs(40, 34).addBox(-0.5F, -4.0F, z, 1.0F, 4.0F, 1.0F);
		}
		body.addOrReplaceChild("spikes", spikes, PartPose.offset(0.0F, -4.0F, 0.0F));
		float[][] hips = {{3.5F, -5.0F}, {-3.5F, -5.0F}, {3.5F, 5.0F}, {-3.5F, 5.0F}};
		String[] legs = {"front_left", "front_right", "back_left", "back_right"};
		for (int i = 0; i < 4; i++) {
			PartDefinition thigh = root.addOrReplaceChild(legs[i] + "_thigh",
					CubeListBuilder.create().texOffs(0, 34).addBox(-1.5F, 0.0F, -1.5F, 3.0F, 6.0F, 3.0F), PartPose.offset(hips[i][0], 12.0F, hips[i][1]));
			thigh.addOrReplaceChild("shin", CubeListBuilder.create().texOffs(12, 34).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 6.0F, 2.0F),
					PartPose.offset(0.0F, 6.0F, 0.0F));
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
		this.spikes.visible = state.enduring;

		// Looking: the neck turns toward what it looks at, the head pitches.
		this.neck.yRot = state.yRot * Mth.DEG_TO_RAD * 0.6F;
		this.head.xRot = -0.6F + state.xRot * Mth.DEG_TO_RAD * 0.5F;
		// Idle: a head bob and a weight shift.
		this.neck.xRot += Mth.sin(t * 0.09F) * 0.04F;
		this.body.zRot = Mth.sin(t * 0.05F) * 0.02F;

		// Legs: a long-legged trot (diagonal pairs), or the gallop's bound (pairs front and back).
		boolean gallop = st == NesterState.GALLOP && walk > 0.4F;
		for (int i = 0; i < 4; i++) {
			boolean front = i < 2;
			float phase = gallop ? (front ? 0.0F : Mth.PI) : (i == 0 || i == 3 ? 0.0F : Mth.PI);
			float swing = Mth.cos(pos * (gallop ? 0.45F : 0.6F) + phase);
			this.thighs[i].xRot = swing * (gallop ? 1.0F : 0.7F) * walk;
			this.shins[i].xRot = Math.max(0.0F, -Mth.sin(pos * (gallop ? 0.45F : 0.6F) + phase)) * 0.8F * walk;
		}
		this.body.xRot = gallop ? 0.12F + Mth.sin(pos * 0.9F) * 0.06F : 0.0F;
		this.body.y = 9.0F - (gallop ? Math.abs(Mth.sin(pos * 0.45F)) * 1.2F : 0.0F);
		this.tail.xRot = -0.4F + Mth.sin(t * 0.1F) * 0.1F + (gallop ? 0.3F : 0.0F);

		// The crest: folded along the neck at rest, fanned upright when it is alert.
		float fan = switch (st) {
			case TELL -> Math.min(1.0F, s / 5.0F);
			case GALLOP, SEARCH, GUARD, DODGE -> 1.0F;
			default -> 0.0F;
		};
		float droop = st == NesterState.RECOVERY || st == NesterState.STAGGER ? 0.4F : 0.0F;
		float rattle = st == NesterState.GUARD ? Mth.sin(t * 2.6F) * 0.12F : 0.0F;
		for (int i = 0; i < 3; i++) {
			this.fins[i].xRot = Mth.lerp(fan, 1.25F, -0.15F + i * 0.1F) + droop + Mth.sin(t * 0.13F + i) * 0.03F;
			this.fins[i].zRot = rattle * (i % 2 == 0 ? 1 : -1);
		}
		this.jaw.xRot = 0.0F;

		switch (st) {
			case TELL -> {
				// Head up and turned: it heard something.
				this.neck.xRot = 0.35F;
				this.head.xRot = -0.35F + state.xRot * Mth.DEG_TO_RAD * 0.5F;
			}
			case SEARCH -> {
				// Head low, sweeping side to side, sniffing.
				this.neck.xRot = 1.05F;
				this.head.xRot = -0.9F;
				this.neck.yRot = Mth.sin(s * 0.25F) * 0.6F;
				this.jaw.xRot = Math.max(0.0F, Mth.sin(s * 1.6F)) * 0.15F;
			}
			case WINDUP, BITE -> {
				// Crouched, crest flat, jaw open: the read.
				float k = Math.min(1.0F, s / 4.0F);
				this.body.y = 9.0F + 2.5F * k;
				for (ModelPart thigh : this.thighs) {
					thigh.xRot = -0.5F * k;
				}
				for (ModelPart shin : this.shins) {
					shin.xRot = 1.0F * k;
				}
				this.neck.xRot = 0.9F;
				this.head.xRot = -0.8F;
				this.jaw.xRot = st == NesterState.BITE && s >= 6.0F ? 0.0F : 0.6F * k;
				for (ModelPart fin : this.fins) {
					fin.xRot = 1.35F;
				}
			}
			case LEAP -> {
				// Stretched out, jaw open, legs thrown back and forward.
				this.body.xRot = -0.15F;
				this.thighs[0].xRot = this.thighs[1].xRot = -1.1F;
				this.thighs[2].xRot = this.thighs[3].xRot = 0.9F;
				for (ModelPart shin : this.shins) {
					shin.xRot = 0.2F;
				}
				this.neck.xRot = 1.0F;
				this.head.xRot = -0.9F;
				this.jaw.xRot = 0.7F;
			}
			case RECOVERY -> {
				// Standing back up with a head shake.
				this.neck.zRot = Mth.sin(s * 1.4F) * 0.25F * Math.max(0.0F, 1.0F - s / 12.0F);
			}
			case STAGGER -> {
				// Reeling: head low, swaying, crest drooped.
				this.neck.xRot = 1.1F;
				this.neck.zRot = Mth.sin(s * 0.5F) * 0.3F;
				this.body.zRot = Mth.sin(s * 0.5F + 1.0F) * 0.1F;
			}
			case DODGE -> {
				this.body.zRot = 0.35F;
				for (ModelPart shin : this.shins) {
					shin.xRot = 0.6F;
				}
			}
			default -> {
			}
		}
		if (st != NesterState.RECOVERY && st != NesterState.STAGGER) {
			this.neck.zRot = 0.0F;
		}

		// Emerging and digging: the whole model rises out of the soil, or sinks into it.
		if (st == NesterState.EMERGE) {
			this.root().y = (1.0F - Math.min(1.0F, s / 40.0F)) * 22.0F;
			this.neck.zRot = Mth.sin(s * 1.2F) * 0.15F; // shaking off the soil
		} else if (st == NesterState.DIG) {
			this.root().y = Math.min(1.0F, s / 60.0F) * 22.0F;
			this.thighs[0].xRot = Mth.sin(s * 1.1F) * 0.8F; // the forelegs paw
			this.thighs[1].xRot = -this.thighs[0].xRot;
		} else {
			this.root().y = 0.0F;
		}
	}
}
