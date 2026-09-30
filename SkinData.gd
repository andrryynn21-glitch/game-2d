class_name SkinData
extends Resource

## Satu skin menentukan tampilan pemain, musuh, peta, dan seluruh lapisan efek
## (gradien latar, partikel, cahaya, jejak).
## Biarkan sebuah field kosong untuk memakai tampilan bawaan (skin Klasik).

## Jenis partikel latar yang tersedia.
enum ParticleKind {
	DUST,   ## Debu yang melayang pelan ke segala arah.
	BUBBLE, ## Gelembung yang naik mantap.
	EMBER,  ## Bara yang naik cepat dan menyebar.
}

## Nama skin yang ditampilkan di menu.
@export var skin_name: String = "Klasik"

## Warna latar peta. Dipakai sebagai cadangan kalau shader gradien gagal dimuat.
@export var background_color: Color = Color(0.219608, 0.372549, 0.380392)

## Animasi pemain. Kosongkan untuk memakai sprite bawaan Player.tscn.
@export var player_frames: SpriteFrames

## Animasi musuh. Kosongkan untuk memakai sprite bawaan Mob.tscn.
@export var mob_frames: SpriteFrames

## Hiasan peta yang digambar menutupi seluruh layar (dasar laut, gelembung, dsb).
@export var map_texture: Texture2D

@export_group("Visual")

## Warna aksen: dipakai untuk cahaya pemain, jejak, kilat benturan, tombol HUD,
## dan gambar kontrol sentuh. Inilah warna yang paling menentukan "rasa" skin.
@export var accent_color: Color = Color("#7fe3c4")

## Warna gradien latar, dari atas ke bawah.
@export var gradient_top: Color = Color("#2d5f62")
@export var gradient_bottom: Color = Color("#0f2427")

## Kecepatan gelombang gradien latar. Kecil = tenang.
@export_range(0.0, 1.0, 0.01) var background_wave_speed: float = 0.12

## Warna partikel latar. Komponen alpha dipakai sebagai pengali kecerahan.
@export var particle_color: Color = Color("#d8f5ea")

## Jenis gerakan partikel latar.
@export var particle_kind: ParticleKind = ParticleKind.DUST

## Warna cahaya di belakang musuh.
@export var mob_glow_color: Color = Color("#ff8f6b")

@export_group("Dasar laut")

## Tekstur satu butir partikel latar. Kosong = titik cahaya radial bawaan.
@export var particle_texture: Texture2D

## Ikon nyawa di HUD. Kosong = hati bawaan. Gambarnya harus putih polos supaya
## HUD bisa mewarnainya ulang lewat modulate mengikuti aksen skin.
@export var life_icon: Texture2D

## Hiasan yang disebar di dasar layar (kerang, bintang laut, tanaman laut).
## Kosong = tidak ada hiasan sama sekali.
@export var decor_textures: Array[Texture2D] = []


## Daftar skin bawaan game.
static func create_presets() -> Array[SkinData]:
	return [
		_create_classic(),
		_create_underwater(),
		_create_reef(),
		_create_dusk(),
	]


static func _create_classic() -> SkinData:
	var skin := SkinData.new()
	skin.skin_name = "Klasik"
	skin.accent_color = Color("#8ef0cf")
	skin.gradient_top = Color("#356f72")
	skin.gradient_bottom = Color("#0d2023")
	skin.particle_color = Color("#dffaf1")
	skin.particle_kind = ParticleKind.DUST
	skin.mob_glow_color = Color("#ffb066")
	return skin


