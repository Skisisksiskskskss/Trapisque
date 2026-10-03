package thesift.client.entity;

import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.client.renderer.entity.state.LivingEntityRenderState;
import net.minecraft.util.Mth;

/**
 * The Singer after Dungeons II's ad (RESEARCH.md S-I8; canon: "shaggy fur, tiny faces on their elongated
 * necks, pale antlers, short legs, and long arms"): a tall shaggy torso, a long neck with a tiny face at
 * its top, two feathery antlers, long blocky arms held out from the shoulders, short legs. Singing, it
 * lifts its arms and face and sways.
 */
public class SingerModel extends EntityModel<SingerModel.State> {
	private final ModelPart body;
	private final ModelPart head;
	private final ModelPart[] antlers = new ModelPart[2];
	private final ModelPart[] arms = new ModelPart[2];
	private final ModelPart[] legs = new ModelPart[2];

	public static class State extends LivingEntityRenderState {
		/** Ticks of singing left (0: not singing). */
		public float singing;
		public boolean restored;
	}

	public SingerModel(ModelPart root) {
		super(root);
		this.body = root.getChild("body");
		this.head = this.body.getChild("head");
		this.antlers[0] = this.head.getChild("left_antler");
		this.antlers[1] = this.head.getChild("right_antler");
		this.arms[0] = this.body.getChild("left_arm");
		this.arms[1] = this.body.getChild("right_arm");
		this.legs[0] = root.getChild("left_leg");
		this.legs[1] = root.getChild("right_leg");
	}

	public static LayerDefinition createBodyLayer() {
		MeshDefinition mesh = new MeshDefinition();
		PartDefinition root = mesh.getRoot();
		// Short legs of 5 from the hips at 19; the torso rises 12 above them, the neck 14 more.
		PartDefinition body = root.addOrReplaceChild("body", CubeListBuilder.create().texOffs(0, 19).addBox(-4.0F, -12.0F, -3.0F, 8.0F, 12.0F, 6.0F),
				PartPose.offset(0.0F, 19.0F, 0.0F));
		PartDefinition head = body.addOrReplaceChild("head", CubeListBuilder.create().texOffs(0, 0).addBox(-3.0F, -14.0F, -2.5F, 6.0F, 14.0F, 5.0F),
				PartPose.offset(0.0F, -12.0F, 0.0F));
		head.addOrReplaceChild("left_antler", CubeListBuilder.create().texOffs(22, 0).addBox(0.0F, -8.0F, -3.0F, 0.0F, 8.0F, 6.0F),
				PartPose.offsetAndRotation(2.0F, -13.5F, 0.0F, 0.0F, 0.0F, 0.55F));
		head.addOrReplaceChild("right_antler", CubeListBuilder.create().texOffs(22, 0).mirror().addBox(0.0F, -8.0F, -3.0F, 0.0F, 8.0F, 6.0F),
				PartPose.offsetAndRotation(-2.0F, -13.5F, 0.0F, 0.0F, 0.0F, -0.55F));
		body.addOrReplaceChild("left_arm", CubeListBuilder.create().texOffs(28, 19).addBox(0.0F, -1.0F, -2.0F, 4.0F, 14.0F, 4.0F),
				PartPose.offsetAndRotation(4.0F, -11.0F, 0.0F, 0.0F, 0.0F, -0.65F));
		body.addOrReplaceChild("right_arm", CubeListBuilder.create().texOffs(28, 19).mirror().addBox(-4.0F, -1.0F, -2.0F, 4.0F, 14.0F, 4.0F),
				PartPose.offsetAndRotation(-4.0F, -11.0F, 0.0F, 0.0F, 0.0F, 0.65F));
		root.addOrReplaceChild("left_leg", CubeListBuilder.create().texOffs(44, 19).addBox(-1.5F, 0.0F, -1.5F, 3.0F, 5.0F, 3.0F),
				PartPose.offset(2.0F, 19.0F, 0.0F));
		root.addOrReplaceChild("right_leg", CubeListBuilder.create().texOffs(44, 19).mirror().addBox(-1.5F, 0.0F, -1.5F, 3.0F, 5.0F, 3.0F),
				PartPose.offset(-2.0F, 19.0F, 0.0F));
		return LayerDefinition.create(mesh, 64, 64);
	}

	@Override
	public void setupAnim(State state) {
		super.setupAnim(state);
		float t = state.ageInTicks;
		float walk = Math.min(1.0F, state.walkAnimationSpeed * 1.5F);
		float pos = state.walkAnimationPos;
		float sing = Math.min(1.0F, state.singing / 10.0F);

		// Looking: the long neck turns and nods; idle, it sways and the antlers stir.
		this.head.yRot = state.yRot * Mth.DEG_TO_RAD * 0.7F;
		this.head.xRot = state.xRot * Mth.DEG_TO_RAD * 0.4F + Mth.sin(t * 0.05F) * 0.03F - 0.25F * sing;
		this.body.zRot = Mth.sin(t * 0.04F) * 0.02F + Mth.sin(t * 0.18F) * 0.08F * sing;
		this.body.xRot = 0.0F;
		for (int i = 0; i < 2; i++) {
			float side = i == 0 ? 1.0F : -1.0F;
			this.antlers[i].zRot = side * (0.55F + Mth.sin(t * 0.07F + i) * 0.04F + 0.15F * sing);
			// Arms: held out and down at rest, swinging a little as it walks, lifted wide to sing.
			float swing = Mth.cos(pos * 0.6F + (i == 0 ? 0.0F : Mth.PI)) * 0.4F * walk;
			this.arms[i].xRot = swing - 0.6F * sing + Mth.sin(t * 0.18F + i * Mth.PI) * 0.15F * sing;
			this.arms[i].zRot = -side * (0.65F + 0.75F * sing);
			this.legs[i].xRot = Mth.cos(pos * 0.8F + (i == 0 ? 0.0F : Mth.PI)) * 0.6F * walk;
		}
	}
}
