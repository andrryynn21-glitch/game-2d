class_name Pickup
extends Area2D

## Item yang bisa diambil pemain: mutiara, koin, peti harta karun, dan kerang nyawa.
##
## Polanya sengaja dibuat sejajar dengan Mob.gd (animasi muncul, larut, umur
## maksimum yang ikut terjeda) supaya Main.gd bisa mengurus keduanya dengan cara
## yang sama lewat grup node.
##
## Satu perbedaan yang menentukan: pickup lahir DI DALAM layar, bukan meluncur dari
## tepi seperti mob. Itulah yang membuatnya jadi keputusan — pemain harus menilai
## apakah nilai item sepadan dengan risiko mendekatinya — bukan sekadar hadiah
## yang jatuh sendiri ke tangan.

## Dikirim saat pemain menyentuh item ini. "at" adalah titik tempat item diambil,
## dipakai Main untuk meledakkan partikel di tempat yang benar.
signal collected(kind: Kind, value: int, at: Vector2)

enum Kind {
	PEARL, ## Mutiara bercahaya: sering muncul, nilainya kecil.
	COIN,  ## Koin: agak lebih jarang, nilainya dua kali mutiara.
	CHEST, ## Peti harta karun: jarang, nilainya besar.
	LIFE,  ## Kerang nyawa: memulihkan satu nyawa, bukan skor.
}

## Tekstur, nilai, label popup, warna kilau, dan skala tampil per jenis.
##
## Skala disetel per jenis, bukan satu angka untuk semua, karena berkas SVG-nya
## berbeda ukuran; angka-angka ini membuat keempatnya terlihat sebesar ~50 px.
const KIND_DATA := {
	Kind.PEARL: {
		"texture": "res://art/items/pearl.svg",
		"value": 5,
		"label": "+5",
		"color": Color(0.961, 0.816, 0.996),
		"scale": 0.62,
	},
	Kind.COIN: {
		"texture": "res://art/items/coin.svg",
		"value": 10,
		"label": "+10",
		"color": Color(0.984, 0.749, 0.141),
		"scale": 0.70,
	},
	Kind.CHEST: {
		"texture": "res://art/items/treasure_chest.svg",
		"value": 25,
		"label": "+25",
		"color": Color(0.988, 0.827, 0.302),
		"scale": 0.60,
	},
	Kind.LIFE: {
		"texture": "res://art/items/shell_health.svg",
		"value": 1,
		"label": "+1 Nyawa",
		"color": Color(0.984, 0.443, 0.522),
		"scale": 0.78,
	},
}

## Lama animasi item muncul dan larut, dalam detik.
const SPAWN_TIME := 0.34
const DISSOLVE_TIME := 0.22

## Umur item sebelum menghilang sendiri. Lebih pendek dari umur mob dengan
## sengaja: item yang menetap selamanya berubah jadi tugas yang harus diambil,
## bukan tawaran yang boleh ditolak.
const PICKUP_LIFETIME := 7.0

## Gerak mengapung: setengah putaran naik-turun sekian detik, sejauh sekian piksel.
const BOB_TIME := 0.9
const BOB_HEIGHT := 9.0

## Miringnya item saat mengapung, dalam radian (~6 derajat).
const SWAY_ANGLE := 0.11

## Radius cahaya di belakang item.
const GLOW_RADIUS := 30.0

var _kind: Kind = Kind.PEARL

## Sedang dalam proses larut; mencegah item diambil atau dilarutkan dua kali.
var _dying := false

var _bob_tween: Tween
var _base_sprite_scale := Vector2.ONE

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_kind()

	# Argumen kedua "false" berarti timer ikut berhenti saat permainan dijeda —
	# alasannya sama dengan yang sudah ditulis di Mob.gd: menjeda game tidak boleh
	# mengubah isi layar.
	get_tree().create_timer(PICKUP_LIFETIME, false).timeout.connect(dissolve)

	_animate_spawn()


## Menentukan jenis item ini. Dipanggil Main sebelum node masuk ke scene, jadi
## sengaja hanya menyimpan pilihannya; tampilannya dipasang di _ready() ketika
## anak-anak node sudah pasti siap.
func configure(kind: Kind) -> void:
	_kind = kind


