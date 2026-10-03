package thesift.client.entity;

import net.minecraft.client.renderer.entity.state.LivingEntityRenderState;

import thesift.entity.nester.NesterState;

/** What the Nester model needs each frame (mob_nester.md, animations). */
public class NesterRenderState extends LivingEntityRenderState {
	public NesterState state = NesterState.ROAM;
	/** Ticks (with the partial tick) since the state changed: the clips' clock. */
	public float stateTime;
	public boolean enduring;
	/** 1 for an enduring Nester's glow, else 0. */
	public float glow;
}
