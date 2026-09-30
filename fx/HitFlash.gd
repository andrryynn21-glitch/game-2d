extends ColorRect

## Kilat layar penuh saat terjadi benturan. Memakai blend additive, jadi layar
## terasa "disorot" sesaat alih-alih tertutup cat putih - lebih enak dilihat dan
## warnanya bisa mengikuti aksen skin.

## Naik cepat, turun perlahan: itu yang membuat kilat terasa seperti pukulan.
const FLASH_IN := 0.045
const FLASH_OUT := 0.34

var _tween: Tween


func _ready() -> void:
	color = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = Fx.additive_material()


## Memancarkan kilat. "strength" adalah alpha puncaknya (0..1).
func flash(tint: Color = Color.WHITE, strength: float = 0.45) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	color = Color(tint.r, tint.g, tint.b, 0.0)

	_tween = create_tween()
	_tween.tween_property(self, "color:a", clampf(strength, 0.0, 1.0), FLASH_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "color:a", 0.0, FLASH_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Mematikan kilat seketika, misalnya saat kembali ke menu.
func reset() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	color = Color(color.r, color.g, color.b, 0.0)
