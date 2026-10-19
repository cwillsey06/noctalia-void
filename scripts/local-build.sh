#!/usr/bin/env bash
# Smoke-test build of this repo's packages on a Void host, using xbps-src.
#
# Build-time dependencies are installed ONLY inside xbps-src's chroot
# ("masterdir"), never on your system, and are removed after each build.
#
# Usage:
#   scripts/local-build.sh [options] [pkg ...]      (default: noctalia noctalia-greeter)
#
# Options:
#   -w DIR     work directory (default: ${XDG_CACHE_HOME:-~/.cache}/noctalia-void)
#              Put it on whichever disk has the most room.
#   -j N       parallel jobs (default: nproc)
#   -c         clean up after: wipe the chroot, downloaded sources and build dirs
#              (keeps the built .xbps files)
#   -p         purge: delete the whole work directory and exit
#   -u         also run 'xbps-src update-check' for each package
#
# Needs: git, xtools (for xgensum), and xbps (already on Void).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
workdir=${XDG_CACHE_HOME:-$HOME/.cache}/noctalia-void
jobs=$(nproc)
clean=0 purge=0 updcheck=0

while getopts "w:j:cpuh" opt; do
	case $opt in
		w) workdir=$OPTARG ;;
		j) jobs=$OPTARG ;;
		c) clean=1 ;;
		p) purge=1 ;;
		u) updcheck=1 ;;
		*) sed -n '2,20p' "$0"; exit 0 ;;
	esac
done
shift $((OPTIND - 1))
if [ $# -gt 0 ]; then pkgs=("$@"); else pkgs=(noctalia noctalia-greeter); fi

vp=$workdir/void-packages

if [ "$purge" = 1 ]; then
	if [ -d "$vp" ]; then
		( cd "$vp" && ./xbps-src zap ) || true
	fi
	rm -rf "$workdir"
	echo "Removed $workdir"
	exit 0
fi

for cmd in git xgensum; do
	command -v "$cmd" >/dev/null || {
		echo "Missing '$cmd'. Install with: sudo xbps-install git xtools" >&2
		exit 1
	}
done

mkdir -p "$workdir"
avail_kb=$(df -Pk "$workdir" | awk 'NR==2 {print $4}')
echo "Free space at $workdir: $((avail_kb / 1024 / 1024)) GiB"
if [ "$avail_kb" -lt $((6 * 1024 * 1024)) ]; then
	echo "Warning: under 6 GiB free; a Noctalia build may run out of space." >&2
	echo "Use -w to point at a bigger disk, or Ctrl-C now." >&2
	sleep 5
fi

# 1. Shallow checkout of official void-packages (no full fork needed)
if [ ! -d "$vp/.git" ]; then
	git clone --depth 1 https://github.com/void-linux/void-packages "$vp"
else
	git -C "$vp" pull --ff-only --depth 1 || echo "Could not update void-packages; using existing checkout."
fi

# 2. Overlay our templates. Copied, not symlinked: builds run in a chroot
#    where paths outside void-packages don't exist, and xbps-src treats
#    symlinks in srcpkgs/ as subpackages.
for d in "$repo_root"/srcpkgs/*/; do
	name=$(basename "$d")
	rm -rf "${vp:?}/srcpkgs/$name"
	cp -r "$d" "$vp/srcpkgs/$name"
done

cd "$vp"

# 3. Chroot with only base packages (once; reused afterwards)
if [ ! -e masterdir-x86_64/.xbps_chroot_init ] && [ ! -e masterdir/.xbps_chroot_init ]; then
	./xbps-src binary-bootstrap
fi

# 4. Fill in placeholder checksums, then build each package
for p in "${pkgs[@]}"; do
	tmpl=srcpkgs/$p/template
	[ -f "$tmpl" ] || { echo "No such package: $p" >&2; exit 1; }
	if grep -q '^checksum=0\{64\}$' "$tmpl"; then
		echo ">> Computing checksum for $p"
		xgensum -i "$p"
		# write the real checksum back into this repo
		cp "$tmpl" "$repo_root/srcpkgs/$p/template"
	fi
	echo ">> Building $p"
	./xbps-src -j "$jobs" pkg "$p"
	if [ "$updcheck" = 1 ]; then
		echo ">> update-check $p (no output = up to date)"
		./xbps-src update-check "$p" || true
	fi
done

binpkgs=$vp/hostdir/binpkgs
echo
echo "Built packages:"
ls -1 "$binpkgs"/*.xbps 2>/dev/null || true
echo
echo "To install from this local repo:"
echo "  sudo xbps-install --repository=$binpkgs ${pkgs[*]}"

if [ "$clean" = 1 ]; then
	echo ">> Removing chroot and downloaded sources (keeping $binpkgs)"
	./xbps-src zap
	rm -rf hostdir/sources hostdir/ccache
fi
