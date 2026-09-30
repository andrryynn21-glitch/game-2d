extends Node

## Penyimpanan pengaturan & rekor pemain yang bertahan antar sesi.
## Terdaftar sebagai autoload bernama "GameSettings" (lihat project.godot).
## Di export Web, "user://" dipetakan ke IndexedDB oleh Godot, jadi berkas ini
## tetap tersimpan setelah halaman di-reload.

const SETTINGS_PATH := "user://settings.cfg"

## Skema kontrol sentuh yang tersedia. Urutannya dipakai sebagai index tombol
## pilihan di menu, jadi jangan disusun ulang tanpa alasan.
enum ControlScheme {
	DRAG,     ## Geser di mana saja: karakter mengikuti pergerakan jari.
	JOYSTICK, ## Stik analog mengambang di tempat jempol menyentuh.
}

## Nama skema kontrol untuk ditampilkan di menu.
const CONTROL_SCHEME_NAMES := ["Geser", "Joystick"]

## Skema kontrol yang sedang dipakai.
var control_scheme: ControlScheme = ControlScheme.DRAG

## Skor terbaik per nama stage: { "Stage 1": 42, ... }
var high_scores: Dictionary = {}


func _ready() -> void:
	# Autoload harus tetap hidup saat permainan di-pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


## Memuat pengaturan dari disk. Berkas yang belum ada bukan error: pemain baru
## cukup memakai nilai bawaan.
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	var scheme := int(config.get_value("controls", "scheme", ControlScheme.DRAG))
	control_scheme = clampi(scheme, 0, ControlScheme.size() - 1) as ControlScheme

	var scores = config.get_value("scores", "high_scores", {})
	if scores is Dictionary:
		high_scores = scores


## Menyimpan pengaturan ke disk.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "scheme", int(control_scheme))
	config.set_value("scores", "high_scores", high_scores)

	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Gagal menyimpan pengaturan (kode %d)" % error)


## Mengganti skema kontrol dan langsung menyimpannya.
func set_control_scheme(scheme: ControlScheme) -> void:
	if control_scheme == scheme:
		return

	control_scheme = scheme
	save_settings()


## Skor terbaik untuk sebuah stage (0 jika belum pernah dimainkan).
func get_high_score(stage_name: String) -> int:
	return int(high_scores.get(stage_name, 0))


## Mencatat skor akhir. Mengembalikan true hanya jika rekor baru terpecahkan,
## supaya HUD bisa memberi selamat.
func submit_score(stage_name: String, score: int) -> bool:
	if score <= get_high_score(stage_name):
		return false

	high_scores[stage_name] = score
	save_settings()
	return true
