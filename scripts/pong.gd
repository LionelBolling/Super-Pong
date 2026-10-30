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

func _ready() -> void:
	randomize()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
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
	if not playing or paused:
		return
	var left_input := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	left_y = clampf(left_y + left_input * 470 * delta, TOP + 45, BOTTOM - 45)
	if two_player:
		var right_input := float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
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
	label_at("LOCAL 2 PLAYER" if two_player else "PLAYER VS COMPUTER", Vector2(650, 40), 16, Color("93a4c3"))
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
	centered("SPACE  Play / Pause       R  Restart       M  Switch mode", 622, 16, Color("93a4c3"))
	if not playing or paused:
		draw_rect(Rect2(210, 240, 540, 165), Color("101d36"))
		centered("PAUSED" if paused else (winner if winner != "" else "READY TO RALLY?"), 297, 32)
		centered("Press SPACE to resume" if paused else "Press SPACE to play", 339, 21, CYAN)
		centered("M switches between computer and local two-player", 376, 16, Color("93a4c3"))
