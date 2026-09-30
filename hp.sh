#!/bin/sh
# Export ulang ke Web lalu sajikan lewat Wi-Fi supaya bisa dibuka di HP.
#
# Pakai: ./hp.sh
# Berhenti: Ctrl-C
#
# Alur kerja sehari-hari: ubah apa pun di Godot, simpan, jalankan skrip ini,
# lalu muat ulang halaman di HP. Tidak perlu git, tidak perlu hosting — folder
# build/ cuma hasil sementara dan boleh dihapus kapan saja.

set -e

PORT=8000
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
PROJECT=$(cd "$(dirname "$0")" && pwd)

[ -x "$GODOT" ] || { echo "Godot tidak ada di $GODOT"; exit 1; }

echo "==> Export Web..."
# Baris progres export sangat berisik; yang penting hanya kalau gagal.
"$GODOT" --headless --path "$PROJECT" --export-release Web build/index.html >/dev/null

# IP Wi-Fi berubah setiap pindah jaringan, jadi selalu dibaca ulang — bukan
# ditulis tetap di sini.
IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1) || {
	echo "Tidak terhubung ke Wi-Fi."; exit 1; }

echo
echo "==> Buka di HP (Wi-Fi yang sama):  http://$IP:$PORT"
echo "    Ctrl-C untuk berhenti."
echo

cd "$PROJECT/build"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
