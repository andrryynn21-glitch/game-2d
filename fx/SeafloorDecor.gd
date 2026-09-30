extends Node2D

## Hiasan dasar laut: tanaman laut, kerang, dan bintang laut yang disebar di
## bagian bawah layar.
##
## Murni latar — tidak punya tabrakan dan tidak pernah ikut logika permainan.
## Tujuannya satu: memberi "dasar" pada layar, supaya pemain merasa berada di
## suatu tempat alih-alih melayang di bidang berwarna.
##
## Kosong dengan sendirinya kalau skin tidak punya decor_textures, jadi skin
## Klasik dan Senja tidak berubah sama sekali.

## Jumlah hiasan yang disebar. Ditahan kecil dengan sengaja: ini latar, bukan
## pemandangan yang harus diperhatikan.
const DECOR_COUNT := 7

## Susunan hiasan diundi dengan seed tetap supaya tidak berubah setiap kali skin
## dipratinjau di menu. Tata letak yang melompat-lompat saat pemain menekan tombol
## skin bolak-balik terlihat seperti bug, bukan seperti variasi.
const LAYOUT_SEED := 20240518

## Bagian bawah layar yang boleh ditempati, sebagai rasio tinggi layar.
const BAND_TOP := 0.80
const BAND_BOTTOM := 0.99

const MIN_SCALE := 0.5
const MAX_SCALE := 0.85

## Hiasan digambar agak tipis supaya tidak bersaing dengan pemain dan mob.
const DECOR_ALPHA := 0.8

## Goyangan pelan terbawa arus: sudut (radian) dan lama setengah putaran (detik).
const SWAY_MIN_ANGLE := 0.04
const SWAY_MAX_ANGLE := 0.10
const SWAY_MIN_TIME := 2.2
const SWAY_MAX_TIME := 3.6

var _textures: Array[Texture2D] = []
var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	# Ditata ulang setiap layar berubah ukuran, mengikuti pola yang sama dengan
	# AmbientParticles: hiasan harus tetap menempel di tepi bawah yang baru, bukan
	# menggantung di tengah layar setelah HP diputar.
	get_viewport().size_changed.connect(_rebuild)


## Mengambil daftar hiasan dari skin yang dipilih pemain.
func apply_skin(skin: SkinData) -> void:
	_textures.clear()
	for texture in skin.decor_textures:
		if texture != null:
			_textures.append(texture)

	_rebuild()


func _rebuild() -> void:
	for sprite in _sprites:
		# Dikeluarkan dari scene sebelum queue_free() supaya tidak ada satu frame
		# pun yang menggambar hiasan lama dan hiasan baru sekaligus.
		remove_child(sprite)
		sprite.queue_free()
	_sprites.clear()

	if _textures.is_empty():
		return

	var rect := get_viewport().get_visible_rect()

	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED

	for i in DECOR_COUNT:
		var texture: Texture2D = _textures[i % _textures.size()]
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * rng.randf_range(MIN_SCALE, MAX_SCALE)
		sprite.modulate = Color(1, 1, 1, DECOR_ALPHA)
		sprite.flip_h = rng.randf() < 0.5

		# Titik jangkar digeser ke kaki sprite, bukan ke tengahnya. Dengan begitu
		# hiasan "duduk" di dasar layar, dan goyangannya berputar dari pangkal
		# seperti tanaman yang terbawa arus.
		sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)

		# Satu hiasan per kolom, lalu digeser sedikit secara acak: pembagian kolom
		# mencegah semuanya menggerombol di satu sisi, geseran acak mencegahnya
		# terlihat seperti barisan.
		var column := (float(i) + 0.5) / float(DECOR_COUNT) + rng.randf_range(-0.045, 0.045)
		sprite.position = Vector2(
			rect.position.x + rect.size.x * clampf(column, 0.04, 0.96),
			rect.position.y + rect.size.y * rng.randf_range(BAND_TOP, BAND_BOTTOM)
		)

		add_child(sprite)
		_sprites.append(sprite)
		_start_sway(sprite, rng)


## Setiap hiasan bergoyang dengan sudut dan tempo sendiri, supaya dasar laut tidak
## terlihat seperti gambar mati yang ditempel.
##
## Memakai rotation, bukan position: menggeser posisi membuat hiasan tampak
## berpindah tempat, sedangkan rotasi dari pangkalnya terbaca sebagai arus.
func _start_sway(sprite: Sprite2D, rng: RandomNumberGenerator) -> void:
	var angle := rng.randf_range(SWAY_MIN_ANGLE, SWAY_MAX_ANGLE)
	var duration := rng.randf_range(SWAY_MIN_TIME, SWAY_MAX_TIME)

	sprite.rotation = -angle

	var tween := sprite.create_tween().set_loops()
	tween.tween_property(sprite, "rotation", angle, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "rotation", -angle, duration).set_trans(Tween.TRANS_SINE)
