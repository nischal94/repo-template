#!/usr/bin/env bash
# Deploy to the configured target. Writes ONLY the preview URL to stdout
# (banners go to stderr) so the caller can `URL=$(bash cd-deploy.sh)`
# cleanly and pass URL to the downstream smoke test.
set -euo pipefail

# extract_url_for <target> <file>: emit the first product-domain URL found.
# Each deploy CLI prints multiple https:// URLs — Vercel emits an `Inspect:
# https://vercel.com/...` dashboard URL BEFORE the deployment URL. A naive
# `grep -oE 'https://...' | head -1` would grab the dashboard URL and the
# downstream smoke test would curl the wrong target. Pinning to the
# product domain disambiguates.
extract_url_for() {
	local target=$1
	local file=$2
	case "$target" in
	# LHS character class allows dots in addition to alphanumerics + hyphens.
	# Default Vercel/Fly/Railway subdomains are single-label (hyphenated, no
	# internal dots), so this is defensive — covers possible future formats
	# (e.g. scoped multi-label subdomains) without overmatching since the
	# regex is still pinned to the product TLD.
	vercel) grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[a-zA-Z0-9._/-]*' "$file" | head -1 ;;
	fly) grep -oE 'https://[a-zA-Z0-9.-]+\.fly\.dev[a-zA-Z0-9._/-]*' "$file" | head -1 ;;
	railway) grep -oE 'https://[a-zA-Z0-9.-]+\.up\.railway\.app[a-zA-Z0-9._/-]*' "$file" | head -1 ;;
	esac
}

# Single temp file with a trap so it cleans up even on failure.
TMP=$(mktemp)
trap '/bin/rm -f "$TMP"' EXIT

if [ -f vercel.json ]; then
	echo "==> Deploy to Vercel (long-lived token; documented gap §4.6)..." >&2
	npx vercel --token="$VERCEL_TOKEN" --prebuilt --prod=false 2>&1 | tee "$TMP" >&2
	URL=$(extract_url_for vercel "$TMP")
	if [ -z "${URL:-}" ]; then
		echo "::error::cd-deploy.sh: could not parse *.vercel.app URL from vercel CLI output" >&2
		exit 1
	fi
	echo "$URL"
elif [ -f fly.toml ]; then
	echo "==> Deploy to Fly.io (long-lived token; documented gap §4.6)..." >&2
	flyctl deploy --remote-only --access-token="$FLY_API_TOKEN" 2>&1 | tee "$TMP" >&2
	URL=$(extract_url_for fly "$TMP")
	if [ -z "${URL:-}" ]; then
		echo "::error::cd-deploy.sh: could not parse *.fly.dev URL from flyctl output" >&2
		exit 1
	fi
	echo "$URL"
elif [ -f railway.toml ]; then
	echo "==> Deploy to Railway (long-lived token; documented gap §4.6)..." >&2
	npx -y @railway/cli up --token="$RAILWAY_TOKEN" 2>&1 | tee "$TMP" >&2
	URL=$(extract_url_for railway "$TMP")
	if [ -z "${URL:-}" ]; then
		echo "::error::cd-deploy.sh: could not parse *.up.railway.app URL from railway output" >&2
		exit 1
	fi
	echo "$URL"
else
	echo "No CD target detected (no vercel.json / fly.toml / railway.toml). Skipping." >&2
	# Empty stdout. The cd-deploy workflow's smoke job has
	# `if: needs.deploy.outputs.preview-url != ''` so it correctly skips.
fi
