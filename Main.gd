extends Node

@export var mob_scene: PackedScene

## Scene item yang bisa diambil (mutiara, koin, peti, kerang nyawa).
@export var pickup_scene: PackedScene

## Daftar stage yang bisa dipilih pemain. Jika kosong, preset bawaan StageData dipakai.
@export var stages: Array[StageData] = []

## Daftar skin (tampilan pemain, musuh, dan peta). Kosong = preset bawaan.
@export var skins: Array[SkinData] = []

## Jumlah nyawa pemain di awal permainan.
@export var start_lives: int = 3

## Kekuatan guncangan layar (0..1) saat kehilangan nyawa dan saat game over.
const HIT_SHAKE := 0.6
const GAME_OVER_SHAKE := 1.0

## Jarak di luar layar tempat mob dilahirkan. Dengan margin ini mob meluncur
## masuk dari luar pandangan, bukan "menyembul" di tepi layar.
const SPAWN_MARGIN := 48.0

## Posisi awal pemain sebagai rasio tinggi layar. 0.62 menempatkannya sedikit di
## bawah tengah seperti versi aslinya, tapi kini ikut menyesuaikan tinggi layar.
const START_HEIGHT_RATIO := 0.62

## Selang kemunculan item. Sengaja sama di semua stage: kesulitan diatur lewat
## laju dan kecepatan mob, sedangkan item adalah hadiah — kalau ikut dipercepat,
## stage tersulit justru jadi yang paling royal.
const PICKUP_INTERVAL := 4.5

## Jarak item dari tepi area aman, supaya tidak ada item yang lahir setengah
## tersembunyi di balik notch atau bilah browser.
const PICKUP_MARGIN := 40.0

## Jarak minimum item dari pemain saat lahir. Item yang muncul tepat di atas
## pemain jadi hadiah gratis, bukan pilihan — dan pilihan itulah gunanya item.
const PICKUP_PLAYER_CLEARANCE := 120.0

## Berapa kali posisi diundi ulang untuk menjauh dari pemain sebelum menyerah.
## Di layar sempit, jarak aman kadang memang tidak tersedia.
const PICKUP_PLACEMENT_TRIES := 6

## Batas item di layar sekaligus. Tanpa batas ini, stage panjang berubah jadi
## ladang item dan pemain tidak lagi harus memilih mana yang layak dikejar.
const MAX_PICKUPS := 3

## Zoom sesaat saat item diambil. Jauh lebih lembut daripada benturan.
const PICKUP_PUNCH := 0.4

var score := 0
var lives := 0
var current_stage: StageData
var current_skin: SkinData
var is_game_over := false
var is_playing := false

@onready var _background: ColorRect = $BackgroundLayer/Background
@onready var _map_texture: TextureRect = $BackgroundLayer/MapTexture
@onready var _decor: Node2D = $BackgroundLayer/SeafloorDecor
@onready var _particles: Node2D = $AmbientParticles
@onready var _camera: Camera2D = $Camera2D
@onready var _player: Area2D = $Player
@onready var _touch_controls: CanvasLayer = $TouchControls
@onready var _hud: CanvasLayer = $HUD
@onready var _mob_path: Path2D = $MobPath
@onready var _start_position: Marker2D = $StartPosition


func _ready() -> void:
	if stages.is_empty():
		stages = StageData.create_presets()
	if skins.is_empty():
		skins = SkinData.create_presets()

	# Laju mob diatur per stage oleh apply_stage(); laju item tidak, jadi nilainya
	# dipasang sekali di sini supaya konstantanya tetap satu-satunya sumber.
	$PickupTimer.wait_time = PICKUP_INTERVAL

	# Semua yang bergantung ukuran layar dihitung ulang setiap layar berubah:
	# inilah yang membuat game tetap benar saat HP diputar atau bilah browser
	# muncul/hilang.
	_rebuild_layout()
	get_viewport().size_changed.connect(_rebuild_layout)

	_player.set_touch_controls(_touch_controls)

	var stage_names := PackedStringArray()
	for stage in stages:
		stage_names.append(stage.stage_name)
	_hud.setup_stages(stage_names)

	var skin_names := PackedStringArray()
	for skin in skins:
		skin_names.append(skin.skin_name)
	_hud.setup_skins(skin_names)

	_hud.setup_controls()

	apply_skin(skins[0], true)
	_refresh_menu_best()


