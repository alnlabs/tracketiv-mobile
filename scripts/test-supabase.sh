#!/usr/bin/env bash
# Reset local Supabase, run pgTAP DB tests, then Flutter integration tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Checking Supabase CLI..."
if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI not found. Install: https://supabase.com/docs/guides/cli"
  exit 1
fi

echo "==> Resetting local database (migrations + seed.sql)..."
supabase db reset

echo "==> Running pgTAP database tests..."
supabase test db

echo "==> Running Flutter integration tests (real local Supabase)..."
flutter test test/integration

echo "==> Running Flutter E2E tests (roles × screens + feature flows)..."
flutter test test/e2e --concurrency=1

echo "==> All Supabase tests passed."
