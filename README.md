# The Sift (`thesift`)

A Fabric mod for Minecraft: Java Edition 26.3 that adds a fan interpretation of **the Sift**, the dimension
from *Minecraft Dungeons II*, as a full fourth dimension.

> **Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.**

**Status:** `v0.1.1-alpha` (pre-release; the owner's playtest rework of M1): the Sift dimension, Singer's Meadow, the Tides, the way in through an Ancient City and back, ichor and tide basins, the Blub (befriended by music), and the advancement tab "The Sift". How to try it: `docs/PLAYTEST.md`. Progress: `docs/STATUS.md`.

## Building
- JDK 25 is required (Gradle itself runs on it; `gradle/gradle-daemon-jvm.properties` lets Gradle find or download one).
- `./gradlew build` → `build/libs/thesift-<version>.jar`
- `./gradlew runServer` / `./gradlew runClient` for development.

## Licence
Code: MIT (`LICENSE`). Original art and audio: All Rights Reserved (`LICENSE-ASSETS.md`).

The unrelated `trapisquebooklet.html` predates this project and is left untouched.
