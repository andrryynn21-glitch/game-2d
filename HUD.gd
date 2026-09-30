extends CanvasLayer

## Seluruh antarmuka: panel skor, hati nyawa, pesan, menu, dan jeda.
##
## Semua gaya visual (panel membulat, tombol beraksen) dibangun di kode lewat
## StyleBoxFlat, mengikuti gaya code-driven yang sudah dipakai _build_buttons().
## Keuntungannya: warna aksen bisa ikut berganti setiap pemain memilih skin lain,
## sesuatu yang tidak bisa dilakukan file .tres statis.

signal start_game(stage_index: int, skin_index: int)

## Dikirim saat pemain memindah pilihan stage, supaya skor terbaik stage itu bisa
## ditampilkan di menu.
signal stage_selected(stage_index: int)

## Dikirim saat pemain memilih skin di menu supaya tampilannya bisa dipratinjau.
signal skin_selected(skin_index: int)

## Dikirim setiap permainan dijeda atau dilanjutkan.
signal pause_changed(paused: bool)

## Dikirim saat pemain menekan "Menu Utama" di layar jeda.
signal quit_requested

## Tombol dibuat besar dengan sengaja: 72 px kira-kira 9 mm di layar HP, di atas
## ambang nyaman-sentuh, dan tetap cukup kecil untuk layar 480 px.
const STAGE_BUTTON_MIN_SIZE := Vector2(72, 72)
const WIDE_BUTTON_MIN_SIZE := Vector2(0, 58)

const STAGE_BUTTON_FONT_SIZE := 30
const SKIN_BUTTON_FONT_SIZE := 20
const CONTROL_BUTTON_FONT_SIZE := 22

const PANEL_RADIUS := 16
const CARD_RADIUS := 26
const BUTTON_RADIUS := 16

## Panel HUD gelap dan tembus pandang supaya angka tetap terbaca di atas latar
## apa pun tanpa menutup-tutupi permainan.
const PANEL_BG := Color(0.04, 0.05, 0.08, 0.5)
const CARD_BG := Color(0.03, 0.04, 0.07, 0.86)

const HEART_TEXTURE_PATH := "res://art/ui/heart.svg"
const HEART_SIZE := Vector2(34, 34)

## Hati yang hilang diredupkan, bukan dihapus: tata letak tidak melompat dan
## pemain tetap melihat berapa nyawa yang pernah dia punya.
const HEART_DIM := Color(1, 1, 1, 0.16)

## Popup item yang baru diambil: ukuran ikon, besar tulisan, jarak naik, dan lama
## hidupnya.
const PICKUP_ICON_SIZE := Vector2(30, 30)
const PICKUP_FONT_SIZE := 30
const PICKUP_POPUP_HEIGHT := 40.0
const PICKUP_POPUP_RISE := 34.0
const PICKUP_POPUP_TIME := 0.8
const PICKUP_POPUP_FADE := 0.3

const FADE_TIME := 0.28
const POP_TIME := 0.28

## Lama "Game Over" bertahan di layar sebelum menu muncul kembali.
const GAME_OVER_HOLD := 1.6

## Kegelapan lapisan peredup di menu dan di layar jeda / game over.
const MENU_DIM := 0.42
const OVERLAY_DIM := 0.62

## Umpan balik tekan tombol.
const PRESS_SCALE := 0.93
const PRESS_TIME := 0.07

## Tinggi area HUD atas, dihitung dari batas aman layar.
const TOP_BAR_HEIGHT := 250.0

## Index stage yang sedang dipilih di menu (0 = stage paling mudah).
var selected_stage_index := 0

## Index skin yang sedang dipilih di menu (0 = skin bawaan).
var selected_skin_index := 0

## Index skema kontrol sentuh yang sedang dipilih.
var selected_control_index := 0

var _stage_buttons: Array[Button] = []
var _skin_buttons: Array[Button] = []
var _control_buttons: Array[Button] = []
var _stage_button_group := ButtonGroup.new()
var _skin_button_group := ButtonGroup.new()
var _control_button_group := ButtonGroup.new()

var _hearts: Array[TextureRect] = []
var _heart_texture: Texture2D

