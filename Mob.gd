extends RigidBody2D

## Lama animasi mob muncul dan larut, dalam detik.
const SPAWN_TIME := 0.3
const DISSOLVE_TIME := 0.24

## Umur maksimum sebagai jaring pengaman. VisibleOnScreenNotifier2D biasanya
## sudah membuang mob yang keluar layar, tapi kalau karena satu dan lain hal
## sinyalnya tidak pernah datang, mob tidak boleh menumpuk selamanya.
const MAX_LIFETIME := 16.0

## Radius cahaya di belakang mob.
const GLOW_RADIUS := 44.0

## Apakah mob ini pernah benar-benar terlihat di layar.
##
## Penting: mob dilahirkan tepat di tepi layar, dan pada frame pertama
## VisibleOnScreenNotifier2D bisa melaporkan "screen_exited" sebelum mob sempat
## terlihat. Tanpa penjaga ini, sebagian mob akan lenyap seketika setelah lahir.
var _seen := false

## Sedang dalam proses larut; mencegah dissolve() dipanggil dua kali.
var _dying := false

var _glow: Sprite2D
var _base_sprite_scale := Vector2.ONE

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	_base_sprite_scale = _sprite.scale
	_play_random_animation()

	# Argumen kedua "false" berarti timer ikut berhenti saat permainan dijeda.
	# Tanpa itu, menjeda game selama belasan detik akan melarutkan semua mob dan
	# pemain mendapat layar bersih secara gratis.
	get_tree().create_timer(MAX_LIFETIME, false).timeout.connect(dissolve)

	_animate_spawn()


## Menerapkan tampilan skin: animasi dan warna cahaya.
func apply_skin(skin: SkinData) -> void:
	if skin.mob_frames != null:
		$AnimatedSprite2D.sprite_frames = skin.mob_frames
		_play_random_animation()

	_set_glow_color(skin.mob_glow_color)


## Memakai animasi dari skin yang dipilih pemain (null = sprite bawaan).
func apply_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return

	$AnimatedSprite2D.sprite_frames = frames
	_play_random_animation()


## Memilih satu animasi secara acak dari sprite yang sedang dipakai.
func _play_random_animation() -> void:
	var mob_types = $AnimatedSprite2D.sprite_frames.get_animation_names()
	if mob_types.is_empty():
		return

	$AnimatedSprite2D.play(mob_types[randi() % mob_types.size()])


func _set_glow_color(color: Color) -> void:
	if _glow == null:
		_glow = Fx.make_glow(GLOW_RADIUS, color, 0.4)
		add_child(_glow)
		move_child(_glow, 0)
	else:
		_glow.modulate = Color(color.r, color.g, color.b, 0.4)


## Mob mengembang masuk alih-alih muncul mendadak. Tanpa ini mob terasa
## "menyembul" di tepi layar, terutama di stage cepat.
func _animate_spawn() -> void:
	_sprite.scale = _base_sprite_scale * 0.2
	modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _base_sprite_scale, SPAWN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, SPAWN_TIME * 0.6) \
		.set_trans(Tween.TRANS_SINE)


## Melarutkan mob dengan halus lalu membuangnya. Dipakai saat pemain kehilangan
## nyawa: semua mob dibersihkan sekaligus dan pemain melihatnya memudar, bukan
## hilang begitu saja.
func dissolve() -> void:
	if _dying:
		return

	_dying = true
	$CollisionShape2D.set_deferred("disabled", true)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _base_sprite_scale * 1.5, DISSOLVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DISSOLVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	_seen = true


func _on_visible_on_screen_notifier_2d_screen_exited():
	# Hanya buang mob yang memang sudah pernah terlihat, supaya mob yang baru
	# lahir di tepi layar tidak ikut terhapus.
	if _seen:
		queue_free()
