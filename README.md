# Super Pong

A Godot Pong game with a computer opponent and local two-player mode. First to seven wins. No external assets or plugins are required.

Open `project.godot` in Godot 4.6 or newer and press F6/F5 to play.

| Key | Action |
| --- | --- |
| W / S | Move player 1 |
| Up / Down | Move player 2 in local mode |
| Space | Start or pause |
| R | Restart |
| M | Switch opponent mode |

## Browser publishing

The GitHub Actions workflow exports a single-threaded web build and deploys it to GitHub Pages when pushed to `main`. In the repository's Settings → Pages, select **GitHub Actions** as the source. The expected URL for LionelBolling/Super-Pong is https://lionelbolling.github.io/Super-Pong/ after a successful deployment.

The repository and live site have not been published by this local setup. Keyboard controls work on desktop browsers; touch controls are not included.
