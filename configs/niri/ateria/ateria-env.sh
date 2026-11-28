#!/bin/sh
# Runtime environment tuning shared by the Niri startup command and
# tools/ateria-shell. This file is sourced by a POSIX shell and must not exec
# anything or depend on the caller's working directory.

# Quickshell is linked against jemalloc. Its default per-thread arenas retain a
# surprising amount of freed memory over a long-lived session, and the shell
# creates hundreds of short-lived QML objects whenever a panel opens or closes.
# Two arenas plus prompt decay keeps RSS substantially lower without affecting
# the shell's modest allocation rate. Respect an explicit user setting.
if [ -z "${MALLOC_CONF:-}" ]; then
    export MALLOC_CONF="narenas:2,background_thread:true,dirty_decay_ms:1000,muzzy_decay_ms:1000"
    # Consumed by the launcher so this shell-specific tuning is not inherited by
    # unrelated applications that happen to use jemalloc.
    export ATERIA_MALLOC_CONF_APPLIED=1
fi

# Test hooks for the environment around the GPU detection.
# ATERIA_DRM_DIR points at a fake sysfs tree; ATERIA_EGL_VENDOR_DIRS is a
# colon-separated list of fake GLVND vendor directories.
ateria_drm_dir=${ATERIA_DRM_DIR:-/sys/class/drm}

ateria_egl_vendor_dirs() {
    if [ -n "${ATERIA_EGL_VENDOR_DIRS:-}" ]; then
        printf '%s\n' "$ATERIA_EGL_VENDOR_DIRS" | tr ':' '\n'
        return 0
    fi
    printf '%s\n' \
        /usr/share/glvnd/egl_vendor.d \
        /usr/local/share/glvnd/egl_vendor.d \
        /etc/glvnd/egl_vendor.d \
        /run/opengl-driver/share/glvnd/egl_vendor.d
}

ateria_gpu_driver() {
    # Smithay, and therefore Niri, prefers the boot VGA device. Fall back to
    # the first render node when boot VGA is unavailable (VMs, containers).
    ateria_driver=""
    for ateria_card in "$ateria_drm_dir"/card[0-9]*; do
        [ -e "$ateria_card/device/boot_vga" ] || continue
        [ "$(cat "$ateria_card/device/boot_vga" 2>/dev/null)" = "1" ] || continue
        ateria_driver=$(readlink -f "$ateria_card/device/driver" 2>/dev/null) || ateria_driver=""
        break
    done
    if [ -z "$ateria_driver" ]; then
        for ateria_node in "$ateria_drm_dir"/renderD*/device/driver; do
            [ -e "$ateria_node" ] || continue
            ateria_driver=$(readlink -f "$ateria_node" 2>/dev/null) || ateria_driver=""
            break
        done
    fi
    printf '%s\n' "${ateria_driver##*/}"
}

ateria_find_egl_vendor() {
    ateria_family=$1
    for ateria_dir in $(ateria_egl_vendor_dirs); do
        [ -d "$ateria_dir" ] || continue
        case "$ateria_family" in
            nvidia)
                for ateria_file in "$ateria_dir/10_nvidia.json" "$ateria_dir"/*nvidia*.json; do
                    [ -e "$ateria_file" ] && { printf '%s\n' "$ateria_file"; return 0; }
                done
                ;;
            amd)
                for ateria_file in "$ateria_dir"/*amdgpu*.json "$ateria_dir/50_mesa.json" "$ateria_dir"/*mesa*.json; do
                    [ -e "$ateria_file" ] && { printf '%s\n' "$ateria_file"; return 0; }
                done
                ;;
            intel|mesa)
                for ateria_file in "$ateria_dir/50_mesa.json" "$ateria_dir"/*mesa*.json "$ateria_dir"/*intel*.json; do
                    [ -e "$ateria_file" ] && { printf '%s\n' "$ateria_file"; return 0; }
                done
                ;;
        esac
    done
    return 1
}

ateria_driver=$(ateria_gpu_driver)

# Prefer the low-power VAAPI path on Intel and AMD render nodes. Qt falls back
# to its normal backend on systems where one is not present.
case "$ateria_driver" in
    amdgpu|i915|xe)
        export QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
        export QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi
        ;;
esac

# Force GLVND to load only the EGL driver for the GPU the compositor renders
# with. On hybrid systems Qt otherwise initializes every installed vendor,
# including the dGPU that never draws this shell; that alone costs about 100 MB
# of resident memory. Respect an explicit user setting.
#
# The launcher clears the restriction for applications it starts, so this does
# not leak into the user's session. If the platform does not match a known
# driver, or the expected GLVND file is missing, nothing is changed and the
# system keeps its default multi-vendor behavior.
if [ -z "${__EGL_VENDOR_LIBRARY_FILENAMES:-}" ] \
        && [ -z "${__EGL_VENDOR_LIBRARY_DIRS:-}" ] \
        && [ "${ATERIA_EGL_VENDOR:-auto}" != "none" ]; then
    ateria_family=""
    case "${ATERIA_EGL_VENDOR:-auto}" in
        mesa) ateria_family=mesa ;;
        nvidia) ateria_family=nvidia ;;
        *)
            case "$ateria_driver" in
                nvidia*) ateria_family=nvidia ;;
                amdgpu|radeon) ateria_family=amd ;;
                i915|xe) ateria_family=intel ;;
                nouveau) ateria_family=mesa ;;
            esac
            ;;
    esac

    if [ -n "$ateria_family" ] && ateria_vendor=$(ateria_find_egl_vendor "$ateria_family"); then
        export __EGL_VENDOR_LIBRARY_FILENAMES="$ateria_vendor"
        # Consumed by the launcher so this restriction is not inherited by
        # applications it starts.
        export ATERIA_EGL_VENDOR_APPLIED=1
    fi
fi