## Nilai item: jumlah skor, atau jumlah nyawa untuk Kind.LIFE.
func get_value() -> int:
	return int(KIND_DATA[_kind]["value"])


## Label popup HUD untuk sebuah jenis, misalnya "+10".
static func label_for(kind: Kind) -> String:
	return str(KIND_DATA[kind]["label"])


## Warna kilau dan popup untuk sebuah jenis.
static func color_for(kind: Kind) -> Color:
	var color: Color = KIND_DATA[kind]["color"]
	return color


## Ikon sebuah jenis, untuk dipakai di HUD. Bisa null kalau berkasnya belum diimpor.
static func texture_for(kind: Kind) -> Texture2D:
	var path := str(KIND_DATA[kind]["texture"])
	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D


## Memasang tampilan sesuai jenis. Sprite2D di Pickup.tscn sengaja dibiarkan tanpa
## tekstur: satu scene melayani keempat jenis item, dan teksturnya baru diketahui
## di sini.
func _apply_kind() -> void:
	var data: Dictionary = KIND_DATA[_kind]

	var texture := texture_for(_kind)
	if texture != null:
		_sprite.texture = texture

	_base_sprite_scale = Vector2.ONE * float(data["scale"])
	_sprite.scale = _base_sprite_scale

	var glow := Fx.make_glow(GLOW_RADIUS, color_for(_kind), 0.55)
	add_child(glow)
	move_child(glow, 0)


## Item mengembang masuk lalu mulai mengapung di tempat. Gerak apungnya bukan
## hiasan: item yang diam membeku di antara mob yang berseliweran mudah terbaca
## sebagai bagian dari latar.
func _animate_spawn() -> void:
	_sprite.scale = _base_sprite_scale * 0.2
	modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _base_sprite_scale, SPAWN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, SPAWN_TIME * 0.6) \
		.set_trans(Tween.TRANS_SINE)

	_start_bob()


## Naik-turun sambil miring pelan, berulang selamanya. Dijalankan pada Sprite2D,
## bukan pada node akar, supaya position akar tetap persis titik kemunculan —
## itulah titik yang dipakai ledakan partikel saat item diambil.
func _start_bob() -> void:
	_bob_tween = create_tween().set_loops()

	_sprite.position.y = BOB_HEIGHT * 0.5
	_sprite.rotation = -SWAY_ANGLE

	_bob_tween.tween_property(_sprite, "position:y", -BOB_HEIGHT * 0.5, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE)
	_bob_tween.parallel().tween_property(_sprite, "rotation", SWAY_ANGLE, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_sprite, "position:y", BOB_HEIGHT * 0.5, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE)
	_bob_tween.parallel().tween_property(_sprite, "rotation", -SWAY_ANGLE, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE)


## Melarutkan item dengan halus lalu membuangnya. Dipanggil oleh timer umur, dan
## oleh Main lewat call_group("pickups", "dissolve") saat layar dibersihkan.
func dissolve() -> void:
	if _dying:
		return

	_dying = true
	$CollisionShape2D.set_deferred("disabled", true)

	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _base_sprite_scale * 0.5, DISSOLVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, DISSOLVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Item diambil: melesat membesar sebentar lalu hilang, supaya sentuhan pemain
## punya jawaban di tempat kejadian — bukan hanya angka yang berubah di HUD.
func _collect() -> void:
	if _dying:
		return

	_dying = true
	$CollisionShape2D.set_deferred("disabled", true)

	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	collected.emit(_kind, get_value(), global_position)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _base_sprite_scale * 1.8, DISSOLVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DISSOLVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Pemain adalah Area2D, jadi yang dipakai "area_entered", bukan "body_entered".
##
## Penyaringan grup itu wajib: mob juga ada di collision layer 1, dan meski mob
## sebagai RigidBody2D hanya bisa memicu body_entered, penjaga ini yang memastikan
## item tidak pernah "diambil" oleh sesuatu selain pemain kalau nanti ada Area2D
## lain di layer yang sama.
func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return

	_collect()
