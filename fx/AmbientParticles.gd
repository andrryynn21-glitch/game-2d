extends Node2D

## Tiga lapis partikel latar yang bergerak dengan kecepatan berbeda sehingga
## tercipta kesan kedalaman (parallax). Semuanya CPUParticles2D, bukan
## GPUParticles2D, supaya pasti jalan di renderer Compatibility untuk export Web.
##
## Jumlah partikel dipatok konservatif sejak awal: di GPU ponsel, biaya partikel
## 2D hampir seluruhnya biaya fill-rate, jadi lebih baik sedikit partikel besar
## yang transparan tipis daripada banyak partikel yang saling menumpuk.

## Pengali jumlah, kecepatan, ukuran, dan kecerahan untuk lapis jauh, tengah,
## dan dekat. Indeks 0 = paling jauh.
const LAYER_AMOUNT := [34, 26, 16]
const LAYER_SPEED := [0.35, 0.65, 1.0]
const LAYER_SCALE := [0.45, 0.75, 1.15]
const LAYER_ALPHA := [0.20, 0.34, 0.5]

## Margin di luar layar tempat partikel boleh lahir, supaya tidak terlihat
## "muncul dari udara" di tepi.
const SPAWN_MARGIN := 80.0

var _layers: Array[CPUParticles2D] = []


func _ready() -> void:
	for i in LAYER_AMOUNT.size():
		var particles := CPUParticles2D.new()
		particles.texture = Fx.radial_texture(64)
		particles.material = Fx.additive_material()
		particles.local_coords = false
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.amount = LAYER_AMOUNT[i]
		particles.randomness = 0.8
		particles.gravity = Vector2.ZERO
		add_child(particles)
		_layers.append(particles)

	_resize()
	get_viewport().size_changed.connect(_resize)


## Menempatkan emitter di tengah viewport dan melebarkannya seluas layar.
## Dipanggil ulang setiap layar berubah ukuran / berotasi.
func _resize() -> void:
	var rect := get_viewport().get_visible_rect()
	position = rect.position + rect.size * 0.5

	var extents := rect.size * 0.5 + Vector2.ONE * SPAWN_MARGIN
	for particles in _layers:
		particles.emission_rect_extents = extents


## Menerapkan gaya partikel dari skin: tekstur, warna, jenis gerakan, dan kecepatan.
func apply_skin(skin: SkinData) -> void:
	# Skin laut memakai gambar gelembung; skin lain tetap memakai titik cahaya
	# radial yang dibuat di runtime.
	var texture: Texture2D = skin.particle_texture
	if texture == null:
		texture = Fx.radial_texture(64)

	for i in _layers.size():
		var particles := _layers[i]
		particles.texture = texture
		particles.color = Color(
			skin.particle_color.r,
			skin.particle_color.g,
			skin.particle_color.b,
			LAYER_ALPHA[i] * skin.particle_color.a
		)
		_apply_kind(particles, skin.particle_kind, i)

		# Isi layar sejak frame pertama, kalau tidak pemain akan melihat layar
		# kosong yang perlahan terisi selama beberapa detik pertama.
		particles.preprocess = particles.lifetime
		particles.restart()


func _apply_kind(particles: CPUParticles2D, kind: SkinData.ParticleKind, layer: int) -> void:
	var speed: float = LAYER_SPEED[layer]
	var size: float = LAYER_SCALE[layer]

	match kind:
		SkinData.ParticleKind.BUBBLE:
			# Gelembung: naik mantap, sedikit bergoyang ke samping.
			particles.direction = Vector2.UP
			particles.spread = 18.0
			particles.lifetime = 7.0 / maxf(speed, 0.1)
			particles.initial_velocity_min = 22.0 * speed
			particles.initial_velocity_max = 55.0 * speed
			particles.tangential_accel_min = -14.0
			particles.tangential_accel_max = 14.0
			particles.damping_min = 0.0
			particles.damping_max = 0.0
			particles.scale_amount_min = 0.10 * size
			particles.scale_amount_max = 0.30 * size

		SkinData.ParticleKind.EMBER:
			# Bara: naik lebih cepat, menyebar lebar, mengecil saat naik.
			particles.direction = Vector2.UP
			particles.spread = 42.0
			particles.lifetime = 5.0 / maxf(speed, 0.1)
			particles.initial_velocity_min = 30.0 * speed
			particles.initial_velocity_max = 85.0 * speed
			particles.tangential_accel_min = -30.0
			particles.tangential_accel_max = 30.0
			particles.damping_min = 4.0
			particles.damping_max = 12.0
			particles.scale_amount_min = 0.06 * size
			particles.scale_amount_max = 0.20 * size

		_:
			# Debu: melayang pelan ke segala arah.
			particles.direction = Vector2.UP
			particles.spread = 180.0
			particles.lifetime = 9.0 / maxf(speed, 0.1)
			particles.initial_velocity_min = 8.0 * speed
			particles.initial_velocity_max = 26.0 * speed
			particles.tangential_accel_min = -6.0
			particles.tangential_accel_max = 6.0
			particles.damping_min = 0.0
			particles.damping_max = 2.0
			particles.scale_amount_min = 0.08 * size
			particles.scale_amount_max = 0.22 * size
