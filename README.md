# Super Pong

A Godot Pong game with a computer opponent and local two-player mode. First to seven wins. No external assets or plugins are required.

Open `project.godot` in Godot 4.7.2 or newer and press F6/F5 to play.

| Key | Action |
| --- | --- |
| W / S | Move player 1 |
| Up / Down | Move player 2 in local mode |
| Space | Start or pause |
| R | Restart |
| M | Switch opponent mode |

## Browser publishing

The committed `docs/` folder contains the single-threaded web build. In Settings → Pages, select **Deploy from a branch**, branch **main**, and folder **/docs**, then save. Play at https://lionelbolling.github.io/Super-Pong/ after deployment.

After changing the game, install the matching Godot web export templates and run `godot --headless --path . --export-release Web docs/index.html`, then commit and push the updated `docs/` files. `docs/.gdignore` keeps exported files out of the Godot project, and `docs/.nojekyll` tells Pages to serve the build directly. Keyboard controls work on desktop browsers; touch controls are not included.
