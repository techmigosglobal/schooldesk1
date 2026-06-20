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

echo "Running Maestro on ${ANDROID_SERIAL}"

flows=(
  "Maestro/login_principal.yaml"
  "Maestro/create_teacher.yaml"
  "Maestro/principal_teacher_navigation.yaml"
  "Maestro/teacher_attendance_marking.yaml"
  "Maestro/teacher_principal_attendance_correction.yaml"
  "Maestro/teacher_principal_content_handoffs.yaml"
  "Maestro/teacher_leave_principal_approval.yaml"
  "Maestro/teacher_principal_communication.yaml"
)

for flow in "${flows[@]}"; do
  echo "==> ${flow}"
  maestro test \
    --device "${ANDROID_SERIAL}" \
    -e "PRINCIPAL_USERNAME=${PRINCIPAL_USERNAME}" \
    -e "PRINCIPAL_PASSWORD=${PRINCIPAL_PASSWORD}" \
    -e "TEACHER_USERNAME=${TEACHER_USERNAME}" \
    -e "TEACHER_PASSWORD=${TEACHER_PASSWORD}" \
    "${ROOT_DIR}/${flow}"
done