## Ikon nyawa bawaan, dipakai kembali setiap skin tidak membawa ikonnya sendiri.
var _default_heart_texture: Texture2D

## Popup item yang sedang tampil. Hanya satu yang dibiarkan hidup: dua popup di
## posisi yang sama akan saling menumpuk dan tidak terbaca.
var _pickup_popup: Control

## Nyawa yang terakhir ditampilkan, dipakai untuk mengetahui hati mana yang baru
## saja padam sehingga hanya hati itu yang beranimasi.
var _shown_lives := -1

var _accent := Color("#8ef0cf")

var _paused := false
var _pause_available := false

var _transition_tween: Tween
var _message_tween: Tween
var _press_tweens: Dictionary = {}

@onready var _flash_rect: ColorRect = $FlashRect
@onready var _dim_rect: ColorRect = $DimRect
@onready var _top_bar: VBoxContainer = $TopBar
@onready var _stage_panel: PanelContainer = $TopBar/TopRow/StagePanel
@onready var _stage_label: Label = $TopBar/TopRow/StagePanel/StageLabel
@onready var _pause_button: Button = $TopBar/TopRow/PauseButton
@onready var _score_label: Label = $TopBar/ScoreLabel
@onready var _best_label: Label = $TopBar/BestLabel
@onready var _lives_box: HBoxContainer = $TopBar/LivesBox
@onready var _message_label: Label = $MessageLabel
@onready var _menu_center: CenterContainer = $MenuCenter
@onready var _menu_card: PanelContainer = $MenuCenter/MenuCard
@onready var _title_label: Label = $MenuCenter/MenuCard/Menu/TitleLabel
@onready var _menu_best_label: Label = $MenuCenter/MenuCard/Menu/MenuBestLabel
@onready var _stage_select_label: Label = $MenuCenter/MenuCard/Menu/StageSelectLabel
@onready var _skin_select_label: Label = $MenuCenter/MenuCard/Menu/SkinSelectLabel
@onready var _control_select_label: Label = $MenuCenter/MenuCard/Menu/ControlSelectLabel
@onready var _stage_container: HBoxContainer = $MenuCenter/MenuCard/Menu/StageButtons
# Ditulis sebagai Container, bukan HBoxContainer: tombol skin kini disusun dalam
# GridContainer 2 kolom supaya empat skin tetap masuk lebar kartu menu.
@onready var _skin_container: Container = $MenuCenter/MenuCard/Menu/SkinButtons
@onready var _control_container: HBoxContainer = $MenuCenter/MenuCard/Menu/ControlButtons
@onready var _start_button: Button = $MenuCenter/MenuCard/Menu/StartButton
@onready var _pause_center: CenterContainer = $PauseCenter
@onready var _pause_card: PanelContainer = $PauseCenter/PauseCard
@onready var _pause_title: Label = $PauseCenter/PauseCard/PauseBox/PauseTitle
@onready var _resume_button: Button = $PauseCenter/PauseCard/PauseBox/ResumeButton
@onready var _quit_button: Button = $PauseCenter/PauseCard/PauseBox/QuitButton
@onready var _message_timer: Timer = $MessageTimer


func _ready() -> void:
	# HUD harus tetap hidup saat get_tree().paused, kalau tidak tombol "Lanjut"
	# ikut terjeda dan permainan tidak bisa dilanjutkan lagi.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_heart_texture = load(HEART_TEXTURE_PATH)
	if _heart_texture == null:
		# Kalau ikon gagal dimuat, lebih baik titik cahaya daripada tidak ada apa-apa.
		_heart_texture = Fx.radial_texture(64)
	_default_heart_texture = _heart_texture

	_apply_styles()

	for button in [_pause_button, _start_button, _resume_button, _quit_button]:
		_add_press_feedback(button)

	# Semua yang dianimasikan dengan scale harus berputar dari pusatnya sendiri,
	# dan ukurannya baru diketahui setelah tata letak dihitung.
	for control in [_title_label, _menu_card, _pause_card, _message_label, _score_label]:
		_keep_pivot_centered(control)

	_start_title_breath()

	_refresh_safe_area()
	get_viewport().size_changed.connect(_refresh_safe_area)

	show_menu()


