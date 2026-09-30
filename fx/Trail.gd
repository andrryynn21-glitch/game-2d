extends Line2D

## Jejak cahaya di belakang pemain. Sangat murah (satu Line2D, tanpa partikel)
## tapi memberi kesan gerakan yang mahal.
##
## Titik disimpan dalam koordinat global lalu dikonversi ke lokal setiap frame,
## sehingga jejak tertinggal di dunia alih-alih ikut menempel pada pemain.

## Jumlah titik maksimum. Semakin banyak, semakin panjang jejaknya.
const MAX_POINTS := 20

## Jarak minimum antar titik. Tanpa ini, pemain yang berdiri diam akan menumpuk
## titik di satu tempat dan jejaknya terlihat seperti gumpalan.
const MIN_DISTANCE := 7.0

## Kecepatan jejak menyusut ketika pemain berhenti (titik per detik).
const DECAY_RATE := 34.0

var _target: Node2D
var _points: Array[Vector2] = []
var _decay_accumulator := 0.0


func _ready() -> void:
	# Jejak digambar di dunia, bukan relatif ke pemain.
	top_level = true
	width = 26.0
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	material = Fx.additive_material()
	z_index = -2

	# Menyempit dari ekor ke kepala: kurva 0..1 dibaca dari titik pertama
	# (ekor, paling tua) ke titik terakhir (kepala, paling baru).
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(0.65, 0.45))
	taper.add_point(Vector2(1.0, 1.0))
	width_curve = taper

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.25),
		Color(1, 1, 1, 0.55),
	])
	gradient = fade


## Menentukan node yang diikuti (biasanya pemain).
func setup(target: Node2D) -> void:
	_target = target
	clear_trail()


## Mengubah warna jejak mengikuti aksen skin.
func set_accent_color(color: Color) -> void:
	default_color = Color(color.r, color.g, color.b, 1.0)


## Menghapus seluruh jejak. Dipakai saat respawn dan saat permainan dimulai,
## supaya tidak ada garis melompat dari posisi lama ke posisi baru.
func clear_trail() -> void:
	_points.clear()
	_decay_accumulator = 0.0
	clear_points()


func _process(delta: float) -> void:
	if _target == null or not _target.is_inside_tree() or not _target.visible:
		if _points.size() > 0:
			clear_trail()
		return

	var head := _target.global_position
	if _points.is_empty() or _points[-1].distance_to(head) >= MIN_DISTANCE:
		_points.append(head)
		while _points.size() > MAX_POINTS:
			_points.remove_at(0)
	else:
		# Pemain (hampir) berhenti: susutkan jejak perlahan supaya tidak ada
		# garis yang menggantung diam di belakangnya.
		_decay_accumulator += DECAY_RATE * delta
		while _decay_accumulator >= 1.0 and _points.size() > 0:
			_points.remove_at(0)
			_decay_accumulator -= 1.0

	# top_level membuat transform node ini lepas dari induknya, tapi node ini
	# sendiri masih punya posisi global; konversi supaya titik berada tepat di
	# jalur yang dilalui pemain.
	var local: PackedVector2Array = PackedVector2Array()
	for point in _points:
		local.append(to_local(point))
	points = local
