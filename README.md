# Super Pong

A Godot Pong game with a computer opponent, local two-player mode, and online browser multiplayer. First to seven wins.

## Online multiplayer

Open the browser game and click **Host online**. Share the eight-character room code with a friend. They open the same site, enter the code, and click **Join**. The match starts when connected. Keep both tabs open.

The host controls the left paddle and the guest controls the right paddle. Both can use W/S or Up/Down. The host uses Space to pause/resume and R to restart. Click **Leave online** to return to offline play.

Online play uses PeerJS 1.5.5 from jsDelivr and the public PeerJS signaling service to establish a direct WebRTC data connection. No account is needed. Room codes are invite-only, not passwords; share them only with your opponent. Availability depends on these services and your network. Some firewalls/NATs require a TURN relay, which this project does not provide; if connection times out, try another network. Native Godot builds retain computer/local play; online play is browser-only.

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
