extends CanvasLayer

## Lapisan kontrol sentuh. Menyediakan satu API untuk Player.gd:
##   get_direction() -> Vector2  (panjang 0..1)
##
## Dua skema didukung, dipilih pemain di menu lewat GameSettings:
##
## GESER    - sentuh di mana saja lalu geser. Arah dihitung dari perpindahan
##            jari, bukan dari posisi absolut, sehingga jari tidak pernah
##            menutupi karakter. Inilah alasan mode ini jadi bawaan untuk game
##            menghindar.
## JOYSTICK - stik analog mengambang: muncul persis di tempat jempol menyentuh,
##            jauh lebih nyaman daripada stik posisi tetap di layar sempit.
##
## Keduanya digambar lewat _draw() sehingga tidak butuh aset art dan tetap tajam
## di resolusi layar apa pun.

## Jarak geser (satuan kanvas) yang setara dengan dorongan penuh.
const DRAG_RADIUS := 110.0

## Radius stik joystick, dan radius knob di dalamnya.
const STICK_RADIUS := 84.0
const KNOB_RADIUS := 34.0

## Dorongan di bawah ambang ini dianggap nol, supaya karakter tidak bergeser
## sendiri karena jempol yang bergetar sedikit.
const DEADZONE := 0.14

## Lama animasi muncul/hilangnya gambar kontrol, dalam detik.
const FADE_TIME := 0.18

## Warna kontrol; komponen alpha-nya dikalikan lagi dengan _visual_alpha.
var accent_color := Color(1, 1, 1)

var _active := false
var _direction := Vector2.ZERO

## Index jari yang sedang kita ikuti. -1 berarti tidak ada sentuhan.
var _touch_index := -1

## Titik acuan: untuk mode GESER ini titik tambat yang bisa bergeser, untuk
## mode JOYSTICK ini pusat stik yang tetap selama jari menempel.
var _origin := Vector2.ZERO
var _current := Vector2.ZERO

## 0 = gambar kontrol tak terlihat, 1 = terlihat penuh.
var _visual_alpha := 0.0
var _fade_tween: Tween

@onready var _visual: Control = $Visual


func _ready() -> void:
	_visual.draw.connect(_on_visual_draw)
	set_active(false)


## Menyalakan / mematikan kontrol. Dipanggil Main saat permainan mulai, selesai,
## atau dijeda. Mematikan kontrol juga melepas sentuhan yang sedang berjalan
## supaya karakter tidak terus melaju setelah permainan berhenti.
func set_active(active: bool) -> void:
	_active = active
	if not active:
		_release_touch()

	set_process_unhandled_input(active)


## Arah yang diminta pemain, panjang 0..1.
func get_direction() -> Vector2:
	return _direction


## Warna kontrol mengikuti aksen skin yang sedang dipakai.
func set_accent_color(color: Color) -> void:
	accent_color = color
	_visual.queue_redraw()


## Sengaja memakai _unhandled_input, bukan _input: dengan begitu tombol Control
## (misalnya tombol Jeda di HUD) mendapat giliran lebih dulu dan menandai event
## sebagai sudah ditangani, sehingga menekan tombol tidak ikut menggeser pemain.
func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Sentuhan pertama yang menang; jari kedua diabaikan supaya tidak
		# saling berebut kendali.
		if _touch_index != -1:
			return

		if GameSettings.control_scheme == GameSettings.ControlScheme.JOYSTICK \
				and not _is_in_stick_zone(event.position):
			return

		_touch_index = event.index
		_origin = event.position
		_current = event.position
		_direction = Vector2.ZERO
		_fade_visual(1.0)
		_visual.queue_redraw()
	elif event.index == _touch_index:
		_release_touch()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return

	_current = event.position

	match GameSettings.control_scheme:
		GameSettings.ControlScheme.JOYSTICK:
			_direction = _apply_deadzone((_current - _origin) / STICK_RADIUS)
		_:
			_direction = _apply_deadzone((_current - _origin) / DRAG_RADIUS)
			# Penambatan-ulang: begitu dorongan mentok, titik acuan ikut
			# bergeser. Tanpa ini jari yang sudah jauh dari titik awal harus
			# ditarik balik sepanjang jarak itu sebelum karakter mau berbalik.
			var overshoot := (_current - _origin).length() - DRAG_RADIUS
			if overshoot > 0.0:
				_origin += (_current - _origin).normalized() * overshoot

	_visual.queue_redraw()


## Membatasi vektor ke panjang 1 dan membuang dorongan yang terlalu kecil.
## Di luar dead zone, nilainya diskalakan ulang dari 0 supaya tidak ada lompatan
## kecepatan saat jari baru melewati ambang.
func _apply_deadzone(raw: Vector2) -> Vector2:
	var length := raw.length()
	if length <= DEADZONE:
		return Vector2.ZERO

	var scaled := (length - DEADZONE) / (1.0 - DEADZONE)
	return raw.normalized() * minf(scaled, 1.0)


## Mode joystick hanya menerima sentuhan di 60% bagian bawah layar, supaya ketukan
## di area atas (tempat HUD berada) tidak memunculkan stik.
func _is_in_stick_zone(position: Vector2) -> bool:
	var rect := get_viewport().get_visible_rect()
	return position.y >= rect.position.y + rect.size.y * 0.4


func _release_touch() -> void:
	_touch_index = -1
	_direction = Vector2.ZERO
	_fade_visual(0.0)
	_visual.queue_redraw()


func _fade_visual(target: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_visual_alpha, _visual_alpha, target, FADE_TIME) \
		.set_trans(Tween.TRANS_SINE)


func _set_visual_alpha(value: float) -> void:
	_visual_alpha = value
	_visual.queue_redraw()


## Menggambar kontrol. Untuk mode geser: cincin tipis di titik tambat dan titik
## kecil di posisi jari, dihubungkan garis. Untuk joystick: cincin besar dan
## knob yang mengikuti jari.
func _on_visual_draw() -> void:
	if _visual_alpha <= 0.01:
		return

	var base := accent_color
	var is_joystick := GameSettings.control_scheme == GameSettings.ControlScheme.JOYSTICK
	var radius := STICK_RADIUS if is_joystick else DRAG_RADIUS

	var ring_color := Color(base.r, base.g, base.b, 0.22 * _visual_alpha)
	var fill_color := Color(base.r, base.g, base.b, 0.08 * _visual_alpha)
	var knob_color := Color(base.r, base.g, base.b, 0.55 * _visual_alpha)

	_visual.draw_circle(_origin, radius, fill_color)
	_visual.draw_arc(_origin, radius, 0.0, TAU, 48, ring_color, 3.0, true)

	if is_joystick:
		var offset := (_current - _origin).limit_length(radius - KNOB_RADIUS * 0.5)
		_visual.draw_circle(_origin + offset, KNOB_RADIUS, knob_color)
	else:
		# Garis penunjuk dari titik tambat ke jari, plus titik di ujungnya.
		var tip := _origin + (_current - _origin).limit_length(radius)
		_visual.draw_line(_origin, tip, knob_color, 4.0, true)
		_visual.draw_circle(tip, 16.0, knob_color)
		_visual.draw_circle(_origin, 7.0, knob_color)
