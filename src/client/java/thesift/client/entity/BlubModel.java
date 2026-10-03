package thesift.client.entity;

import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.util.Mth;

/**
 * The Blub: a rounded 7 x 6 x 7 box with two upright ear tufts, four little feet and a tail tuft
 * (mob_blub.md). No separate head: its face is the body's front, as the Dungeons II first look shows.
 * The clips (mob_blub.md, animations) are procedural, driven by synced state and entity events:
 * idle, walk, hop, listen, sing, bathe, curl and the stack wobble; hurt and death are vanilla's.
 */
public class BlubModel extends EntityModel<BlubRenderState> {
	private final ModelPart body;
	private final ModelPart leftEar;
	private final ModelPart rightEar;
	private final ModelPart frontLeftFoot;
	private final ModelPart frontRightFoot;
	private final ModelPart backLeftFoot;
	private final ModelPart backRightFoot;

	public BlubModel(ModelPart root) {
		super(root);
		this.body = root.getChild("body");
		this.leftEar = this.body.getChild("left_ear");
		this.rightEar = this.body.getChild("right_ear");
		this.frontLeftFoot = root.getChild("front_left_foot");
		this.frontRightFoot = root.getChild("front_right_foot");
		this.backLeftFoot = root.getChild("back_left_foot");
		this.backRightFoot = root.getChild("back_right_foot");
	}

	/** The body, for layers that draw on it (the frond carried in its mouth). */
	public ModelPart body() {
		return this.body;
	}

	public static LayerDefinition createBodyLayer() {
		MeshDefinition mesh = new MeshDefinition();
		PartDefinition root = mesh.getRoot();
		// After the first look (owner rework): a 9 × 7 × 8 cube body, two long ears standing at the
		// front of its top, short legs. The body pivots at its base centre, one pixel above the ground.
		PartDefinition body = root.addOrReplaceChild("body",
				CubeListBuilder.create().texOffs(0, 0).addBox(-4.5F, -7.0F, -4.0F, 9.0F, 7.0F, 8.0F)
						.texOffs(36, 8).addBox(-1.0F, -3.0F, 4.0F, 2.0F, 2.0F, 1.0F),
				PartPose.offset(0.0F, 23.0F, 0.0F));
		body.addOrReplaceChild("left_ear", CubeListBuilder.create().texOffs(36, 0).addBox(-1.0F, -5.0F, -0.5F, 2.0F, 5.0F, 1.0F),
				PartPose.offset(2.25F, -7.0F, -1.5F));
		body.addOrReplaceChild("right_ear", CubeListBuilder.create().texOffs(42, 0).addBox(-1.0F, -5.0F, -0.5F, 2.0F, 5.0F, 1.0F),
				PartPose.offset(-2.25F, -7.0F, -1.5F));
		CubeListBuilder foot = CubeListBuilder.create().texOffs(48, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 1.0F, 2.0F);
		root.addOrReplaceChild("front_left_foot", foot, PartPose.offset(2.5F, 23.0F, -2.5F));
		root.addOrReplaceChild("front_right_foot", foot, PartPose.offset(-2.5F, 23.0F, -2.5F));
		root.addOrReplaceChild("back_left_foot", foot, PartPose.offset(2.5F, 23.0F, 2.5F));
		root.addOrReplaceChild("back_right_foot", foot, PartPose.offset(-2.5F, 23.0F, 2.5F));
		return LayerDefinition.create(mesh, 64, 32);
	}

