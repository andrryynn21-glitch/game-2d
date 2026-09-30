class_name StageData
extends Resource

## Konfigurasi satu stage. Semakin kecil "mob_spawn_interval" dan semakin besar
## kecepatan mob, semakin sulit stage tersebut.

@export var stage_name: String = "Stage 1"

## Jeda antar kemunculan mob dalam detik.
@export var mob_spawn_interval: float = 1.0

## Kecepatan mob paling lambat.
@export var mob_speed_min: float = 100.0

## Kecepatan mob paling cepat.
@export var mob_speed_max: float = 180.0

## Waktu persiapan sebelum mob mulai muncul, dalam detik.
@export var start_delay: float = 3.0


## Daftar preset stage bawaan game.
## Stage 1 adalah yang paling mudah, Stage 5 yang paling sulit.
static func create_presets() -> Array[StageData]:
	return [
		_create("Stage 1", 1.00, 100.0, 180.0, 3.0),
		_create("Stage 2", 0.85, 120.0, 210.0, 2.5),
		_create("Stage 3", 0.70, 150.0, 250.0, 2.0),
		_create("Stage 4", 0.55, 180.0, 290.0, 1.5),
		_create("Stage 5", 0.40, 210.0, 330.0, 1.0),
	]


static func _create(p_name: String, p_spawn_interval: float, p_speed_min: float, p_speed_max: float, p_start_delay: float) -> StageData:
	var stage := StageData.new()
	stage.stage_name = p_name
	stage.mob_spawn_interval = p_spawn_interval
	stage.mob_speed_min = p_speed_min
	stage.mob_speed_max = p_speed_max
	stage.start_delay = p_start_delay
	return stage
