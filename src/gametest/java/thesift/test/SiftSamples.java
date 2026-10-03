package thesift.test;

/**
 * Where the worldgen tests sample the Sift: fixed patches far apart, not near a test, whose place
 * varies from run to run. The test server's seed is fixed, so each run reads the same land, and
 * tests that share the patches share their generation.
 */
final class SiftSamples {
	/** Each patch is (2 × PATCH + 1)² chunks. */
	static final int PATCH = 2;
	/** Patch centres, in chunks. */
	static final int[][] PATCHES = {{200, 200}, {-200, 200}, {200, -200}, {-200, -200}};

	private SiftSamples() {
	}
}
