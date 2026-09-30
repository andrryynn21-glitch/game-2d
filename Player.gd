extends Area2D

signal hit

## Kecepatan puncak pemain, dalam satuan kanvas per detik.
##
## Tipenya wajib ditulis: tanpa ": float" nilainya dianggap Variant, sehingga
## "input * speed" ikut jadi Variant dan baris "var target := input * speed"
## gagal menyimpulkan tipe saat skrip di-parse.
@export var speed: float = 400.0

## Lama kebal (dalam detik) setelah pemain kehilangan satu nyawa.
@export var invulnerability_time := 1.5

## Selang kedip saat pemain sedang kebal.
const BLINK_INTERVAL := 0.15

## Konstanta waktu peredaman gerak, dalam detik. Semakin kecil semakin "nyantol"
## ke jari; semakin besar semakin meluncur. 0.08 masih terasa responsif tapi
## menghilangkan hentakan kasar saat arah berubah mendadak.
const MOVE_SMOOTH_TIME := 0.08

## Radius efektif tubuh pemain, dipakai supaya karakter tidak pernah separuh
## keluar layar.
const BODY_RADIUS := 30.0

## Seberapa kuat efek squash & stretch saat bergerak cepat.
const STRETCH_AMOUNT := 0.14
const SQUASH_AMOUNT := 0.09

## Radius cahaya di belakang pemain.
const GLOW_RADIUS := 62.0

## Area yang boleh ditempati pemain, sudah dikurangi margin aman layar.
var _play_rect: Rect2

var _velocity := Vector2.ZERO
var _invulnerable := false
var _invulnerability_tween: Tween
var _default_frames: SpriteFrames

## Skala asli sprite dari scene; squash/stretch selalu dihitung relatif ke nilai
## ini, jangan dipaku ke angka tetap.
var _base_sprite_scale := Vector2.ONE

## Lapisan kontrol sentuh, dipasang oleh Main. Boleh null (misalnya saat scene
## Player dijalankan sendiri untuk pengetesan).
var _touch_controls: Node = null

var _glow: Sprite2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _trail: Line2D = $Trail


func _ready() -> void:
	_default_frames = _sprite.sprite_frames
	_base_sprite_scale = _sprite.scale

	_glow = Fx.make_glow(GLOW_RADIUS, Color.WHITE, 0.55)
	add_child(_glow)
	move_child(_glow, 0)

	_trail.setup(self)

	_refresh_play_rect()
	get_viewport().size_changed.connect(_refresh_play_rect)

	hide()


## Menghubungkan pemain ke lapisan kontrol sentuh.
func set_touch_controls(controls: Node) -> void:
	_touch_controls = controls


## Batas gerak dihitung ulang setiap layar berubah ukuran atau berotasi. Tanpa
## ini, pemain akan terkurung di area lama setelah HP diputar.
func _refresh_play_rect() -> void:
	_play_rect = SafeArea.get_play_rect(get_viewport(), BODY_RADIUS)


func _process(delta: float) -> void:
	var input := _read_input()

	# Peredaman eksponensial: bebas frame-rate, jadi terasa sama di HP 60 Hz
	# maupun 120 Hz.
	var target := input * speed
	var weight: float = 1.0 - exp(-delta / MOVE_SMOOTH_TIME)
	_velocity = _velocity.lerp(target, weight)

	position += _velocity * delta
	position = position.clamp(_play_rect.position, _play_rect.end)

	_update_animation(input)
	_update_stretch(delta)


## Menggabungkan kontrol sentuh dengan keyboard. Yang dorongannya lebih besar
## yang dipakai, sehingga keduanya bisa hidup berdampingan tanpa saling
## membatalkan.
func _read_input() -> Vector2:
	var keyboard := Input.get_vector("jalan_kiri", "jalan_kanan", "jalan_atas", "jalan_bawah")

	var touch := Vector2.ZERO
	if _touch_controls != null:
		touch = _touch_controls.get_direction()

	return touch if touch.length() > keyboard.length() else keyboard