	@Override
	public void setupAnim(BlubRenderState state) {
		super.setupAnim(state);
		float t = state.ageInTicks;
		float walk = Math.min(1.0F, state.walkAnimationSpeed * 2.0F);
		float pos = state.walkAnimationPos;
		// Idle: a slow breathing squash, softer while walking.
		float breath = Mth.sin(t * 0.08F) * 0.03F * (1.0F - walk);
		this.body.yScale = 1.0F - breath;
		this.body.xScale = 1.0F + breath * 0.5F;
		this.body.zScale = 1.0F + breath * 0.5F;
		// Walk: a side-to-side roll and a little bounce in step.
		this.body.zRot = Mth.sin(pos * 0.9F) * 0.12F * walk;
		this.body.y = 23.0F - Math.abs(Mth.sin(pos * 0.9F)) * 0.8F * walk;
		this.frontLeftFoot.xRot = Mth.cos(pos * 0.9F) * 0.9F * walk;
		this.backRightFoot.xRot = this.frontLeftFoot.xRot;
		this.frontRightFoot.xRot = -this.frontLeftFoot.xRot;
		this.backLeftFoot.xRot = -this.frontLeftFoot.xRot;
		// Ears: a lazy sway, and now and then a twitch.
		float twitch = Mth.sin(t * 0.7F) > 0.97F ? 0.25F : 0.0F;
		this.leftEar.zRot = 0.12F + Mth.sin(t * 0.05F) * 0.05F + twitch;
		this.rightEar.zRot = -0.12F - Mth.sin(t * 0.05F + 1.0F) * 0.05F;
		this.leftEar.xRot = -0.1F * walk;
		this.rightEar.xRot = -0.1F * walk;

		if (state.airborne) {
			// Hop: stretched in the air.
			this.body.yScale = 1.12F;
			this.body.xScale = 0.94F;
			this.body.zScale = 0.94F;
			this.leftEar.xRot = 0.35F;
			this.rightEar.xRot = 0.35F;
		}
		if (state.listening) {
			// Listen: ears straight up, the body swaying to the beat.
			this.leftEar.zRot = 0.02F;
			this.rightEar.zRot = -0.02F;
			this.leftEar.xRot = -0.15F;
			this.rightEar.xRot = -0.15F;
			this.body.zRot += Mth.sin(t * 0.52F) * 0.08F;
		}
		if (state.interested) {
			// Beg: head on one side, ears pricked, as a wolf watching a treat.
			this.body.zRot += 0.22F;
			this.leftEar.zRot = 0.05F;
			this.rightEar.zRot = -0.3F;
			this.leftEar.xRot = -0.2F;
			this.rightEar.xRot = -0.2F;
		}
		if (state.restless) {
			// The herald: quick ear flicks.
			this.leftEar.zRot += Mth.sin(t * 1.6F) * 0.25F;
			this.rightEar.zRot -= Mth.sin(t * 1.6F + 0.8F) * 0.25F;
		}
		if (state.sing > 0.0F) {
			// Sing: ears flick back and the body squashes, like a mouth opening.
			float s = Mth.sin(state.sing * Mth.PI);
			this.leftEar.xRot += 0.7F * s;
			this.rightEar.xRot += 0.7F * s;
			this.body.yScale *= 1.0F - 0.14F * s;
			this.body.xScale *= 1.0F + 0.07F * s;
			this.body.zScale *= 1.0F + 0.07F * s;
		}
		if (state.stacked) {
			// Stack wobble: a sway of up to 8 degrees, growing as the tower nears its fall.
			float amp = 0.07F + 0.07F * state.teeter;
			this.body.zRot += Mth.sin(t * 0.15F + state.towerLevel * 0.9F) * amp;
			this.body.xRot = Mth.sin(t * 0.11F + state.towerLevel * 1.3F) * amp * 0.5F;
		}
		if (state.sitting) {
			this.body.y = 23.6F;
			this.body.yScale = 0.9F;
			this.leftEar.zRot = 0.4F;
			this.rightEar.zRot = -0.4F;
		}
		if (state.curled) {
			// Curl: flattened, ears laid flat; the belly glows (the emissive layer).
			this.body.y = 23.8F;
			this.body.yScale = 0.7F + breath;
			this.body.xScale = 1.1F;
			this.body.zScale = 1.1F;
			this.leftEar.zRot = 1.35F;
			this.rightEar.zRot = -1.35F;
			this.leftEar.xRot = 0.2F;
			this.rightEar.xRot = 0.2F;
		}
		if (state.bathe > 0.0F) {
			// Bathe: lifted so it sits in the ichor up to the belly, bobbing gently; feet tucked.
			this.root().y = -(state.bathe + Mth.sin(t * 0.12F) * 0.02F) * 16.0F;
			this.frontLeftFoot.xRot = 0.0F;
			this.frontRightFoot.xRot = 0.0F;
			this.backLeftFoot.xRot = 0.0F;
			this.backRightFoot.xRot = 0.0F;
		}
	}
}
