class_name Fx
extends RefCounted

## Kumpulan pembantu efek visual yang dipakai bersama oleh pemain, mob, dan Main.
##
## Semuanya sengaja dibuat "renderer-agnostic": target game ini adalah export Web
## (renderer Compatibility / WebGL2), jadi kita tidak bergantung pada glow
## post-processing maupun GPUParticles2D. Cahaya dipalsukan dengan sprite
## ber-blend additive, dan partikel memakai CPUParticles2D yang ada di semua
## renderer. Hasilnya juga bebas resolusi sehingga tetap tajam di layar HP.

## Tekstur radial putih di-cache per ukuran: mob lahir terus-menerus, jadi
## membuat gradien baru setiap kali akan memboroskan waktu dan memori.
static var _radial_cache: Dictionary = {}


## Tekstur lingkaran putih yang memudar ke tepi. Warnai lewat "modulate" pada
## node yang memakainya, jangan buat tekstur baru per warna.
static func radial_texture(size: int = 128) -> GradientTexture2D:
	if _radial_cache.has(size):
		return _radial_cache[size]

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.35),
		Color(1, 1, 1, 0),
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size
	texture.height = size

	_radial_cache[size] = texture
	return texture


## Material additive bersama. Aman dibagi antar node karena tidak punya
## parameter per-instance.
static func additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## Halo cahaya palsu untuk dipasang sebagai anak sebuah Node2D. Letakkan sebagai
## anak pertama supaya tergambar di belakang sprite pemiliknya.
static func make_glow(radius: float, color: Color, strength: float = 0.75) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = radial_texture(128)
	glow.material = additive_material()
	glow.modulate = Color(color.r, color.g, color.b, strength)
	# Tekstur selalu 128 px; skala node yang menentukan radius sebenarnya.
	glow.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	glow.z_index = -1
	return glow


## Ledakan partikel sekali-pakai di titik tumbukan. Node membersihkan dirinya
## sendiri setelah partikel terakhir habis, jadi pemanggil tidak perlu mengurus
## siklus hidupnya.
static func spawn_burst(parent: Node, position: Vector2, color: Color, amount: int = 24) -> void:
	if parent == null or not parent.is_inside_tree():
		return

	var particles := CPUParticles2D.new()
	particles.position = position
	particles.texture = radial_texture(64)
	particles.material = additive_material()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.55
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 320.0
	particles.damping_min = 120.0
	particles.damping_max = 260.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.34
	particles.color = color

	# Mengecil dan memudar seiring umurnya.
	#
	# Perhatikan tipenya: CPUParticles2D menerima Curve dan Gradient secara
	# langsung, bukan CurveTexture / GradientTexture1D seperti
	# ParticleProcessMaterial milik GPUParticles2D. Memberi versi tekstur di sini
	# hanya akan ditolak dan efeknya hilang tanpa suara.
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.7),
		Color(1, 1, 1, 0),
	])
	particles.color_ramp = ramp

	parent.add_child(particles)

	# Beri jeda sedikit lebih panjang dari lifetime supaya partikel terakhir
	# selesai digambar sebelum node dibuang.
	var timer := parent.get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(particles.queue_free)
