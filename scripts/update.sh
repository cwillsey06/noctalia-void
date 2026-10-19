#!/usr/bin/env bash
# Bump templates in srcpkgs/ to the newest upstream versions.
#
# Usage: scripts/update.sh --vp VOID_PACKAGES_DIR [--git] [pkg ...]
#
#   Release packages (no _commit): asks Void's own 'xbps-src update-check'
#   for newer GitHub tags; bumps version, resets revision to 1.
#   Snapshot packages (_commit set): only with --git, moves to the latest
#   commit on the default branch; version becomes 0.0.<UTC date>.
#   Any template whose checksum is the all-zero placeholder gets a real one.
#
# Edits templates in THIS repo (copy them into void-packages afterwards).
# Prints the names of changed packages on stdout, one per line; logs go
# to stderr. Needs: bash, curl, git, sha256sum, xbps-uhelper.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
vp= git=0
while [ $# -gt 0 ]; do
	case $1 in
		--vp) vp=$2; shift 2 ;;
		--git) git=1; shift ;;
		-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
		*) break ;;
	esac
done
[ -n "$vp" ] || { echo "--vp is required" >&2; exit 2; }
vp=$(cd "$vp" && pwd)

if [ $# -gt 0 ]; then
	pkgs=("$@")
else
	pkgs=()
	for d in "$root"/srcpkgs/*/; do pkgs+=("$(basename "$d")"); done
fi

log() { echo "$@" >&2; }

# Read a variable from a template without running any build functions.
tvar() {
	( set +eu; XBPS_TARGET_LIBC=glibc; . "$1" >/dev/null 2>&1; eval "printf '%s' \"\${$2:-}\"" )
}

set_field() { sed -i "s|^$2=.*|$2=$3|" "$1"; }

set_checksum() {
	local t=$1 url sum
	url=$(tvar "$t" distfiles)
	log "   fetching $url"
	sum=$(curl -fsSL --retry 3 "$url" | sha256sum | cut -d' ' -f1)
	set_field "$t" checksum "$sum"
}

# 1 if $1 > $2, 0 if equal, 255 if lower
cmpver() { local rc=0; xbps-uhelper cmpver "$1" "$2" || rc=$?; echo "$rc"; }

for p in "${pkgs[@]}"; do
	t=$root/srcpkgs/$p/template
	[ -f "$t" ] || { log "no template for $p"; exit 1; }
	cur=$(tvar "$t" version)
	commit=$(tvar "$t" _commit)
	changed=0

	if [ -z "$commit" ]; then
		# Release-tagged package: use Void's update-check
		mkdir -p "$vp/srcpkgs/$p"
		cp "$t" "$vp/srcpkgs/$p/template"
		[ -f "$root/srcpkgs/$p/update" ] && cp "$root/srcpkgs/$p/update" "$vp/srcpkgs/$p/"
		rc=0
		out=$(cd "$vp" && ./xbps-src update-check "$p" 2>&1) || rc=$?
		if [ "$rc" != 0 ]; then
			# Don't fail the run, but make it visible (GitHub shows ::warning::)
			log "::warning::update-check failed for $p (exit $rc): $(printf '%s' "$out" | tail -n3 | tr '\n' ' ')"
		fi
		new=$(printf '%s\n' "$out" | sed -n "s/^.* -> ${p}-//p" | sort -V | tail -n1)
		if [ -n "$new" ] && [ "$(cmpver "$new" "$cur")" = 1 ]; then
			log ">> $p: $cur -> $new"
			set_field "$t" version "$new"
			set_field "$t" revision 1
			set_checksum "$t"
			changed=1
		else
			log ">> $p: $cur is current"
		fi
	elif [ "$git" = 1 ]; then
		# Commit snapshot: follow upstream's default branch
		head=$(git ls-remote "$(tvar "$t" homepage)" HEAD | cut -f1)
		if [ -n "$head" ] && [ "$head" != "$commit" ]; then
			new=0.0.$(date -u +%Y%m%d)
			log ">> $p: ${commit:0:12} -> ${head:0:12} ($new)"
			set_field "$t" _commit "$head"
			if [ "$new" = "$cur" ]; then
				# second bump on the same day
				set_field "$t" revision $(( $(tvar "$t" revision) + 1 ))
			else
				set_field "$t" version "$new"
				set_field "$t" revision 1
			fi
			set_checksum "$t"
			changed=1
		else
			log ">> $p: snapshot ${commit:0:12} is current"
		fi
	fi

	if grep -q '^checksum=0\{64\}$' "$t"; then
		log ">> $p: filling placeholder checksum"
		set_checksum "$t"
		changed=1
	fi

	[ "$changed" = 1 ] && echo "$p"
done
exit 0
