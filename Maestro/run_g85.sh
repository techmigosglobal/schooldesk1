#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PRINCIPAL_USERNAME="${PRINCIPAL_USERNAME:-principal}"
export PRINCIPAL_PASSWORD="${PRINCIPAL_PASSWORD:-Principal@12345}"
export TEACHER_USERNAME="${TEACHER_USERNAME:-teacher01}"
export TEACHER_PASSWORD="${TEACHER_PASSWORD:-Teacher@12345}"

if [[ -z "${ANDROID_SERIAL:-}" ]]; then
  ANDROID_SERIAL="$(adb devices -l | awk '/moto_g85_5G|model:moto_g85_5G|device:malmo/ {print $1; exit}')"
  export ANDROID_SERIAL
fi

if [[ -z "${ANDROID_SERIAL:-}" ]]; then
  echo "No Moto G85 wireless ADB device found. Run: adb devices -l" >&2
  exit 1
fi

echo "Running Maestro suite on ${ANDROID_SERIAL}"

maestro_args=(
  test
  --device "${ANDROID_SERIAL}"
  -e "PRINCIPAL_USERNAME=${PRINCIPAL_USERNAME}"
  -e "PRINCIPAL_PASSWORD=${PRINCIPAL_PASSWORD}"
  -e "TEACHER_USERNAME=${TEACHER_USERNAME}"
  -e "TEACHER_PASSWORD=${TEACHER_PASSWORD}"
)

if [[ -n "${MAESTRO_FORMAT:-}" ]]; then
  maestro_args+=(--format "${MAESTRO_FORMAT}")
fi

if [[ -n "${MAESTRO_OUTPUT:-}" ]]; then
  maestro_args+=(--output "${MAESTRO_OUTPUT}")
fi

maestro "${maestro_args[@]}" "${ROOT_DIR}/Maestro/config.yaml"