## Margin aman (notch, sudut membulat, bilah browser) diterapkan ke offset HUD.
## Tanpa ini, skor di HP ber-notch bisa tertutup separuh.
func _refresh_safe_area() -> void:
	var insets := SafeArea.get_insets(get_viewport())

	_top_bar.offset_left = insets.x
	_top_bar.offset_top = insets.y
	_top_bar.offset_right = -insets.z
	_top_bar.offset_bottom = insets.y + TOP_BAR_HEIGHT

	for node in [_menu_center, _pause_center]:
		node.offset_left = insets.x
		node.offset_top = insets.y
		node.offset_right = -insets.z
		node.offset_bottom = -insets.w


# ---------------------------------------------------------------------------
# Gaya visual
# ---------------------------------------------------------------------------

## Mengikuti warna aksen skin yang sedang dipakai. Dipanggil Main setiap skin
## berganti, termasuk saat pratinjau di menu.
func set_accent_color(color: Color) -> void:
	_accent = color
	_apply_styles()


func _apply_styles() -> void:
	_stage_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, PANEL_RADIUS, 14, 4))
	_menu_card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, CARD_RADIUS, 26, 24))
	_pause_card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, CARD_RADIUS, 34, 28))

	for button in _all_buttons():
		_style_button(button)

	# Skor diberi garis tepi paling tebal: dialah yang harus terbaca sekilas,
	# bahkan saat melintas di atas mob yang terang.
	_style_label(_score_label, Color.WHITE, 8)
	_style_label(_message_label, _accent, 10)
	_style_label(_title_label, _accent, 6)
	_style_label(_pause_title, _accent, 6)
	_style_label(_stage_label, Color.WHITE, 4)
	_style_label(_best_label, Color(1, 1, 1, 0.75), 4)
	_style_label(_menu_best_label, Color(1, 1, 1, 0.75), 4)

	for label in [_stage_select_label, _skin_select_label, _control_select_label]:
		_style_label(label, Color(1, 1, 1, 0.6), 3)

	_refresh_heart_colors()


