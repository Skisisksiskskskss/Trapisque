package thesift.client.entity;

import net.minecraft.client.renderer.entity.state.HoldingEntityRenderState;

/** What the Blub model needs each frame (mob_blub.md, animations). */
public class BlubRenderState extends HoldingEntityRenderState {
	public boolean sitting;
	public boolean listening;
	public boolean curled;
	public boolean restless;
	/** Watching a frond in its owner's hand: head on one side (D-029). */
	public boolean interested;
	/** Riding another blub or carrying one: the tower sway. */
	public boolean stacked;
	/** Height in the tower (0 = the bottom), so each blub sways a little out of step. */
	public int towerLevel;
	public boolean airborne;
	/** 0..1 through the sing clip. */
	public float sing;
	/** 0..1 as the tower nears its fall. */
	public float teeter;
	/** 0..1, the belly glow (Endure, night, curled). */
	public float glow;
	/** Blocks to lift the model so a bathing blub sits in ichor up to the belly. */
	public float bathe;
}