## Animasi dipilih dari niat pemain (input), tapi arah hadapnya dari kecepatan
## nyata supaya sprite tidak berkedip balik arah saat pemain melepas jari.
func _update_animation(input: Vector2) -> void:
	if input.length() > 0.0:
		_sprite.play()
	else:
		_sprite.stop()

	if absf(_velocity.x) > absf(_velocity.y):
		if absf(_velocity.x) > 1.0:
			_sprite.animation = "walk"
			_sprite.flip_v = false
			_sprite.flip_h = _velocity.x < 0.0
	elif absf(_velocity.y) > 1.0:
		_sprite.animation = "up"
		_sprite.flip_v = _velocity.y > 0.0


## Squash & stretch ringan: memanjang searah gerak dan memipih di sisi lain.
## Murah, tapi inilah yang membuat gerakan terasa hidup.
func _update_stretch(delta: float) -> void:
	var ratio := minf(_velocity.length() / maxf(speed, 1.0), 1.0)
	var horizontal := absf(_velocity.x) > absf(_velocity.y)

	var stretch := 1.0 + STRETCH_AMOUNT * ratio
	var squash := 1.0 - SQUASH_AMOUNT * ratio

	var target := _base_sprite_scale
	if ratio > 0.01:
		if horizontal:
			target = Vector2(_base_sprite_scale.x * stretch, _base_sprite_scale.y * squash)
		else:
			target = Vector2(_base_sprite_scale.x * squash, _base_sprite_scale.y * stretch)

	var weight: float = 1.0 - exp(-delta / 0.09)
	_sprite.scale = _sprite.scale.lerp(target, weight)


## Memakai animasi dari skin yang dipilih pemain (null = sprite bawaan).
func set_frames(frames: SpriteFrames) -> void:
	_sprite.sprite_frames = frames if frames != null else _default_frames


## Menerapkan warna aksen skin ke cahaya dan jejak pemain.
func set_accent_color(color: Color) -> void:
	if _glow != null:
		_glow.modulate = Color(color.r, color.g, color.b, 0.55)
	_trail.set_accent_color(color)


func start(pos):
	_end_invulnerability()
	position = pos
	_velocity = Vector2.ZERO
	_sprite.scale = _base_sprite_scale
	_refresh_play_rect()
	show()
	_trail.clear_trail()
	$CollisionShape2D.disabled = false


## Dipanggil saat pemain kehilangan satu nyawa: kembali ke posisi aman dan
## kebal sementara supaya tidak langsung tertabrak mob berikutnya.
func respawn(pos) -> void:
	position = pos
	_velocity = Vector2.ZERO
	show()
	_trail.clear_trail()
	_start_invulnerability()


## Dipanggil saat game over untuk menyembunyikan pemain.
func hide_player() -> void:
	_end_invulnerability()
	_velocity = Vector2.ZERO
	hide()
	_trail.clear_trail()
	$CollisionShape2D.set_deferred("disabled", true)


func _start_invulnerability() -> void:
	_invulnerable = true
	_kill_invulnerability_tween()

	# Berkedip selama invulnerability_time detik.
	var loops := maxi(1, int(invulnerability_time / (BLINK_INTERVAL * 2.0)))
	_invulnerability_tween = create_tween().set_loops(loops)
	_invulnerability_tween.tween_property(_sprite, "modulate:a", 0.25, BLINK_INTERVAL)
	_invulnerability_tween.tween_property(_sprite, "modulate:a", 1.0, BLINK_INTERVAL)
	_invulnerability_tween.finished.connect(_end_invulnerability)


func _end_invulnerability() -> void:
	_invulnerable = false
	_kill_invulnerability_tween()
	_sprite.modulate.a = 1.0


func _kill_invulnerability_tween() -> void:
	if _invulnerability_tween and _invulnerability_tween.is_valid():
		_invulnerability_tween.kill()


## Apakah pemain sedang dalam masa kebal?
func is_invulnerable() -> bool:
	return _invulnerable


func _on_body_entered(_body):
	if is_invulnerable():
		return

	hit.emit()
