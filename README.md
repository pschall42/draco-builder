# Draco Builder
## Kifass 2 Game Jam

This is an entry for the [Kifass 2 Game Jam](https://itch.io/jam/kifass-2), made using the [Building Games with DragonRuby book](https://book.dragonriders.community/) as a jumping off point, with some help from the [drb-profiling](https://github.com/aquila12/drb-profiling) library.

The aim of this project is to try to see what a fusion of a bullet hell, twin stick shooter, and deckbuilder would look like. I've got some things scaffolded out for those when I eventually get to integrating them.

As of right now this is still basically the same game from that book, though I've heavily refactored it and expanded upon it in order to use custom physics and separate that logic from rendering. It's clearly _not_ fully separated into components yet though, because they still have some influence on each other, but hey it's in dev and I normally only have about 24 - 26 hours per week to work on, so considering my time constraints I think it's going fairly well. Fortunately for me, the deadline was extended by a week, so we'll see what happens.

## TODO:
- Get projectiles to fire from a point relative to the dragon's mouth
- Change targets to proper enemies that spawn in waves
- Add boids behavior to the enemies
- Add firing bullets toward the player
- Add health/damage to player and enemies
- Add the deckbuilder stuff (there's going to be a ton here, probably won't finish it by the end of the jam)

## DONE (aside from debugging when things come up):
- Physics colliders
- Physics transforms
- Color interpolation and gradiants
- Music (attributions currently in sounds/*)
- Player animation
- Twin-stick input