## Menyesuaikan seluruh geometri permainan dengan ukuran layar sekarang.
func _rebuild_layout() -> void:
	var rect := get_viewport().get_visible_rect()
	_rebuild_mob_path(rect)
	_start_position.position = rect.position + Vector2(
		rect.size.x * 0.5, rect.size.y * START_HEIGHT_RATIO
	)


## Membangun ulang jalur spawn mob mengikuti tepi layar.
##
## Versi aslinya memakai kurva yang dipaku ke 480x720. Dengan mode peregangan
## "expand", layar HP 20:9 terlihat ~480x1040 sehingga mob tidak pernah muncul
## dari sisi di bawah y=720 dan bagian bawah layar jadi zona aman gratis. Ini bug
## kesulitan, bukan sekadar kosmetik, jadi kurvanya dihitung ulang dari viewport.
func _rebuild_mob_path(rect: Rect2) -> void:
	var spawn_rect := rect.grow(SPAWN_MARGIN)
	var curve := Curve2D.new()

	# Urutan searah jarum jam. Mob.gd memakai rotasi jalur + PI/2 sebagai arah,
	# dan dengan urutan ini hasilnya selalu menghadap ke dalam layar.
	curve.add_point(spawn_rect.position)
	curve.add_point(Vector2(spawn_rect.end.x, spawn_rect.position.y))
	curve.add_point(spawn_rect.end)
	curve.add_point(Vector2(spawn_rect.position.x, spawn_rect.end.y))
	curve.add_point(spawn_rect.position)

	_mob_path.curve = curve


func game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	is_playing = false
	$ScoreTimer.stop()
	$MobTimer.stop()
	$PickupTimer.stop()
	$StartTimer.stop()
	_player.hide_player()
	_touch_controls.set_active(false)
	_hud.set_pause_available(false)
	get_tree().call_group("mobs", "dissolve")
	get_tree().call_group("pickups", "dissolve")

	var stage_name: String = current_stage.stage_name
	var is_new_best: bool = GameSettings.submit_score(stage_name, score)
	_hud.show_game_over(score, GameSettings.get_high_score(stage_name), is_new_best)
	_refresh_menu_best()

	$Music.stop()
	$DeathSound.play()


## Dipanggil setiap pemain tertabrak mob: nyawa berkurang satu, dan permainan
## baru berakhir setelah nyawa habis.
func _on_player_hit() -> void:
	if is_game_over or not is_playing:
		return

	lives -= 1
	_hud.update_lives(lives)

	# Umpan balik benturan: kilat, ledakan partikel, guncangan, dan zoom sesaat.
	# Empat lapis kecil ini yang membuat tabrakan terasa, bukan cuma terlihat.
	var accent: Color = current_skin.accent_color
	_hud.flash(accent, 0.5)
	Fx.spawn_burst(self, _player.position, accent, 28)
	_camera.punch()

	if lives <= 0:
		_camera.shake(GAME_OVER_SHAKE)
		game_over()
		return

	_camera.shake(HIT_SHAKE)

	# Kesempatan kedua: mob dilarutkan (bukan dihapus mendadak) dan pemain
	# kembali ke posisi awal dengan masa kebal singkat. Item ikut dibersihkan
	# supaya pemain tidak mendarat tepat di atas item yang tinggal dijemput.
	get_tree().call_group("mobs", "dissolve")
	get_tree().call_group("pickups", "dissolve")
	_player.respawn(_start_position.position)
	_hud.show_message("-1 Nyawa")