func _style_label(label: Label, color: Color, outline_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", outline_size)


func _make_panel_style(bg: Color, radius: int, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.border_color = Color(_accent.r, _accent.g, _accent.b, 0.22)
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style


func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(BUTTON_RADIUS)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## Tombol terpilih (dan tombol yang sedang ditekan) diisi penuh warna aksen,
## sehingga pilihan aktif langsung terlihat tanpa perlu tulisan tambahan.
func _style_button(button: Button) -> void:
	var soft := Color(_accent.r, _accent.g, _accent.b, 0.32)
	var strong := Color(_accent.r, _accent.g, _accent.b, 0.7)
	var fill := Color(_accent.r, _accent.g, _accent.b, 0.9)

	var normal := _make_button_style(Color(1, 1, 1, 0.06), soft)
	var hover := _make_button_style(Color(1, 1, 1, 0.13), strong)
	var pressed := _make_button_style(fill, Color(_accent.r, _accent.g, _accent.b, 1.0))

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	# Tanpa override ini, tombol pilihan yang sedang tersorot jari akan kembali
	# terlihat seperti tidak terpilih.
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var dark := Color(0.04, 0.05, 0.08)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", dark)
	button.add_theme_color_override("font_hover_pressed_color", dark)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	button.add_theme_constant_override("outline_size", 3)


func _all_buttons() -> Array[Button]:
	var buttons: Array[Button] = [_pause_button, _start_button, _resume_button, _quit_button]
	buttons.append_array(_stage_buttons)
	buttons.append_array(_skin_buttons)
	buttons.append_array(_control_buttons)
	return buttons


# ---------------------------------------------------------------------------
# Menu: stage, skin, kontrol
# ---------------------------------------------------------------------------

## Membuat tombol pemilih stage sesuai daftar stage yang tersedia di Main.
func setup_stages(stage_names: PackedStringArray) -> void:
	_stage_buttons = _build_buttons(
		_stage_container, stage_names, _stage_button_group, _on_stage_button_pressed,
		STAGE_BUTTON_FONT_SIZE, false, STAGE_BUTTON_MIN_SIZE
	)
	select_stage(selected_stage_index)


## Membuat tombol pemilih skin; tombol memakai nama skin supaya lebih jelas.
func setup_skins(skin_names: PackedStringArray) -> void:
	_skin_buttons = _build_buttons(
		_skin_container, skin_names, _skin_button_group, _on_skin_button_pressed,
		SKIN_BUTTON_FONT_SIZE, true, WIDE_BUTTON_MIN_SIZE
	)
	select_skin(selected_skin_index)


## Membuat tombol pemilih skema kontrol sentuh. Pilihannya bertahan antar sesi
## lewat GameSettings, jadi nilai awalnya dibaca dari sana.
func setup_controls() -> void:
	_control_buttons = _build_buttons(
		_control_container, PackedStringArray(GameSettings.CONTROL_SCHEME_NAMES),
		_control_button_group, _on_control_button_pressed,
		CONTROL_BUTTON_FONT_SIZE, true, WIDE_BUTTON_MIN_SIZE
	)
	select_control(GameSettings.control_scheme)


## Memilih stage berdasarkan index (juga dipakai untuk menentukan pilihan awal).
func select_stage(index: int) -> void:
	selected_stage_index = _press_button(_stage_buttons, index)


## Memilih skin berdasarkan index (juga dipakai untuk menentukan pilihan awal).
func select_skin(index: int) -> void:
	selected_skin_index = _press_button(_skin_buttons, index)


## Memilih skema kontrol berdasarkan index.
func select_control(index: int) -> void:
	selected_control_index = _press_button(_control_buttons, index)


## Membuat satu baris tombol pilihan (radio) di dalam sebuah container.
func _build_buttons(
	container: Node,
	labels: PackedStringArray,
	group: ButtonGroup,
	on_pressed: Callable,
	font_size: int,
	use_label_as_text: bool,
	min_size: Vector2
) -> Array[Button]:
	for child in container.get_children():
		child.queue_free()
	_press_tweens.clear()

	var buttons: Array[Button] = []
	var button_font: Font = _start_button.get_theme_font("font")
	for i in labels.size():
		var button := Button.new()
		button.text = labels[i] if use_label_as_text else str(i + 1)
		button.tooltip_text = labels[i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = min_size
		# Tombol berlabel teks (skin, kontrol) membagi lebar container secara
		# merata, jadi baris 2 kolom terlihat rapi dan namanya tidak terpotong.
		# Tombol bernomor (pemilih stage) dibiarkan tetap persegi.
		if use_label_as_text:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", button_font)
		button.add_theme_font_size_override("font_size", font_size)
		button.pressed.connect(on_pressed.bind(i))
		_style_button(button)
		_add_press_feedback(button)
		container.add_child(button)
		buttons.append(button)

	return buttons


## Menyalakan tombol ke-index dan mengembalikan index yang benar-benar dipakai.
func _press_button(buttons: Array[Button], index: int) -> int:
	if buttons.is_empty():
		return index

	var pressed_index := clampi(index, 0, buttons.size() - 1)
	buttons[pressed_index].button_pressed = true
	return pressed_index


# ---------------------------------------------------------------------------
# Umpan balik sentuh
# ---------------------------------------------------------------------------

## Tombol mengecil sedikit saat ditekan. Di layar sentuh tidak ada kursor yang
## menandai "aku menyentuh di sini", jadi tanpa umpan balik ini tombol terasa mati.
func _add_press_feedback(button: Button) -> void:
	button.button_down.connect(_on_any_button_down.bind(button))
	button.button_up.connect(_on_any_button_up.bind(button))


func _on_any_button_down(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	_scale_control(button, Vector2.ONE * PRESS_SCALE, PRESS_TIME)


func _on_any_button_up(button: Button) -> void:
	_scale_control(button, Vector2.ONE, PRESS_TIME)


func _scale_control(control: Control, target: Vector2, duration: float) -> void:
	var previous = _press_tweens.get(control)
	if previous is Tween and previous.is_valid():
		previous.kill()

	var tween := control.create_tween()
	tween.tween_property(control, "scale", target, duration).set_trans(Tween.TRANS_SINE)
	_press_tweens[control] = tween


## Sentakan kecil "pop": membesar lalu kembali. Dipakai untuk skor yang naik dan
## hati yang padam.
func _pop(control: Control, amount: float) -> void:
	_center_pivot(control)
	control.scale = Vector2.ONE * amount
	_scale_control(control, Vector2.ONE, POP_TIME)


func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


## Menjaga titik putar sebuah Control tetap di tengah, termasuk setelah teksnya
## berubah panjang atau layar berubah ukuran.
func _keep_pivot_centered(control: Control) -> void:
	control.resized.connect(_center_pivot.bind(control))
	_center_pivot(control)


## Judul "bernapas" perlahan. Sengaja memakai scale, bukan position: posisi anak
## sebuah Container akan ditimpa setiap kali tata letak dihitung ulang, sedangkan
## scale tidak pernah disentuh.
func _start_title_breath() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_title_label, "scale", Vector2.ONE * 1.035, 1.6) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title_label, "scale", Vector2.ONE, 1.6) \
		.set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Nyawa, skor, stage
# ---------------------------------------------------------------------------

## Membuat deretan ikon hati sebanyak nyawa maksimum.
func setup_lives(max_lives: int) -> void:
	for child in _lives_box.get_children():
		child.queue_free()
	_hearts.clear()
	_shown_lives = -1

	for _i in maxi(max_lives, 0):
		var heart := TextureRect.new()
		heart.texture = _heart_texture
		heart.custom_minimum_size = HEART_SIZE
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart.pivot_offset = HEART_SIZE * 0.5
		_lives_box.add_child(heart)
		_hearts.append(heart)

	_refresh_heart_colors()


## Menampilkan sisa nyawa pemain. Hati yang baru padam diberi sentakan supaya
## pemain sadar dia kehilangan sesuatu.
func update_lives(lives: int) -> void:
	var previous := _shown_lives
	_shown_lives = lives
	_refresh_heart_colors()

	if previous > lives and lives >= 0 and lives < _hearts.size():
		_pop(_hearts[lives], 1.5)


## Mengganti ikon nyawa mengikuti skin: kerang untuk skin laut, hati untuk yang
## lain. Cukup menukar tekstur, tanpa membangun ulang deretan hati, supaya sisa
## nyawa yang sedang ditampilkan tidak ikut ter-reset.
func set_life_icon(texture: Texture2D) -> void:
	var next: Texture2D = texture if texture != null else _default_heart_texture
	if next == _heart_texture:
		return

	_heart_texture = next
	for heart in _hearts:
		heart.texture = _heart_texture


func _refresh_heart_colors() -> void:
	# Hati dibuat putih di berkas SVG-nya, jadi warnanya sepenuhnya ditentukan
	# modulate - sekali gambar, semua skin terlayani.
	var alive_color := Color(_accent.r, _accent.g, _accent.b, 1.0).lerp(Color.WHITE, 0.35)
	for i in _hearts.size():
		_hearts[i].modulate = alive_color if i < _shown_lives else HEART_DIM


func update_score(score: int) -> void:
	_score_label.text = str(score)
	_pop(_score_label, 1.08)


## Menampilkan nama stage yang sedang dimainkan.
func update_stage(stage_name: String) -> void:
	_stage_label.text = stage_name


## Skor terbaik stage ini, ditampilkan di bawah skor saat bermain.
func update_best(best: int) -> void:
	_best_label.text = "Terbaik: %d" % best


## Skor terbaik stage yang sedang dipilih di menu.
func update_menu_best(best: int) -> void:
	_menu_best_label.text = "Terbaik: %d" % best


# ---------------------------------------------------------------------------
# Popup item
# ---------------------------------------------------------------------------

## Popup kecil "ikon + nilai" yang mengapung naik lalu memudar setiap pemain
## mengambil item.
##
## Dibangun di kode, bukan sebagai node di HUD.tscn, mengikuti gaya yang sudah
## dipakai _build_buttons() dan _make_panel_style().
##
## Posisinya tetap di bawah panel skor, bukan di titik item diambil: Camera2D di
## scene ini melakukan punch() dan shake(), jadi popup yang dipaku ke koordinat
## dunia akan ikut bergoyang justru saat pemain sedang berusaha membacanya.
func show_pickup(icon: Texture2D, text: String, color: Color) -> void:
	# Popup sebelumnya dibuang tanpa animasi: dua popup di titik yang sama hanya
	# akan saling menimpa.
	if _pickup_popup != null and is_instance_valid(_pickup_popup):
		_pickup_popup.queue_free()

	var insets := SafeArea.get_insets(get_viewport())
	var top := insets.y + TOP_BAR_HEIGHT

	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_left = insets.x
	holder.offset_right = -insets.z
	holder.offset_top = top
	holder.offset_bottom = top + PICKUP_POPUP_HEIGHT
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)

	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = PICKUP_ICON_SIZE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _score_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", PICKUP_FONT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(label, color, 6)
	row.add_child(label)

	add_child(holder)
	_pickup_popup = holder

	# Naik dengan menggeser kedua offset sekaligus, bukan dengan menganimasikan
	# "position": posisi sebuah Control ber-anchor baru terhitung setelah tata
	# letak dihitung, jadi nilainya belum bisa dibaca di sini.
	var tween := holder.create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(holder, "offset_top", top - PICKUP_POPUP_RISE, PICKUP_POPUP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		holder, "offset_bottom", top + PICKUP_POPUP_HEIGHT - PICKUP_POPUP_RISE, PICKUP_POPUP_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "modulate:a", 0.0, PICKUP_POPUP_FADE) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(holder.queue_free)


## Membuang popup item yang masih tersisa, supaya tidak ikut terbawa ke layar menu.
func _clear_pickup_popup() -> void:
	if _pickup_popup != null and is_instance_valid(_pickup_popup):
		_pickup_popup.queue_free()

	_pickup_popup = null


# ---------------------------------------------------------------------------
# Pesan & transisi
# ---------------------------------------------------------------------------

func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.show()
	_message_label.modulate.a = 0.0
	_message_label.scale = Vector2.ONE * 0.82

	_kill_tween(_message_tween)
	_message_tween = create_tween().set_parallel(true)
	_message_tween.tween_property(_message_label, "modulate:a", 1.0, 0.18)
	_message_tween.tween_property(_message_label, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_message_timer.start()


func _hide_message() -> void:
	_message_timer.stop()
	_kill_tween(_message_tween)
	_message_tween = create_tween()
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.22) \
		.set_trans(Tween.TRANS_SINE)
	_message_tween.tween_callback(_message_label.hide)


func _hide_message_instant() -> void:
	_message_timer.stop()
	_kill_tween(_message_tween)
	_message_label.hide()


func show_menu() -> void:
	_kill_tween(_transition_tween)

	_top_bar.hide()
	_pause_center.hide()
	_hide_message_instant()
	_clear_pickup_popup()

	_menu_center.show()
	_menu_card.modulate.a = 0.0
	_menu_card.scale = Vector2.ONE * 0.92

	_dim_rect.show()

	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(_dim_rect, "color:a", MENU_DIM, FADE_TIME) \
		.set_trans(Tween.TRANS_SINE)
	_transition_tween.tween_property(_menu_card, "modulate:a", 1.0, FADE_TIME)
	_transition_tween.tween_property(_menu_card, "scale", Vector2.ONE, FADE_TIME * 1.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_menu() -> void:
	_kill_tween(_transition_tween)

	_menu_center.hide()
	_top_bar.show()

	_transition_tween = create_tween()
	_transition_tween.tween_property(_dim_rect, "color:a", 0.0, FADE_TIME) \
		.set_trans(Tween.TRANS_SINE)
	_transition_tween.tween_callback(_dim_rect.hide)


## Rangkaian game over: layar meredup, tulisan masuk dengan sentakan, lalu menu
## kembali sendiri. Dulu ini rantai "await"; dengan tween seluruh rangkaian bisa
## dibatalkan sekaligus kalau pemain memulai permainan baru di tengah jalan.
func show_game_over(final_score: int, best: int, is_new_best: bool) -> void:
	_kill_tween(_transition_tween)
	_set_paused(false)
	set_pause_available(false)

	update_score(final_score)
	update_best(best)

	_message_label.text = "Rekor Baru!" if is_new_best else "Game Over"
	_message_label.show()
	_message_label.modulate.a = 0.0
	_message_label.scale = Vector2.ONE * 0.6
	_message_timer.stop()

	_dim_rect.show()

	_transition_tween = create_tween()
	_transition_tween.tween_property(_dim_rect, "color:a", OVERLAY_DIM, 0.35) \
		.set_trans(Tween.TRANS_SINE)
	_transition_tween.parallel().tween_property(_message_label, "modulate:a", 1.0, 0.25)
	_transition_tween.parallel().tween_property(_message_label, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_interval(GAME_OVER_HOLD)
	_transition_tween.tween_callback(_hide_message)
	_transition_tween.tween_interval(0.3)
	_transition_tween.tween_callback(show_menu)


## Kilat layar penuh saat benturan; warnanya mengikuti aksen skin.
func flash(tint: Color = Color.WHITE, strength: float = 0.45) -> void:
	_flash_rect.flash(tint, strength)


## Mengembalikan semua efek layar ke keadaan tenang, dipanggil saat permainan baru.
func reset_effects() -> void:
	_flash_rect.reset()
	_clear_pickup_popup()


## Kembali ke menu dari layar jeda.
func return_to_menu() -> void:
	_set_paused(false)
	set_pause_available(false)
	show_menu()


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


# ---------------------------------------------------------------------------
# Jeda
# ---------------------------------------------------------------------------

## Tombol jeda hanya ada selagi bermain.
func set_pause_available(available: bool) -> void:
	_pause_available = available
	_pause_button.visible = available

	if not available and _paused:
		_set_paused(false)


func _set_paused(value: bool) -> void:
	if value and not _pause_available:
		return
	if _paused == value:
		return

	_paused = value
	get_tree().paused = value

	if value:
		_pause_center.show()
		_dim_rect.show()
		_dim_rect.color.a = 0.0
		_pause_card.modulate.a = 0.0
		_pause_card.scale = Vector2.ONE * 0.9

		var tween := create_tween().set_parallel(true)
		tween.tween_property(_dim_rect, "color:a", OVERLAY_DIM, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_pause_card, "modulate:a", 1.0, 0.2)
		tween.tween_property(_pause_card, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Melanjutkan permainan harus langsung, tanpa animasi: pemain sudah siap
		# dan setiap milidetik tambahan terasa seperti kendali yang direbut.
		_pause_center.hide()
		_dim_rect.hide()
		_dim_rect.color.a = 0.0

	pause_changed.emit(value)


## Tombol Escape / P di desktop. Memakai _unhandled_input supaya tombol di layar
## tetap mendapat giliran lebih dulu.
func _unhandled_input(event: InputEvent) -> void:
	if not _pause_available:
		return

	if event.is_action_pressed("jeda"):
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()


## Ganti tab di browser HP, telepon masuk, atau layar terkunci tidak boleh
## berarti mati sia-sia: permainan dijeda sendiri begitu fokus hilang.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return

	# _pause_available hanya pernah true setelah Main menyalakannya, jadi
	# pengecekan ini sekaligus menjamin scene sudah siap.
	if _pause_available:
		_set_paused(true)


# ---------------------------------------------------------------------------
# Sinyal tombol
# ---------------------------------------------------------------------------

func _on_stage_button_pressed(index: int) -> void:
	selected_stage_index = index
	stage_selected.emit(index)


func _on_skin_button_pressed(index: int) -> void:
	selected_skin_index = index
	skin_selected.emit(index)


func _on_control_button_pressed(index: int) -> void:
	selected_control_index = index
	GameSettings.set_control_scheme(index)


func _on_start_button_pressed() -> void:
	hide_menu()
	start_game.emit(selected_stage_index, selected_skin_index)


func _on_pause_button_pressed() -> void:
	_set_paused(true)


func _on_resume_button_pressed() -> void:
	_set_paused(false)


func _on_quit_button_pressed() -> void:
	_set_paused(false)
	quit_requested.emit()


func _on_message_timer_timeout() -> void:
	_hide_message()
