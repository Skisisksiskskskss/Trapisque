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
 * Idle breathing, a waddle when walking and a settle when sitting are procedural; the hop, sing
 * and topple clips arrive with the AI (WP-051).
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

	public static LayerDefinition createBodyLayer() {
		MeshDefinition mesh = new MeshDefinition();
		PartDefinition root = mesh.getRoot();
		// The body pivots at its base centre, one pixel above the ground (the feet's height).
		PartDefinition body = root.addOrReplaceChild("body",
				CubeListBuilder.create().texOffs(0, 0).addBox(-3.5F, -6.0F, -3.5F, 7.0F, 6.0F, 7.0F)
						.texOffs(20, 13).addBox(-1.0F, -3.0F, 3.5F, 2.0F, 2.0F, 1.0F),
				PartPose.offset(0.0F, 23.0F, 0.0F));
		body.addOrReplaceChild("left_ear", CubeListBuilder.create().texOffs(0, 13).addBox(-1.0F, -4.0F, -0.5F, 2.0F, 4.0F, 1.0F),
				PartPose.offset(1.75F, -6.0F, 0.0F));
		body.addOrReplaceChild("right_ear", CubeListBuilder.create().texOffs(6, 13).addBox(-1.0F, -4.0F, -0.5F, 2.0F, 4.0F, 1.0F),
				PartPose.offset(-1.75F, -6.0F, 0.0F));
		CubeListBuilder foot = CubeListBuilder.create().texOffs(12, 13).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 1.0F, 2.0F);
		root.addOrReplaceChild("front_left_foot", foot, PartPose.offset(2.0F, 23.0F, -2.0F));
		root.addOrReplaceChild("front_right_foot", foot, PartPose.offset(-2.0F, 23.0F, -2.0F));
		root.addOrReplaceChild("back_left_foot", foot, PartPose.offset(2.0F, 23.0F, 2.0F));
		root.addOrReplaceChild("back_right_foot", foot, PartPose.offset(-2.0F, 23.0F, 2.0F));
		return LayerDefinition.create(mesh, 32, 32);
	}

	@Override
	public void setupAnim(BlubRenderState state) {
		super.setupAnim(state);
		float t = state.ageInTicks;
		float walk = Math.min(1.0F, state.walkAnimationSpeed * 2.0F);
		float pos = state.walkAnimationPos;
		// Breathing: a slow squash, softer while walking.
		float breath = Mth.sin(t * 0.08F) * 0.03F * (1.0F - walk);
		this.body.yScale = 1.0F - breath;
		this.body.xScale = 1.0F + breath * 0.5F;
		this.body.zScale = 1.0F + breath * 0.5F;
		// The waddle: a side-to-side roll and a little bounce in step.
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
		if (state.sitting) {
			this.body.y = 23.6F;
			this.body.yScale = 0.9F;
			this.leftEar.zRot = 0.4F;
			this.rightEar.zRot = -0.4F;
		}
	}
}
