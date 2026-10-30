extends Node2D

const WIDTH := 960.0
const TOP := 125.0
const BOTTOM := 555.0
const PADDLE := Vector2(14, 90)
const RADIUS := 9.0
const SPEED := 420.0
const WIN_SCORE := 7
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

func _ready() -> void:
	randomize()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/multiplayer.js"), true)
	setup_online_ui()
	queue_redraw()

func setup_online_ui() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(35, 65)
	add_child(panel)
	online_buttons = HBoxContainer.new()
	panel.add_child(online_buttons)
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
	if not OS.has_feature("web"):
		host.disabled = true
		join.disabled = true
		net_status.text = "Online play is available in the browser version."

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

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color("080e20"))
	label_at("SUPER PONG", Vector2(35, 43), 25, CYAN)
	label_at(("ONLINE - PLAYER 1" if is_host else "ONLINE - PLAYER 2") if online else ("LOCAL 2 PLAYER" if two_player else "PLAYER VS COMPUTER"), Vector2(650, 40), 16, Color("93a4c3"))
	centered("%d    %d" % scores, 101, 46)
	draw_line(Vector2(30, TOP), Vector2(930, TOP), Color("263550"), 2)
	draw_line(Vector2(30, BOTTOM), Vector2(930, BOTTOM), Color("263550"), 2)
	for y in range(140, 550, 28):
		draw_rect(Rect2(478, y, 4, 13), Color("263550"))
	draw_rect(Rect2(Vector2(56, left_y - 45), PADDLE), CYAN)
	draw_rect(Rect2(Vector2(890, right_y - 45), PADDLE), PINK)
	draw_circle(ball, RADIUS + 5, Color(0.33, 0.9, 0.94, 0.1))
	draw_circle(ball, RADIUS, Color.WHITE)
	centered("W / S   Player 1     •     ↑ / ↓   Player 2     •     First to 7", 592, 17, Color("93a4c3"))
	centered("W/S or arrows to move | Host: SPACE pause, R rematch" if online else "SPACE  Play / Pause       R  Restart       M  Switch mode", 622, 16, Color("93a4c3"))
	if not playing or paused:
		draw_rect(Rect2(210, 240, 540, 165), Color("101d36"))
		centered("PAUSED" if paused else (winner if winner != "" else "READY TO RALLY?"), 297, 32)
		centered(("Waiting for opponent..." if not connected else ("Host: SPACE to resume / rematch" if is_host else "Waiting for host...")) if online else ("Press SPACE to resume" if paused else "Press SPACE to play"), 339, 21, CYAN)
		centered("Host is left paddle. Guest is right paddle." if online else "M switches between computer and local two-player", 376, 16, Color("93a4c3"))