static func _create_underwater() -> SkinData:
	var skin := SkinData.new()
	skin.skin_name = "Bawah Laut"
	skin.background_color = Color("#0e4b73")
	skin.map_texture = _load_texture("res://art/underwater/underwater_map.svg")
	skin.player_frames = _build_player_frames()
	skin.mob_frames = _build_mob_frames()
	skin.accent_color = Color("#6fd8ff")
	skin.gradient_top = Color("#11618f")
	skin.gradient_bottom = Color("#04121f")
	skin.background_wave_speed = 0.18
	skin.particle_color = Color("#bfe9ff")
	skin.particle_kind = ParticleKind.BUBBLE
	skin.mob_glow_color = Color("#ffd166")
	skin.particle_texture = _load_texture("res://art/items/bubble.svg")
	skin.life_icon = _load_texture("res://art/items/shell_health.svg")
	skin.decor_textures = _build_sea_decor()
	return skin


## Skin keempat: terumbu karang yang lebih hangat dan lebih padat isinya.
## Kuda laut hijau naik pangkat jadi pemain, dan penghuni dasar laut (kepiting,
## bulu babi, kelomang, ikan buntal) yang jadi musuh — jadi arah ancamannya
## terasa lain meski aturan mainnya sama.
static func _create_reef() -> SkinData:
	var skin := SkinData.new()
	skin.skin_name = "Karang"
	skin.background_color = Color("#0d5f6e")
	skin.map_texture = _load_texture("res://art/reef/reef_map.svg")
	skin.player_frames = _build_reef_player_frames()
	skin.mob_frames = _build_reef_mob_frames()
	skin.accent_color = Color("#5ef0c0")
	skin.gradient_top = Color("#14798a")
	skin.gradient_bottom = Color("#04202b")
	skin.background_wave_speed = 0.14
	skin.particle_color = Color("#d7fff2")
	skin.particle_kind = ParticleKind.BUBBLE
	skin.mob_glow_color = Color("#ff7a59")
	skin.particle_texture = _load_texture("res://art/items/bubble.svg")
	skin.life_icon = _load_texture("res://art/items/shell_health.svg")
	skin.decor_textures = _build_sea_decor()
	return skin


## Skin ketiga yang dibangun sepenuhnya dari lapisan efek baru: sprite-nya sama
## dengan Klasik, hanya warna gradien, partikel bara, dan aksen hangat yang
## berbeda. Nol aset art baru, tapi suasananya benar-benar lain.
static func _create_dusk() -> SkinData:
	var skin := SkinData.new()
	skin.skin_name = "Senja"
	skin.background_color = Color("#3d2440")
	skin.accent_color = Color("#ffc46b")
	skin.gradient_top = Color("#8c3f63")
	skin.gradient_bottom = Color("#1b1024")
	skin.background_wave_speed = 0.08
	skin.particle_color = Color("#ffd9a0")
	skin.particle_kind = ParticleKind.EMBER
	skin.mob_glow_color = Color("#ff6b8f")
	return skin


## Ubur-ubur sebagai karakter. Nama animasi "up" dan "walk" dipakai oleh Player.gd.
static func _build_player_frames() -> SpriteFrames:
	var frames := _new_frames()
	_add_animation(frames, "up", ["res://art/underwater/jellyfish_up1.svg", "res://art/underwater/jellyfish_up2.svg"], 5.0)
	_add_animation(frames, "walk", ["res://art/underwater/jellyfish_walk1.svg", "res://art/underwater/jellyfish_walk2.svg"], 5.0)
	return _player_frames_or_null(frames)


## Penghuni laut sebagai musuh. Mob.gd memilih satu animasi secara acak, jadi
## setiap animasi di sini otomatis jadi satu jenis musuh — menambah ragam musuh
## tidak butuh kode baru sama sekali.
static func _build_mob_frames() -> SpriteFrames:
	var frames := _new_frames()
	_add_animation(frames, "swim", ["res://art/underwater/seahorse_1.svg", "res://art/underwater/seahorse_2.svg"], 3.5)
	_add_animation(frames, "glide", ["res://art/underwater/seahorse_3.svg", "res://art/underwater/seahorse_4.svg"], 3.5)
	_add_animation(frames, "puffer", ["res://art/underwater/pufferfish_1.svg", "res://art/underwater/pufferfish_2.svg"], 3.0)
	_add_animation(frames, "angry_jelly", ["res://art/underwater/jellyfish_angry_1.svg", "res://art/underwater/jellyfish_angry_2.svg"], 4.0)
	return _frames_or_null(frames)


