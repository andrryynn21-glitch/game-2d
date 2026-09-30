extends Camera2D

## Getaran layar saat pemain tertabrak. Memakai model "trauma": setiap kejadian
## menambah trauma, lalu trauma menyusut sendiri. Peredaman kuadratik membuat
## getaran terasa memukul di awal dan mereda dengan lembut, jauh lebih enak
## daripada amplitudo yang turun linear.
##
## Kamera ini juga yang memusatkan tampilan ke viewport. Latar dan peta sengaja
## ditempatkan di CanvasLayer terpisah sehingga tidak ikut bergetar - kalau ikut,
## tepi latar akan tersingkap saat layar berguncang.

## Seberapa cepat trauma menyusut per detik.
const DECAY := 4.2

## Simpangan maksimum saat trauma penuh, dalam satuan kanvas.
const MAX_OFFSET := Vector2(26.0, 20.0)

## Kemiringan maksimum saat trauma penuh, dalam radian (~1.7 derajat).
const MAX_ROLL := 0.03

## Zoom sesaat saat terjadi benturan.
const PUNCH_ZOOM := 1.05
const PUNCH_IN_TIME := 0.06
const PUNCH_OUT_TIME := 0.32

var _trauma := 0.0
var _punch_tween: Tween


func _ready() -> void:
	make_current()
	# Camera2D mengabaikan rotasinya sendiri secara bawaan; matikan supaya
	# kemiringan saat berguncang benar-benar terlihat.
	ignore_rotation = false
	_recenter()
	get_viewport().size_changed.connect(_recenter)


## Menempatkan kamera tepat di tengah viewport. Pemain dibatasi dengan koordinat
## dunia 0..ukuran layar, jadi pemusatan ini yang membuat batas itu cocok dengan
## apa yang benar-benar terlihat.
func _recenter() -> void:
	var rect := get_viewport().get_visible_rect()
	position = rect.position + rect.size * 0.5


## Menambah guncangan. "amount" 0..1; nilai di atas 1 tidak menambah apa-apa.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Zoom masuk sesaat lalu kembali. Dipakai bersama shake() saat benturan.
##
## "strength" (0..1) mengecilkan zoom-nya. Benturan memakai nilai penuh; kejadian
## kecil seperti mengambil item memakai nilai kecil — kalau tidak, hadiah terasa
## sekeras hukuman.
func punch(strength: float = 1.0) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	var target := 1.0 + (PUNCH_ZOOM - 1.0) * clampf(strength, 0.0, 1.0)

	_punch_tween = create_tween()
	_punch_tween.tween_property(self, "zoom", Vector2.ONE * target, PUNCH_IN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "zoom", Vector2.ONE, PUNCH_OUT_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Menghentikan semua guncangan seketika, misalnya saat kembali ke menu.
func reset() -> void:
	_trauma = 0.0
	offset = Vector2.ZERO
	rotation = 0.0
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	zoom = Vector2.ONE


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO or rotation != 0.0:
			offset = Vector2.ZERO
			rotation = 0.0
		return

	_trauma = maxf(_trauma - DECAY * delta, 0.0)

	# Kuadrat dari trauma: pukulan awal tegas, ekornya halus.
	var strength := _trauma * _trauma
	offset = Vector2(
		randf_range(-1.0, 1.0) * MAX_OFFSET.x,
		randf_range(-1.0, 1.0) * MAX_OFFSET.y
	) * strength
	rotation = randf_range(-1.0, 1.0) * MAX_ROLL * strength
