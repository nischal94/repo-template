#!/usr/bin/env bash
set -euo pipefail
if [ -f vercel.json ]; then
  echo "==> Deploy to Vercel (long-lived token; documented gap §4.6)..."
  npx vercel --token="$VERCEL_TOKEN" --prebuilt --prod=false
elif [ -f fly.toml ]; then
  echo "==> Deploy to Fly.io (long-lived token; documented gap §4.6)..."
  flyctl deploy --remote-only --access-token="$FLY_API_TOKEN"
elif [ -f railway.toml ]; then
  echo "==> Deploy to Railway (long-lived token; documented gap §4.6)..."
  npx -y @railway/cli up --token="$RAILWAY_TOKEN"
else
  echo "No CD target detected (no vercel.json / fly.toml / railway.toml). Skipping."
fi
