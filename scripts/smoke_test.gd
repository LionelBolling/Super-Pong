extends SceneTree

func _initialize() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child.call_deferred(game)
	call_deferred("check_game", game)

func check_game(game: Node) -> void:
	game.set_physics_process(false)
	game.start_game()
	assert(game.playing and game.scores == [0, 0])
	game.serve_delay = 0
	game.ball = Vector2(80, game.left_y)
	game.velocity = Vector2(-420, 0)
	game._physics_process(0.02)
	assert(game.velocity.x > 0, "Left paddle should reflect the ball")
	game.ball = Vector2(880, game.right_y)
	game.velocity = Vector2(420, 0)
	game._physics_process(0.02)
	assert(game.velocity.x < 0, "Right paddle should reflect the ball")
	game.ball = Vector2(400, 134)
	game.velocity = Vector2(200, -420)
	game._physics_process(0.02)
	assert(game.velocity.y > 0, "Top wall should reflect the ball")
	game.paused = true
	var position: Vector2 = game.ball
	game._physics_process(0.1)
	assert(game.ball == position, "Pause should stop movement")
	game.paused = false
	for i in range(2):
		game.point(0)
	assert(game.playing and game.scores[0] == 2, "Two points must not end the match")
	game.point(0)
	assert(not game.playing and game.winner == "PLAYER 1 WINS")
	game.play_ai()
	assert(game.playing and not game.two_player and game.scores == [0, 0], "VS AI starts a fresh solo match")
	game.start_game()
	assert(game.playing and game.scores == [0, 0] and game.winner == "")
	game.two_player = true
	game.point(1)
	var snapshot: Array = game.network_state()
	game.right_y = 500
	game.scores = [5, 5]
	game.apply_network_state(snapshot)
	assert(game.scores == [0, 1] and game.right_y == snapshot[1], "Guest should restore host state")
	game.online = true
	game.connected = true
	game.is_host = false
	position = game.ball
	game._physics_process(0.1)
	assert(game.ball == position, "Guest must not simulate authoritative physics")
	game.is_host = true
	game.remote_input = 1.0
	var before: float = game.right_y
	game._physics_process(0.02)
	assert(game.right_y > before, "Host should apply guest paddle input")
	print("PASS: paddle collisions, wall bounce, pause, scoring, win, restart")
	game.queue_free()
	quit()
