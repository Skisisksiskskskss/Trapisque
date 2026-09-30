package thesift.client;

import net.fabricmc.api.ClientModInitializer;

/**
 * Client-only entrypoint. Rendering, models, particles and other client-side registration go here,
 * never in the common source set.
 */
public final class TheSiftClient implements ClientModInitializer {
	@Override
	public void onInitializeClient() {
	}
}
