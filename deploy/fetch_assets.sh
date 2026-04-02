#!/usr/bin/env bash
set -euo pipefail

# Fetch non-git-tracked model + dataset artifacts into the public repo so local
# runtime image builds can bake them in.
#
# Runtime Dockerfiles copy from deploy/models and deploy/data. Keep those
# directories as the canonical pre-build staging paths regardless of where the
# source archives live.
#
# Inputs (set via env):
# - GBX_ASSETS_MODELS_URI   : gs://.../models.tar.gz OR https://.../models.zip
# - GBX_ASSETS_DATA_URI     : gs://.../data.tar.gz OR https://.../data.zip
# - GBX_ASSETS_PRIMEKG_URI  : optional gs://.../kg.csv.gz OR primekg tarball
# - GBX_ASSETS_FORCE        : set to 1 to overwrite existing local assets
#
# Example:
#   export GBX_ASSETS_MODELS_URI="gs://glassbox-bio-molecular-data/models.zip"
#   export GBX_ASSETS_DATA_URI="gs://glassbox-bio-molecular-data/data.zip"
#   ./deploy/fetch_assets.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_MODELS_URI="gs://glassbox-bio-molecular-data/models.zip"
DEFAULT_DATA_URI="gs://glassbox-bio-molecular-data/data.zip"

MODELS_URI="${GBX_ASSETS_MODELS_URI:-$DEFAULT_MODELS_URI}"
DATA_URI="${GBX_ASSETS_DATA_URI:-$DEFAULT_DATA_URI}"
PRIMEKG_URI="${GBX_ASSETS_PRIMEKG_URI:-}"
FORCE="${GBX_ASSETS_FORCE:-0}"

if [[ -z "$MODELS_URI" && -z "$DATA_URI" && -z "$PRIMEKG_URI" ]]; then
  cat <<'EOF' 1>&2
Missing inputs.

Set at least one of:
  - GBX_ASSETS_MODELS_URI
  - GBX_ASSETS_DATA_URI
  - GBX_ASSETS_PRIMEKG_URI

Example:
  export GBX_ASSETS_MODELS_URI="gs://glassbox-bio-molecular-data/models.zip"
  export GBX_ASSETS_DATA_URI="gs://glassbox-bio-molecular-data/data.zip"
  ./deploy/fetch_assets.sh
EOF
  exit 2
fi

need_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required executable: $1" 1>&2
    exit 3
  fi
}

need_bin tar
need_bin gzip
need_bin unzip
need_bin curl

gcs_cp() {
  local src="$1"
  local dst="$2"
  if command -v gcloud >/dev/null 2>&1; then
    gcloud storage cp "$src" "$dst"
    return 0
  fi
  if command -v gsutil >/dev/null 2>&1; then
    gsutil cp "$src" "$dst"
    return 0
  fi
  echo "Missing required executable: gcloud (preferred) or gsutil" 1>&2
  exit 3
}

http_get() {
  local src="$1"
  local dst="$2"
  curl -fsSL "$src" -o "$dst"
}

