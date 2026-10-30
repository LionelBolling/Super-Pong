extends Node2D

const WIDTH := 960.0
const TOP := 125.0
const BOTTOM := 555.0
const PADDLE := Vector2(14, 90)
const RADIUS := 9.0
const SPEED := 420.0
const WIN_SCORE := 3
const CYAN := Color("55e6ef")
const PINK := Color("ff759e")

var left_y := 340.0
var right_y := 340.0
var ball := Vector2(480, 340)
var velocity := Vector2.ZERO
var scores := [0, 0]
var playing := false
var paused := false
var two_player := false
var winner := ""
var serve_delay := 0.0
var font := ThemeDB.fallback_font
var online := false
var is_host := false
var connected := false
var remote_input := 0.0
var network_clock := 0.0
var net_status: Label
var room_input: LineEdit
var online_buttons: HBoxContainer
var leave_button: Button
var trail: Array[Vector2] = []
var sparks: Array[Dictionary] = []
var visual_time := 0.0
var last_visual_ball := Vector2(480, 340)
var last_visual_velocity := Vector2.ZERO
var visual_scores := [0, 0]
var score_flash := 0.0

func _ready() -> void:
	randomize()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/multiplayer.js"), true)
	setup_online_ui()
	queue_redraw()

func setup_online_ui() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(35, 566)
	add_child(panel)
	online_buttons = HBoxContainer.new()
	panel.add_child(online_buttons)
	var ai := Button.new()
	ai.text = "VS AI"
	ai.focus_mode = Control.FOCUS_NONE
	ai.pressed.connect(play_ai)
	online_buttons.add_child(ai)
	var local := Button.new()
	local.text = "Local 2P"
	local.focus_mode = Control.FOCUS_NONE
	local.pressed.connect(func(): two_player = true; start_game())
	online_buttons.add_child(local)
	var host := Button.new()
	host.focus_mode = Control.FOCUS_NONE
	host.text = "Host online"
	host.pressed.connect(func(): begin_online(true))
	online_buttons.add_child(host)
	room_input = LineEdit.new()
	room_input.placeholder_text = "Room code"
	room_input.max_length = 8
	room_input.custom_minimum_size.x = 130
	online_buttons.add_child(room_input)
	var join := Button.new()
	join.focus_mode = Control.FOCUS_NONE
	join.text = "Join"
	join.pressed.connect(func(): begin_online(false))
	online_buttons.add_child(join)
	leave_button = Button.new()
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.text = "Leave online"
	leave_button.visible = false
	leave_button.pressed.connect(leave_online)
	panel.add_child(leave_button)
	net_status = Label.new()
	net_status.add_theme_font_size_override("font_size", 13)
	panel.add_child(net_status)
	var theme := Theme.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("152642") if state == "hover" else Color("0a1128")
		style.border_color = PINK if state == "pressed" else Color("287787")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		theme.set_stylebox(state, "Button", style)
	theme.set_color("font_color", "Button", CYAN)
	theme.set_font_size("font_size", "Button", 15)
	panel.theme = theme
	if not OS.has_feature("web"):
		host.disabled = true
		join.disabled = true
		net_status.text = "Online play is available in the browser version."

func play_ai() -> void:
	if online:
		leave_online()
	room_input.release_focus()
	two_player = false
	start_game()

func begin_online(hosting: bool) -> void:
	online = true
	is_host = hosting
	connected = false
	playing = false
	paused = false
	two_player = true
	winner = ""
	scores = [0, 0]
	online_buttons.hide()
	leave_button.show()
	room_input.release_focus()
	JavaScriptBridge.eval("window.pongNet.start(%s, %s)" % [JSON.stringify("host" if hosting else "guest"), JSON.stringify(room_input.text)])
	queue_redraw()

func leave_online() -> void:
	JavaScriptBridge.eval("window.pongNet.leave()")
	online = false
	connected = false
	playing = false
	paused = false
	two_player = false
	winner = ""
	scores = [0, 0]
	online_buttons.show()
	leave_button.hide()
	net_status.text = ""
	queue_redraw()

