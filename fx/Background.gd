extends ColorRect

## Latar bergradien beranimasi. Warnanya diambil dari skin yang dipilih pemain,
## dan perpindahan antar skin di-tween supaya pratinjau di menu terasa halus,
## bukan berkedip ganti warna.

const SHADER_PATH := "res://fx/background.gdshader"

## Lama perpindahan warna saat pemain mengganti skin, dalam detik.
const BLEND_TIME := 0.45

var _material := ShaderMaterial.new()
var _blend_tween: Tween


func _ready() -> void:
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		push_warning("Shader latar tidak ditemukan: %s" % SHADER_PATH)
		return

	_material.shader = shader
	material = _material

	# ColorRect tetap butuh warna dasar buram supaya tidak ada yang bocor di
	# frame pertama sebelum shader ter-compile.
	color = Color.BLACK


## Menerapkan warna dari sebuah skin. "instant" dipakai saat permainan baru
## dimulai, ketika tidak ada yang perlu dianimasikan.
func apply_skin(skin: SkinData, instant: bool = false) -> void:
	if _material.shader == null:
		# Shader gagal dimuat: minimal latar tetap memakai warna skin.
		color = skin.background_color
		return

	if _blend_tween and _blend_tween.is_valid():
		_blend_tween.kill()

	if instant:
		_set_colors(skin.gradient_top, skin.gradient_bottom, skin.accent_color)
		_material.set_shader_parameter("wave_speed", skin.background_wave_speed)
		return

	var from_top: Color = _get_color("top_color", skin.gradient_top)
	var from_bottom: Color = _get_color("bottom_color", skin.gradient_bottom)
	var from_glow: Color = _get_color("glow_color", skin.accent_color)

	_material.set_shader_parameter("wave_speed", skin.background_wave_speed)

	_blend_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_blend_tween.tween_method(
		_apply_shader_color.bind("top_color"), from_top, skin.gradient_top, BLEND_TIME
	)
	_blend_tween.tween_method(
		_apply_shader_color.bind("bottom_color"), from_bottom, skin.gradient_bottom, BLEND_TIME
	)
	_blend_tween.tween_method(
		_apply_shader_color.bind("glow_color"), from_glow, skin.accent_color, BLEND_TIME
	)


## Penerima nilai tween untuk satu uniform warna.
##
## Urutan argumennya sengaja "nilai dulu, nama uniform belakangan": Callable.bind()
## menambahkan argumen terikat di akhir, sedangkan tween_method mengirim nilai
## interpolasinya sebagai argumen pertama.
func _apply_shader_color(value: Color, parameter: String) -> void:
	_material.set_shader_parameter(parameter, value)


func _set_colors(top: Color, bottom: Color, glow: Color) -> void:
	_material.set_shader_parameter("top_color", top)
	_material.set_shader_parameter("bottom_color", bottom)
	_material.set_shader_parameter("glow_color", glow)


## Nilai uniform yang sedang dipakai; sebelum pernah di-set, shader mengembalikan
## null sehingga kita perlu nilai cadangan.
func _get_color(parameter: String, fallback: Color) -> Color:
	var value = _material.get_shader_parameter(parameter)
	return value if value is Color else fallback