fetch_to_file() {
  local src="$1"
  local dst="$2"
  if [[ "$src" == gs://* ]]; then
    gcs_cp "$src" "$dst" >/dev/null
    return 0
  fi
  if [[ "$src" == http://* || "$src" == https://* ]]; then
    http_get "$src" "$dst"
    return 0
  fi
  echo "[fetch_assets] unsupported URI scheme (expected gs:// or http(s)://): $src" 1>&2
  exit 3
}

MODELS_DIR="$ROOT_DIR/deploy/models"
DATA_DIR="$ROOT_DIR/deploy/data"
PRIMEKG_DIR="$DATA_DIR/primekg"

mkdir -p "$MODELS_DIR" "$PRIMEKG_DIR"

is_dir_nonempty() {
  local d="$1"
  [[ -d "$d" ]] && find "$d" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
}

safe_rm_contents() {
  local d="$1"
  rm -rf "$d"/*
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fetch_models() {
  local uri="$1"
  echo "[fetch_assets] fetching models: $uri"

  if is_dir_nonempty "$MODELS_DIR" && [[ "$FORCE" != "1" ]]; then
    echo "[fetch_assets] models/ already populated; set GBX_ASSETS_FORCE=1 to overwrite"
    return 0
  fi

  local extract_dir="$TMP_DIR/models_extract"
  mkdir -p "$extract_dir"

  local name
  name="$(basename "$uri")"
  if [[ "$name" == *.zip ]]; then
    local archive="$TMP_DIR/models.zip"
    fetch_to_file "$uri" "$archive"
    unzip -q "$archive" -d "$extract_dir"
  elif [[ "$name" == *.tar.gz || "$name" == *.tgz ]]; then
    local archive="$TMP_DIR/models.tgz"
    fetch_to_file "$uri" "$archive"
    tar -xzf "$archive" -C "$extract_dir"
  else
    echo "[fetch_assets] unsupported models artifact (expect .zip or .tar.gz/.tgz): $uri" 1>&2
    exit 4
  fi

  if [[ "$FORCE" == "1" ]]; then
    safe_rm_contents "$MODELS_DIR"
  fi

  if [[ -d "$extract_dir/models" ]]; then
    cp -R "$extract_dir/models/." "$MODELS_DIR/"
  else
    cp -R "$extract_dir/." "$MODELS_DIR/"
  fi

  echo "[fetch_assets] models fetched into: $MODELS_DIR"
}

fetch_data_bundle() {
  local uri="$1"
  echo "[fetch_assets] fetching data bundle: $uri"

  if is_dir_nonempty "$DATA_DIR" && [[ "$FORCE" != "1" ]]; then
    local real_count
    real_count="$(find "$DATA_DIR" -type f ! -name '.gitkeep' ! -name 'README.md' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$real_count" != "0" ]]; then
      echo "[fetch_assets] data/ already populated; set GBX_ASSETS_FORCE=1 to overwrite"
      return 0
    fi
  fi

  local extract_dir="$TMP_DIR/data_extract"
  mkdir -p "$extract_dir"

  local name
  name="$(basename "$uri")"
  if [[ "$name" == *.zip ]]; then
    local archive="$TMP_DIR/data.zip"
    fetch_to_file "$uri" "$archive"
    unzip -q "$archive" -d "$extract_dir"
  elif [[ "$name" == *.tar.gz || "$name" == *.tgz ]]; then
    local archive="$TMP_DIR/data.tgz"
    fetch_to_file "$uri" "$archive"
    tar -xzf "$archive" -C "$extract_dir"
  else
    echo "[fetch_assets] unsupported data artifact (expect .zip or .tar.gz/.tgz): $uri" 1>&2
    exit 4
  fi

  if [[ "$FORCE" == "1" ]]; then
    find "$DATA_DIR" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' ! -name 'README.md' -exec rm -rf {} + 2>/dev/null || true
    rm -rf "$PRIMEKG_DIR" 2>/dev/null || true
    mkdir -p "$PRIMEKG_DIR"
  fi

  if [[ -d "$extract_dir/data" ]]; then
    cp -R "$extract_dir/data/." "$DATA_DIR/"
  else
    cp -R "$extract_dir/." "$DATA_DIR/"
  fi

  echo "[fetch_assets] data fetched into: $DATA_DIR"
}

fetch_primekg() {
  local uri="$1"
  echo "[fetch_assets] fetching primekg: $uri"

  if [[ -f "$PRIMEKG_DIR/kg.csv" && "$FORCE" != "1" ]]; then
    echo "[fetch_assets] data/primekg/kg.csv already exists; set GBX_ASSETS_FORCE=1 to overwrite"
    return 0
  fi

  local name
  name="$(basename "$uri")"

  if [[ "$name" == *.csv.gz ]]; then
    local archive="$TMP_DIR/kg.csv.gz"
    mkdir -p "$PRIMEKG_DIR"
    fetch_to_file "$uri" "$archive"
    gzip -dc "$archive" > "$PRIMEKG_DIR/kg.csv"
  elif [[ "$name" == *.csv ]]; then
    mkdir -p "$PRIMEKG_DIR"
    fetch_to_file "$uri" "$PRIMEKG_DIR/kg.csv"
  elif [[ "$name" == *.tar.gz || "$name" == *.tgz ]]; then
    local archive="$TMP_DIR/primekg.tgz"
    local extract_dir="$TMP_DIR/primekg_extract"
    mkdir -p "$extract_dir" "$PRIMEKG_DIR"
    fetch_to_file "$uri" "$archive"
    tar -xzf "$archive" -C "$extract_dir"
    if [[ -f "$extract_dir/kg.csv" ]]; then
      cp "$extract_dir/kg.csv" "$PRIMEKG_DIR/kg.csv"
    elif [[ -f "$extract_dir/primekg/kg.csv" ]]; then
      cp "$extract_dir/primekg/kg.csv" "$PRIMEKG_DIR/kg.csv"
    else
      echo "[fetch_assets] primekg tarball did not contain kg.csv" 1>&2
      exit 4
    fi
  else
    echo "[fetch_assets] unsupported primekg artifact (expect .csv, .csv.gz or .tar.gz/.tgz): $uri" 1>&2
    exit 4
  fi

  echo "[fetch_assets] primekg fetched into: $PRIMEKG_DIR/kg.csv"
}

if [[ -n "$MODELS_URI" ]]; then
  fetch_models "$MODELS_URI"
fi

if [[ -n "$DATA_URI" ]]; then
  fetch_data_bundle "$DATA_URI"
fi

if [[ -n "$PRIMEKG_URI" ]]; then
  fetch_primekg "$PRIMEKG_URI"
fi

echo "[fetch_assets] done"