func _process(delta: float) -> void:
	update_visuals(delta)
	if not online:
		return
	var info = JSON.parse_string(JavaScriptBridge.eval("window.pongNet.poll()"))
	if not info is Dictionary:
		return
	var was_connected := connected
	connected = info.get("connected", false)
	net_status.text = ("Room: %s | " % info.get("room", "")) + str(info.get("status", ""))
	if connected and not was_connected and is_host:
		start_game()
	if not connected:
		playing = false
		queue_redraw()
		return
	remote_input = float(info.get("input", 0.0))
	if not is_host and info.get("state") is Array:
		apply_network_state(info.state)
	network_clock += delta
	if network_clock >= 1.0 / 30.0:
		network_clock = 0.0
		var message := {"state": network_state()} if is_host else {"input": movement_input()}
		JavaScriptBridge.eval("window.pongNet.send(%s)" % JSON.stringify(message))
	queue_redraw()

func movement_input() -> float:
	return float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))

func network_state() -> Array:
	return [left_y, right_y, ball.x, ball.y, scores[0], scores[1], int(playing), int(paused), serve_delay, 1 if winner == "PLAYER 1 WINS" else (2 if winner != "" else 0)]

func apply_network_state(state: Array) -> void:
	if state.size() != 10:
		return
	left_y = clampf(float(state[0]), TOP + 45, BOTTOM - 45)
	right_y = clampf(float(state[1]), TOP + 45, BOTTOM - 45)
	ball = Vector2(float(state[2]), float(state[3]))
	scores = [int(state[4]), int(state[5])]
	playing = bool(state[6])
	paused = bool(state[7])
	serve_delay = float(state[8])
	winner = "PLAYER 1 WINS" if int(state[9]) == 1 else ("PLAYER 2 WINS" if int(state[9]) == 2 else "")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if online and (not connected or not is_host or event.keycode == KEY_M):
		return
	if event.keycode == KEY_SPACE:
		if not playing:
			start_game()
		else:
			paused = not paused
	elif event.keycode == KEY_R:
		start_game()
	elif event.keycode == KEY_M:
		two_player = not two_player
		playing = false
		paused = false
		winner = ""
		scores = [0, 0]
		reset_ball()
	queue_redraw()

func start_game() -> void:
	scores = [0, 0]
	left_y = 340.0
	right_y = 340.0
	winner = ""
	playing = true
	paused = false
	reset_ball()

func reset_ball() -> void:
	trail.clear()
	ball = Vector2(480, 340)
	var direction := -1.0 if randf() < 0.5 else 1.0
	velocity = Vector2(direction, randf_range(-0.45, 0.45)).normalized() * SPEED
	serve_delay = 0.8

func _physics_process(delta: float) -> void:
	if online and (not connected or not is_host):
		return
	if not playing or paused:
		return
	var left_input := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	if online:
		left_input = movement_input()
	left_y = clampf(left_y + left_input * 470 * delta, TOP + 45, BOTTOM - 45)
	if two_player:
		var right_input := float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
		if online:
			right_input = remote_input
		right_y = clampf(right_y + right_input * 470 * delta, TOP + 45, BOTTOM - 45)
	else:
		var target := ball.y if velocity.x > 0 else 340.0
		right_y = clampf(move_toward(right_y, target, 285 * delta), TOP + 45, BOTTOM - 45)
	if serve_delay > 0:
		serve_delay -= delta
		queue_redraw()
		return
	var previous := ball
	ball += velocity * delta
	if ball.y < TOP + RADIUS:
		ball.y = TOP + RADIUS
		velocity.y = absf(velocity.y)
	elif ball.y > BOTTOM - RADIUS:
		ball.y = BOTTOM - RADIUS
		velocity.y = -absf(velocity.y)
	if velocity.x < 0 and previous.x >= 70 + RADIUS and ball.x <= 70 + RADIUS and absf(ball.y - left_y) <= 45 + RADIUS:
		bounce(1, left_y)
		ball.x = 70 + RADIUS
	elif velocity.x > 0 and previous.x <= 890 - RADIUS and ball.x >= 890 - RADIUS and absf(ball.y - right_y) <= 45 + RADIUS:
		bounce(-1, right_y)
		ball.x = 890 - RADIUS
	if ball.x < -RADIUS:
		point(1)
	elif ball.x > WIDTH + RADIUS:
		point(0)
	queue_redraw()