## Kuda laut hijau sebagai karakter skin Karang: pose tegak untuk gerak naik-turun,
## pose berenang cepat untuk gerak menyamping.
static func _build_reef_player_frames() -> SpriteFrames:
	var frames := _new_frames()
	_add_animation(frames, "up", ["res://art/reef/seahorse_green_up1.svg", "res://art/reef/seahorse_green_up2.svg"], 5.0)
	_add_animation(frames, "walk", ["res://art/reef/seahorse_green_walk1.svg", "res://art/reef/seahorse_green_walk2.svg"], 6.0)
	return _player_frames_or_null(frames)


static func _build_reef_mob_frames() -> SpriteFrames:
	var frames := _new_frames()
	_add_animation(frames, "crab", ["res://art/reef/crab_1.svg", "res://art/reef/crab_2.svg"], 3.5)
	_add_animation(frames, "urchin", ["res://art/reef/urchin_1.svg", "res://art/reef/urchin_2.svg"], 2.5)
	_add_animation(frames, "hermit", ["res://art/reef/hermit_1.svg", "res://art/reef/hermit_2.svg"], 3.0)
	_add_animation(frames, "puffer", ["res://art/underwater/pufferfish_1.svg", "res://art/underwater/pufferfish_2.svg"], 3.0)
	return _frames_or_null(frames)


## Hiasan dasar laut, dipakai bersama oleh kedua skin laut.
static func _build_sea_decor() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path in [
		"res://art/items/seaweed.svg",
		"res://art/items/scallop.svg",
		"res://art/items/starfish.svg",
		"res://art/items/shell_closed.svg",
	]:
		var texture := _load_texture(path)
		if texture != null:
			textures.append(texture)

	return textures


static func _new_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	# Buang animasi bawaan supaya tidak ikut terpilih secara acak oleh mob.
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	return frames


static func _add_animation(frames: SpriteFrames, animation_name: String, texture_paths: Array, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, true)

	for path in texture_paths:
		var texture := _load_texture(path)
		if texture != null:
			frames.add_frame(animation_name, texture)

	# Animasi tanpa satu pun frame lebih buruk daripada tidak ada animasinya:
	# Mob.gd mengundi nama animasi secara acak, jadi animasi kosong akan membuat
	# sebagian musuh tampil sebagai sprite hilang.
	if frames.get_frame_count(animation_name) == 0:
		frames.remove_animation(animation_name)


## Tekstur yang gagal dimuat pulang sebagai null, bukan sebagai error yang
## menghentikan pembangunan skin. Ini yang membuat game tetap jalan (dengan
## tampilan bawaan) sebelum Godot sempat mengimpor aset SVG yang baru ditambahkan.
static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D


## SpriteFrames tanpa animasi apa pun sama saja dengan "tidak ada skin": pulangkan
## null supaya pemanggil memakai sprite bawaan .tscn alih-alih sprite kosong.
static func _frames_or_null(frames: SpriteFrames) -> SpriteFrames:
	return frames if frames.get_animation_names().size() > 0 else null


## Frame pemain diperlakukan lebih ketat daripada frame musuh: Player.gd memasang
## nama animasi "up" dan "walk" secara langsung, sementara Mob.gd mengundi dari
## nama yang memang ada. Jadi skin pemain yang hanya separuh terimpor akan memicu
## error setiap frame — lebih baik jatuh utuh ke sprite bawaan.
static func _player_frames_or_null(frames: SpriteFrames) -> SpriteFrames:
	if not frames.has_animation("up") or not frames.has_animation("walk"):
		return null

	return frames