func new_game(stage_index: int = 0, skin_index: int = 0) -> void:
	apply_stage(stages[clampi(stage_index, 0, stages.size() - 1)])
	apply_skin(skins[clampi(skin_index, 0, skins.size() - 1)])

	score = 0
	lives = start_lives
	is_game_over = false
	is_playing = true

	get_tree().call_group("mobs", "queue_free")
	get_tree().call_group("pickups", "queue_free")
	_camera.reset()
	_hud.reset_effects()
	_rebuild_layout()

	_player.start(_start_position.position)
	$StartTimer.start()

	_hud.update_score(score)
	_hud.setup_lives(start_lives)
	_hud.update_lives(lives)
	_hud.update_stage(current_stage.stage_name)
	_hud.update_best(GameSettings.get_high_score(current_stage.stage_name))
	_hud.set_pause_available(true)
	_hud.show_message("Get Ready")

	_touch_controls.set_active(true)
	$Music.stream_paused = false
	$Music.play()


## Menerapkan tingkat kesulitan dari stage yang dipilih pemain.
func apply_stage(stage: StageData) -> void:
	current_stage = stage
	$MobTimer.wait_time = stage.mob_spawn_interval
	$StartTimer.wait_time = stage.start_delay


## Menerapkan tampilan dari skin yang dipilih ke seluruh lapisan: latar, partikel,
## peta, pemain, kontrol sentuh, dan HUD.
##
## "instant" dipakai saat pertama kali memuat, ketika tidak ada yang perlu
## dianimasikan.
func apply_skin(skin: SkinData, instant: bool = false) -> void:
	current_skin = skin

	_background.apply_skin(skin, instant)
	_particles.apply_skin(skin)
	_decor.apply_skin(skin)

	_map_texture.texture = skin.map_texture
	_map_texture.visible = skin.map_texture != null

	_player.set_frames(skin.player_frames)
	_player.set_accent_color(skin.accent_color)

	_touch_controls.set_accent_color(skin.accent_color)
	_hud.set_accent_color(skin.accent_color)
	_hud.set_life_icon(skin.life_icon)


## Pratinjau skin langsung di menu (hanya saat permainan belum berjalan).
func _on_skin_selected(skin_index: int) -> void:
	if is_playing:
		return

	apply_skin(skins[clampi(skin_index, 0, skins.size() - 1)])


## Skor terbaik disimpan per stage, jadi labelnya ikut berubah saat pemain
## memindah pilihan stage di menu.
func _on_stage_selected(stage_index: int) -> void:
	_refresh_menu_best(stage_index)


func _refresh_menu_best(stage_index: int = -1) -> void:
	if stage_index < 0:
		stage_index = _hud.selected_stage_index

	var stage: StageData = stages[clampi(stage_index, 0, stages.size() - 1)]
	_hud.update_menu_best(GameSettings.get_high_score(stage.stage_name))


## Jeda: musik ikut berhenti dan kontrol sentuh dimatikan supaya karakter tidak
## terus melaju karena jari yang masih menempel saat permainan dijeda.
func _on_hud_pause_changed(paused: bool) -> void:
	$Music.stream_paused = paused
	_touch_controls.set_active(is_playing and not paused)


## Keluar dari permainan lewat menu jeda.
func _on_hud_quit_requested() -> void:
	is_playing = false
	is_game_over = false

	$ScoreTimer.stop()
	$MobTimer.stop()
	$PickupTimer.stop()
	$StartTimer.stop()
	get_tree().call_group("mobs", "queue_free")
	get_tree().call_group("pickups", "queue_free")

	_player.hide_player()
	_touch_controls.set_active(false)
	_camera.reset()

	$Music.stop()
	$Music.stream_paused = false

	_hud.return_to_menu()
	_refresh_menu_best()