func bounce(direction: float, paddle_y: float) -> void:
	var offset := clampf((ball.y - paddle_y) / 45, -1, 1)
	var speed := minf(velocity.length() * 1.06, 800)
	velocity = Vector2(direction * cos(offset * 1.05), sin(offset * 1.05)) * speed

func point(player: int) -> void:
	scores[player] += 1
	if scores[player] >= WIN_SCORE:
		winner = "PLAYER 1 WINS" if player == 0 else ("PLAYER 2 WINS" if two_player else "COMPUTER WINS")
		playing = false
	reset_ball()

func label_at(value: String, position: Vector2, size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color = Color.WHITE) -> void:
	var text_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	label_at(value, Vector2((WIDTH - text_width) / 2, y), size, color)

func burst(at: Vector2, tint: Color, count: int = 18) -> void:
	for i in range(count):
		var angle := randf() * TAU
		sparks.append({"p": at, "v": Vector2.from_angle(angle) * randf_range(60, 250), "life": 1.0, "color": tint})
	while sparks.size() > 160:
		sparks.pop_front()

func update_visuals(delta: float) -> void:
	visual_time += delta
	score_flash = maxf(0.0, score_flash - delta * 2.0)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].p += sparks[i].v * delta
		sparks[i].v *= exp(-delta * 3.0)
		sparks[i].life -= delta * 1.8
		if sparks[i].life <= 0:
			sparks.remove_at(i)
	if scores != visual_scores:
		var tint := CYAN if scores[0] > visual_scores[0] else PINK
		burst(Vector2(480, 340), tint, 60)
		score_flash = 1.0
		visual_scores = scores.duplicate()
		trail.clear()
	if ball.distance_to(last_visual_ball) > 180 or serve_delay > 0:
		trail.clear()
	elif playing and not paused and ball.distance_to(last_visual_ball) > 0.5:
		var motion := ball - last_visual_ball
		if motion.x * last_visual_velocity.x < 0 or motion.y * last_visual_velocity.y < 0:
			burst(ball, CYAN if ball.x < 480 else PINK)
		last_visual_velocity = motion
		trail.append(ball)
		while trail.size() > 24:
			trail.pop_front()
	elif not trail.is_empty() and (not playing or paused):
		trail.pop_front()
	last_visual_ball = ball
	queue_redraw()

func glow_line(a: Vector2, b: Vector2, tint: Color, width: float = 2.0) -> void:
	for layer in [16.0, 9.0, 4.0]:
		draw_line(a, b, Color(tint, 0.045), width + layer, true)
	draw_line(a, b, tint, width, true)

