#!/bin/sh
# Terbitkan versi terbaru game ke internet (GitHub Pages).
#
# Pakai: ./publish.sh
#
# Alur kerja setelah menambah fitur di Godot:
#     simpan di Godot  ->  ./publish.sh  ->  tunggu ~1 menit  ->  muat ulang di HP
#
# Alamat game tidak pernah berubah, jadi link yang sudah Anda sebarkan ke orang
# lain akan langsung menampilkan versi baru tanpa perlu dikirim ulang.

set -e

GODOT=/Applications/Godot.app/Contents/MacOS/Godot
PROJECT=$(cd "$(dirname "$0")" && pwd)
WORKTREE=/tmp/ghpages

[ -x "$GODOT" ] || { echo "Godot tidak ada di $GODOT"; exit 1; }

echo "==> 1/3  Export Web..."
"$GODOT" --headless --path "$PROJECT" --export-release Web build/index.html >/dev/null

echo "==> 2/3  Menyiapkan cabang gh-pages..."
# Worktree terpisah supaya cabang gh-pages (hasil cetakan) tidak pernah
# tercampur dengan cabang main (sumber). Dibuat ulang tiap kali agar tidak ada
# sisa berkas dari export sebelumnya.
git -C "$PROJECT" worktree remove --force "$WORKTREE" 2>/dev/null || true
rm -rf "$WORKTREE"
git -C "$PROJECT" fetch -q origin gh-pages
git -C "$PROJECT" worktree add -q "$WORKTREE" gh-pages

find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R "$PROJECT/build/." "$WORKTREE/"
rm -f "$WORKTREE/.gdignore"
# Tanpa berkas ini GitHub menjalankan Jekyll, yang mengabaikan sebagian berkas.
touch "$WORKTREE/.nojekyll"

echo "==> 3/3  Mengunggah (~40 MB, bisa beberapa menit)..."
# Buffer besar + batas kecepatan dimatikan: unggahan 40 MB di koneksi lambat
# kalau tidak akan diputus server dengan HTTP 408.
git -C "$WORKTREE" config http.postBuffer 524288000
git -C "$WORKTREE" config http.lowSpeedLimit 0
git -C "$WORKTREE" config http.lowSpeedTime 999999
git -C "$WORKTREE" config http.version HTTP/1.1

git -C "$WORKTREE" add -A
if git -C "$WORKTREE" diff --cached --quiet; then
	echo "    Tidak ada perubahan — tidak ada yang perlu diunggah."
else
	git -C "$WORKTREE" commit -q -m "Perbarui hasil export Web"
	git -C "$WORKTREE" push -q origin gh-pages
fi

URL=$(git -C "$PROJECT" remote get-url origin \
	| sed -E 's#.*github.com[:/]([^/]+)/(.+)\.git#https://\1.github.io/\2/#')

echo
echo "==> Selesai. GitHub perlu ~1 menit untuk menayangkannya."
echo "    $URL"
