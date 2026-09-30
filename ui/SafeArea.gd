class_name SafeArea
extends RefCounted

## Menghitung margin aman di tepi layar: notch, punch-hole, bilah gestur, dan
## di Web juga UI browser yang bisa muncul-hilang.
##
## Catatan penting: DisplayServer.get_display_safe_area() memberi nilai dalam
## piksel layar, sedangkan game memakai koordinat kanvas logis (480x720 yang
## diregangkan oleh stretch mode "canvas_items"). Keduanya harus dikonversi,
## kalau tidak margin akan terasa terlalu besar di layar ber-DPI tinggi.
##
## Ada dua sumber yang dipakai, lalu diambil yang paling besar per sisi:
## CSS env(safe-area-inset-*) lewat web/head_include.html (satu-satunya yang
## tahu notch di browser) dan DisplayServer (untuk build native).

## Margin minimum (dalam satuan kanvas) yang selalu dipakai, bahkan ketika
## sistem melaporkan tidak ada area terpotong. Di browser HP nilai sistemnya
## biasanya kosong, jadi angka inilah yang menjaga HUD tetap terbaca.
const MIN_TOP := 28.0
const MIN_BOTTOM := 24.0
const MIN_SIDE := 16.0


## Margin aman sebagai Vector4: (kiri, atas, kanan, bawah) dalam satuan kanvas.
static func get_insets(viewport: Viewport) -> Vector4:
	var insets := Vector4(MIN_SIDE, MIN_TOP, MIN_SIDE, MIN_BOTTOM)
	if viewport == null:
		return insets

	var canvas_size := viewport.get_visible_rect().size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return insets

	# Sumber pertama: CSS env(safe-area-inset-*) di browser. Di Web inilah
	# satu-satunya yang tahu soal notch — DisplayServer selalu melapor nol.
	var web := _web_inset_ratios()
	insets = Vector4(
		maxf(insets.x, web.x * canvas_size.x),
		maxf(insets.y, web.y * canvas_size.y),
		maxf(insets.z, web.z * canvas_size.x),
		maxf(insets.w, web.w * canvas_size.y)
	)

	# Sumber kedua: sistem operasi (Android/iOS native).
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return insets

	var safe := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or screen_size.x <= 0 or screen_size.y <= 0:
		return insets

	# Piksel yang terpotong di setiap sisi, menurut sistem operasi.
	var cut_left := float(safe.position.x)
	var cut_top := float(safe.position.y)
	var cut_right := float(screen_size.x - safe.position.x - safe.size.x)
	var cut_bottom := float(screen_size.y - safe.position.y - safe.size.y)

	# Konversi piksel layar -> satuan kanvas.
	var to_canvas := canvas_size / window_size

	return Vector4(
		maxf(insets.x, cut_left * to_canvas.x),
		maxf(insets.y, cut_top * to_canvas.y),
		maxf(insets.z, cut_right * to_canvas.x),
		maxf(insets.w, cut_bottom * to_canvas.y)
	)


## Margin aman versi browser, sebagai rasio ukuran jendela (0..1) per sisi.
##
## Nilainya disediakan oleh window.gameSafeArea() dari web/head_include.html.
## Rasio, bukan piksel, karena piksel CSS dan piksel kanvas berbeda sebesar
## devicePixelRatio — dengan rasio, pengali yang benar cukup ukuran kanvas
## sendiri.
##
## Tiap kegagalan (bukan Web, bridge tidak ada, head include belum terpasang,
## format tak terduga) pulang sebagai nol, dan pemanggil akan memakai margin
## minimum. Jadi versi tanpa head include tetap jalan, cuma kurang presisi.
static func _web_inset_ratios() -> Vector4:
	if not OS.has_feature("web"):
		return Vector4.ZERO

	# Diakses lewat Engine.get_singleton, bukan langsung: JavaScriptBridge tidak
	# terdaftar di platform lain, dan menyebutnya langsung membuat skrip ini
	# gagal dikompilasi di desktop.
	if not Engine.has_singleton("JavaScriptBridge"):
		return Vector4.ZERO

	var bridge := Engine.get_singleton("JavaScriptBridge")
	var raw = bridge.eval("window.gameSafeArea ? window.gameSafeArea() : ''", true)
	if not (raw is String):
		return Vector4.ZERO

	var parts := (raw as String).split(",")
	if parts.size() != 4:
		return Vector4.ZERO

	return Vector4(
		clampf(parts[0].to_float(), 0.0, 0.25),
		clampf(parts[1].to_float(), 0.0, 0.25),
		clampf(parts[2].to_float(), 0.0, 0.25),
		clampf(parts[3].to_float(), 0.0, 0.25)
	)


## Persegi area bermain yang sudah dikurangi margin aman, ditambah "padding"
## ekstra (misalnya radius sprite pemain supaya tidak separuh keluar layar).
static func get_play_rect(viewport: Viewport, padding: float = 0.0) -> Rect2:
	var canvas_size := Vector2(480, 720)
	if viewport != null:
		canvas_size = viewport.get_visible_rect().size

	var insets := get_insets(viewport)
	var top_left := Vector2(insets.x + padding, insets.y + padding)
	var bottom_right := canvas_size - Vector2(insets.z + padding, insets.w + padding)

	# Layar yang sangat kecil bisa membuat margin saling melewati; jaga supaya
	# ukurannya tidak pernah negatif.
	var size := bottom_right - top_left
	return Rect2(top_left, Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