func glow_rect(rect: Rect2, tint: Color) -> void:
	for size in [16.0, 10.0, 5.0]:
		draw_rect(rect.grow(size), Color(tint, 0.035))
	draw_rect(rect, tint)
	draw_rect(rect.grow(-3), Color("eaffff"))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color("050817"))
	# A slow-moving starfield and perspective grid sit beneath the court.
	for i in range(65):
		var star := Vector2(fmod(i * 137.3, 960), fmod(i * 83.7 + visual_time * 5, 640))
		draw_circle(star, 1.0, Color(0.35, 0.6, 0.9, 0.12 + 0.12 * sin(visual_time + i)))
	for x in range(-600, 1600, 100):
		draw_line(Vector2(480 + (x - 480) * 0.18, 125), Vector2(x, 555), Color(0.15, 0.35, 0.6, 0.13), 1, true)
	for i in range(1, 13):
		var t := float(i) / 12.0
		var y := TOP + t * t * (BOTTOM - TOP)
		draw_line(Vector2(30, y), Vector2(930, y), Color(0.18, 0.35, 0.65, 0.13), 1)
	label_at("N E O N  /  S U P E R  P O N G", Vector2(35, 38), 23, CYAN)
	label_at(("ONLINE / PLAYER 1" if is_host else "ONLINE / PLAYER 2") if online else ("LOCAL / TWO PLAYERS" if two_player else "SOLO / VS AI"), Vector2(695, 37), 14, PINK)
	label_at("CYAN / PLAYER 1", Vector2(165, 88), 14, CYAN)
	label_at("MAGENTA / " + ("PLAYER 2" if two_player else "AI"), Vector2(652, 88), 14, PINK)
	centered("%02d   :   %02d" % scores, 89, 42, Color("eaffff"))
	centered("F I R S T   T O   3", 113, 12, Color("8c9ecb"))
	for i in range(WIN_SCORE):
		draw_circle(Vector2(195 + i * 22, 105), 4, CYAN if i < scores[0] else Color("1a3047"))
		draw_circle(Vector2(709 + i * 22, 105), 4, PINK if i < scores[1] else Color("352037"))
	glow_line(Vector2(30, TOP), Vector2(480, TOP), CYAN)
	glow_line(Vector2(480, TOP), Vector2(930, TOP), PINK)
	glow_line(Vector2(30, BOTTOM), Vector2(480, BOTTOM), CYAN)
	glow_line(Vector2(480, BOTTOM), Vector2(930, BOTTOM), PINK)
	for y in range(143, 550, 27):
		draw_rect(Rect2(479, y, 2, 11), Color(0.4, 0.65, 0.95, 0.22))
	for x in [30, 930]:
		var tint := CYAN if x == 30 else PINK
		glow_line(Vector2(x, TOP), Vector2(x, TOP + 28), tint)
		glow_line(Vector2(x, BOTTOM - 28), Vector2(x, BOTTOM), tint)
	glow_rect(Rect2(Vector2(56, left_y - 45), PADDLE), CYAN)
	glow_rect(Rect2(Vector2(890, right_y - 45), PADDLE), PINK)
	# Layered strokes form a tapered, luminous comet tail.
	for i in range(1, trail.size()):
		var strength := float(i) / trail.size()
		var tint := CYAN.lerp(PINK, float(i) / trail.size() * 0.6)
		draw_line(trail[i - 1], trail[i], Color(tint, strength * 0.06), strength * 34, true)
		draw_line(trail[i - 1], trail[i], Color(tint, strength * 0.24), strength * 15, true)
		draw_line(trail[i - 1], trail[i], Color(tint, strength * 0.8), maxf(1, strength * 5), true)
	for spark in sparks:
		var tint: Color = spark.color
		var life: float = spark.life
		draw_circle(spark.p, 7 * life, Color(tint, life * 0.08))
		draw_line(spark.p, spark.p - spark.v * 0.035, Color(tint, life), maxf(1, 2 * life), true)
	for size in [30.0, 22.0, 15.0]:
		draw_circle(ball, size, Color(CYAN, 0.06))
	draw_circle(ball, RADIUS + 1, CYAN)
	draw_circle(ball, RADIUS - 3, Color("f3ffff"))
	if serve_delay > 0 and playing:
		draw_arc(ball, 24 + serve_delay * 18, visual_time * 3, visual_time * 3 + TAU * 0.8, 48, Color(CYAN, 0.6), 2, true)
	if score_flash > 0:
		draw_rect(Rect2(30, TOP, 900, BOTTOM - TOP), Color(CYAN if scores[0] > scores[1] else PINK, score_flash * 0.09))
	label_at("W / S  MOVE", Vector2(720, 589), 14, CYAN)
	centered("W/S or arrows to move | Host: SPACE pause, R rematch" if online else "W/S  Player 1     UP/DOWN  Player 2     SPACE  Pause     R  Restart     M  Mode", 633, 13, Color("8b9cc4"))
	if not playing or paused:
		draw_rect(Rect2(208, 238, 544, 170), Color("080e23"))
		glow_line(Vector2(208, 238), Vector2(752, 238), PINK, 1)
		glow_line(Vector2(208, 408), Vector2(752, 408), CYAN, 1)
		centered("PAUSED" if paused else (winner if winner != "" else "ENTER THE NEON ARENA"), 291, 29, Color("efffff"))
		centered(("Waiting for opponent..." if not connected else ("Host: SPACE to resume / rematch" if is_host else "Waiting for host...")) if online else ("Press SPACE to resume" if paused else "Press SPACE or choose VS AI"), 335, 20, CYAN)
		centered("Host is cyan. Guest is magenta. First to 3." if online else "Fast rallies. Neon nights. First to 3 wins.", 375, 15, PINK)
