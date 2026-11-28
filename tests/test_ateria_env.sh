#!/bin/sh
# Tests the GPU/EGL selection in configs/niri/ateria/ateria-env.sh against
# synthetic DRM and GLVND trees. Run from anywhere:
#   sh tests/test_ateria_env.sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
helper="$root/configs/niri/ateria/ateria-env.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

passed=0
failed=0

fail() {
    printf 'not ok - %s\n' "$1"
    failed=$((failed + 1))
}

check() {
    description=$1
    actual=$2
    expected=$3
    if [ "$actual" = "$expected" ]; then
        printf 'ok - %s\n' "$description"
        passed=$((passed + 1))
    else
        printf 'not ok - %s\n  expected: %s\n  actual:   %s\n' \
            "$description" "$expected" "$actual"
        failed=$((failed + 1))
    fi
}

get_var() {
    printf '%s\n' "$1" | sed -n "s/^$2=//p"
}

make_driver() {
    mkdir -p "$tmp/drivers/$1"
}

make_card() {
    drm=$1
    card=$2
    driver=$3
    boot_vga=$4
    make_driver "$driver"
    mkdir -p "$drm/$card/device"
    ln -s "$tmp/drivers/$driver" "$drm/$card/device/driver"
    if [ -n "$boot_vga" ]; then
        printf '%s\n' "$boot_vga" > "$drm/$card/device/boot_vga"
    fi
}

make_render_node() {
    drm=$1
    node=$2
    driver=$3
    make_driver "$driver"
    mkdir -p "$drm/$node/device"
    ln -s "$tmp/drivers/$driver" "$drm/$node/device/driver"
}

run_env() {
    drm=$1
    vendors=$2
    shift 2
    env -i PATH="$PATH" HOME="$tmp/home" \
        ATERIA_DRM_DIR="$drm" \
        ATERIA_EGL_VENDOR_DIRS="$vendors" \
        "$@" sh -eu -c '. "$1"; env' sh "$helper"
}

# AMD boot VGA: Mesa is the compositor renderer, NVIDIA is only installed.
case_dir="$tmp/amd"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 amdgpu 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "AMD boot GPU selects Mesa" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/50_mesa.json"
check "AMD marks the restriction as applied" \
    "$(get_var "$out" ATERIA_EGL_VENDOR_APPLIED)" "1"
check "AMD enables VAAPI" \
    "$(get_var "$out" QT_FFMPEG_DECODING_HW_DEVICE_TYPES)" "vaapi"
check "jemalloc arena limit is applied" \
    "$(get_var "$out" MALLOC_CONF | cut -d, -f1)" "narenas:2"
check "jemalloc restriction is marked as applied" \
    "$(get_var "$out" ATERIA_MALLOC_CONF_APPLIED)" "1"

# Intel boot VGA uses the same Mesa ICD.
case_dir="$tmp/intel"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 i915 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "Intel boot GPU selects Mesa" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/50_mesa.json"
check "Intel enables VAAPI" \
    "$(get_var "$out" QT_FFMPEG_DECODING_HW_DEVICE_TYPES)" "vaapi"

# NVIDIA boot VGA must not be forced onto Mesa, and must not enable VAAPI.
case_dir="$tmp/nvidia"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 nvidia 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "NVIDIA boot GPU selects the NVIDIA ICD" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/10_nvidia.json"
check "NVIDIA does not enable VAAPI" \
    "$(get_var "$out" QT_FFMPEG_DECODING_HW_DEVICE_TYPES)" ""

# nouveau is a Mesa driver.
case_dir="$tmp/nouveau"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 nouveau 1
: > "$case_dir/vendor/50_mesa.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "nouveau selects Mesa" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/50_mesa.json"

# boot_vga=0 must be ignored in favor of the card that is actually boot VGA.
case_dir="$tmp/two-cards"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 nvidia 0
make_card "$case_dir/drm" card1 amdgpu 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "boot_vga=1 wins over a lower-numbered card" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/50_mesa.json"

# No boot_vga (VMs/containers): fall back to the first render node.
case_dir="$tmp/render-fallback"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 amdgpu ""
make_render_node "$case_dir/drm" renderD128 amdgpu
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "missing boot_vga falls back to the first render node" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/50_mesa.json"

# Unsupported platform: leave the default behavior alone.
case_dir="$tmp/unsupported"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 virtio_gpu 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "unsupported driver leaves EGL unset" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" ""
check "unsupported driver does not mark the restriction applied" \
    "$(get_var "$out" ATERIA_EGL_VENDOR_APPLIED)" ""

# The selected driver has no matching ICD: do not point EGL at a missing file.
case_dir="$tmp/missing-icd"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 amdgpu 1
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "missing Mesa ICD leaves EGL unset" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" ""
check "missing Mesa ICD does not mark the restriction applied" \
    "$(get_var "$out" ATERIA_EGL_VENDOR_APPLIED)" ""

# AMDGPU-PRO ships its own vendor file; prefer it over Mesa when present.
case_dir="$tmp/amdgpu-pro"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 amdgpu 1
: > "$case_dir/vendor/10_amdgpu-pro.json"
: > "$case_dir/vendor/50_mesa.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor")
check "AMDGPU-PRO vendor file is preferred" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/10_amdgpu-pro.json"

# Explicit user settings win.
case_dir="$tmp/override"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 amdgpu 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor" \
    __EGL_VENDOR_LIBRARY_FILENAMES=/custom/vendor.json)
check "an existing EGL vendor list is preserved" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "/custom/vendor.json"
check "an existing EGL vendor list does not mark the restriction applied" \
    "$(get_var "$out" ATERIA_EGL_VENDOR_APPLIED)" ""

out=$(run_env "$case_dir/drm" "$case_dir/vendor" \
    __EGL_VENDOR_LIBRARY_DIRS=/custom/dir)
check "an existing EGL vendor directory list is preserved" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" ""
check "an existing EGL vendor directory list does not mark the restriction applied" \
    "$(get_var "$out" ATERIA_EGL_VENDOR_APPLIED)" ""

case_dir="$tmp/forced-nvidia"
mkdir -p "$case_dir/vendor"
make_card "$case_dir/drm" card0 amdgpu 1
: > "$case_dir/vendor/50_mesa.json"
: > "$case_dir/vendor/10_nvidia.json"
out=$(run_env "$case_dir/drm" "$case_dir/vendor" ATERIA_EGL_VENDOR=nvidia)
check "ATERIA_EGL_VENDOR=nvidia overrides detection" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" "$case_dir/vendor/10_nvidia.json"

out=$(run_env "$case_dir/drm" "$case_dir/vendor" ATERIA_EGL_VENDOR=none)
check "ATERIA_EGL_VENDOR=none disables the optimization" \
    "$(get_var "$out" __EGL_VENDOR_LIBRARY_FILENAMES)" ""
check "ATERIA_EGL_VENDOR=none does not mark the restriction applied" \
    "$(get_var "$out" ATERIA_EGL_VENDOR_APPLIED)" ""

# A caller-provided MALLOC_CONF must be preserved.
out=$(run_env "$case_dir/drm" "$case_dir/vendor" MALLOC_CONF=custom)
check "an existing MALLOC_CONF is preserved" \
    "$(get_var "$out" MALLOC_CONF)" "custom"
check "an existing MALLOC_CONF is not marked as applied" \
    "$(get_var "$out" ATERIA_MALLOC_CONF_APPLIED)" ""

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