func _on_mob_timer_timeout() -> void:
	# Create a new instance of the Mob scene.
	var mob = mob_scene.instantiate()
	mob.apply_skin(current_skin)

	# Choose a random location on Path2D.
	var mob_spawn_location = $MobPath/MobSpawnLocation
	mob_spawn_location.progress_ratio = randf()

	# Set the mob's direction perpendicular to the path direction.
	var direction = mob_spawn_location.rotation + PI / 2

	# Set the mob's position to the random location.
	mob.position = mob_spawn_location.position

	# Add some randomness to the direction.
	direction += randf_range(-PI / 4, PI / 4)
	mob.rotation = direction

	# Choose the velocity for the mob.
	var velocity = Vector2(randf_range(current_stage.mob_speed_min, current_stage.mob_speed_max), 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Spawn the mob by adding it to the Main scene.
	add_child(mob)


func _on_score_timer_timeout() -> void:
	score += 1
	_hud.update_score(score)


# ---------------------------------------------------------------------------
# Item
# ---------------------------------------------------------------------------

func _on_pickup_timer_timeout() -> void:
	if pickup_scene == null or not is_playing or is_game_over:
		return

	if get_tree().get_nodes_in_group("pickups").size() >= MAX_PICKUPS:
		return

	var pickup := pickup_scene.instantiate()
	pickup.configure(_pick_pickup_kind())
	pickup.collected.connect(_on_pickup_collected)
	pickup.position = _pickup_spawn_position()

	add_child(pickup)


## Mengundi jenis item.
##
## Mutiara dan koin sering muncul, peti jarang. Kerang nyawa hanya ditawarkan
## ketika pemain memang sedang kekurangan nyawa: kalau selalu tersedia, item
## paling berharga di game ini jadi tidak berarti apa-apa.
func _pick_pickup_kind() -> Pickup.Kind:
	var choices := [Pickup.Kind.PEARL, Pickup.Kind.COIN, Pickup.Kind.CHEST]
	var weights := [46, 34, 12]

	if lives < start_lives:
		choices.append(Pickup.Kind.LIFE)
		weights.append(10)

	var total := 0
	for weight in weights:
		total += weight

	var roll := randi() % total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0:
			return choices[i]

	return choices[0]


## Titik kemunculan item: acak di dalam area aman, tapi tidak terlalu dekat pemain.
##
## Berbeda dengan mob yang lahir di luar layar, item lahir di dalam layar. Itu
## disengaja: item harus jadi keputusan ("apakah skor ini sepadan dengan jalan
## masuk ke sana?"), bukan sesuatu yang lewat sendiri di depan pemain.
func _pickup_spawn_position() -> Vector2:
	var rect := SafeArea.get_play_rect(get_viewport(), PICKUP_MARGIN)
	var spot := rect.get_center()

	for _i in PICKUP_PLACEMENT_TRIES:
		spot = Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		if spot.distance_to(_player.position) >= PICKUP_PLAYER_CLEARANCE:
			break

	return spot


## Item diambil: skor atau nyawa bertambah, lalu tiga lapis umpan balik kecil
## (kilau partikel di tempat, popup nilai di HUD, zoom lembut) supaya hadiahnya
## terasa, bukan hanya terbaca di angka skor.
func _on_pickup_collected(kind: Pickup.Kind, value: int, at: Vector2) -> void:
	if is_game_over:
		return

	var color := Pickup.color_for(kind)

	if kind == Pickup.Kind.LIFE:
		# Nyawa tidak boleh melewati jumlah awal: HUD hanya menyiapkan hati
		# sebanyak start_lives, jadi nyawa keempat tidak punya tempat untuk
		# terlihat dan pemain akan kehilangan nyawa yang tak pernah dia lihat.
		lives = mini(lives + value, start_lives)
		_hud.update_lives(lives)
	else:
		score += value
		_hud.update_score(score)

	Fx.spawn_burst(self, at, color, 20)
	_hud.show_pickup(Pickup.texture_for(kind), Pickup.label_for(kind), color)
	_camera.punch(PICKUP_PUNCH)


func _on_start_timer_timeout() -> void:
	$MobTimer.start()
	$ScoreTimer.start()
	$PickupTimer.start()
