#!/bin/sh

MODID="Txn2z-KPM"
MODDIR="/data/adb/modules/$MODID"
KPNDIR="/data/adb/txn2z-kpm"
OLD_KPNDIR="/data/adb/kp-next"

FAILS=0
WARNS=0

cd_sep()  { ui_print "=========================================="; }
cd_step() { ui_print ""; ui_print "[$1] $2"; sleep 0.2 2>/dev/null; }
cd_ok()   { ui_print "  [ OK ] $1: $2"; }
cd_info() { ui_print "  [ .. ] $1: $2"; }
cd_warn() { WARNS=$((WARNS + 1)); ui_print "  [WARN] $1: $2"; }
cd_fail() { FAILS=$((FAILS + 1)); ui_print "  [FAIL] $1: $2"; }

cd_exec_ok() {
    "$1" $2 </dev/null >/dev/null 2>&1
    case $? in
        126 | 127 | 132 | 139) return 1 ;;
    esac
    return 0
}

cd_links() {
    ln -sf kpatch-android "$1/kpatch"
    ln -sf kptools-android "$1/kptools"
    ln -sf kpimg-linux "$1/kpimg"
}

M_NAME="$(sed -n 's/^name=//p' "$MODPATH/module.prop" | head -n1)"
M_VER="$(sed -n 's/^version=//p' "$MODPATH/module.prop" | head -n1)"

ui_print ""
cd_sep
ui_print "   $M_NAME  $M_VER"
ui_print "   KernelPatch Module (KPM) for Magisk / KernelSU"
ui_print "   by Txn2zMinify"
cd_sep

cd_step "1/3" "Checking device compatibility"

if [ "$APATCH" ]; then
    cd_fail "Root" "APatch detected (conflicts, APatch already has built-in KPM)"
elif [ "$KSU" ]; then
    cd_ok "Root" "KernelSU ${KSU_VER:-?} (${KSU_VER_CODE:-?})"
elif [ "$MAGISK_VER_CODE" ]; then
    cd_ok "Root" "Magisk ${MAGISK_VER:-?} ($MAGISK_VER_CODE)"
else
    cd_warn "Root" "unknown root manager, continuing anyway"
fi

ABI="$(getprop ro.product.cpu.abi)"
[ -z "$ARCH" ] && [ "$(uname -m)" = "aarch64" ] && ARCH="arm64"
if [ "$ARCH" = "arm64" ]; then
    cd_ok "Arch" "arm64 (${ABI:-unknown})"
else
    cd_fail "Arch" "${ARCH:-unknown} / ${ABI:-unknown} (only arm64 is supported)"
fi

cd_info "Android" "$(getprop ro.build.version.release) (API ${API:-$(getprop ro.build.version.sdk)})"

KVER="$(uname -r)"
KMAJ="${KVER%%.*}"
KREST="${KVER#*.}"
KMIN="${KREST%%[!0-9]*}"
[ -z "$KMIN" ] && KMIN=0
case "$KMAJ" in
    '' | *[!0-9]*)
        cd_warn "Kernel" "$KVER (version could not be parsed)"
        ;;
    *)
        if [ "$KMAJ" -lt 3 ] || { [ "$KMAJ" -eq 3 ] && [ "$KMIN" -lt 18 ]; }; then
            cd_fail "Kernel" "$KVER (needs 3.18 or newer)"
        elif [ "$KMAJ" -gt 6 ] || { [ "$KMAJ" -eq 6 ] && [ "$KMIN" -gt 12 ]; }; then
            cd_warn "Kernel" "$KVER (newer than 6.12, not verified)"
        else
            cd_ok "Kernel" "$KVER"
        fi
        ;;
esac

KCFG="$(zcat /proc/config.gz 2>/dev/null || gzip -dc /proc/config.gz 2>/dev/null)"
if [ -n "$KCFG" ]; then
    if echo "$KCFG" | grep -q '^CONFIG_KALLSYMS=y'; then
        cd_ok "KALLSYMS" "enabled"
    else
        cd_fail "KALLSYMS" "CONFIG_KALLSYMS is not enabled in this kernel"
    fi
elif [ -e /proc/kallsyms ]; then
    cd_ok "KALLSYMS" "enabled"
else
    cd_fail "KALLSYMS" "/proc/kallsyms not found (kernel built without kallsyms)"
fi

if ls -d /dev/block/by-name/boot* /dev/block/by-name/init_boot* \
    /dev/block/bootdevice/by-name/boot* /dev/block/bootdevice/by-name/init_boot* \
    /dev/block/platform/*/by-name/boot* /dev/block/platform/*/*/by-name/boot* \
    >/dev/null 2>&1; then
    cd_ok "Boot" "boot partition found"
else
    cd_warn "Boot" "boot partition not detected, patching may need manual selection"
fi

set_perm_recursive "$MODPATH/bin" 0 2000 0755 0755
BIN_BAD=""
for b in kpatch-android kptools-android magiskboot; do
    case "$b" in
        kpatch-android | kptools-android) ARGV="-v" ;;
        *) ARGV="" ;;
    esac
    cd_exec_ok "$MODPATH/bin/$b" "$ARGV" || BIN_BAD="$BIN_BAD $b"
done
if [ -z "$BIN_BAD" ]; then
    cd_ok "Binaries" "kpatch, kptools, magiskboot run fine"
else
    cd_fail "Binaries" "cannot run on this device:$BIN_BAD"
fi

if command -v timeout >/dev/null 2>&1; then
    HELLO="$(timeout 5 "$MODPATH/bin/kpatch-android" hello 2>/dev/null)"
else
    HELLO="$("$MODPATH/bin/kpatch-android" hello 2>/dev/null)"
fi
if [ -n "$HELLO" ]; then
    cd_info "KernelPatch" "already active in the running kernel"
else
    cd_info "KernelPatch" "not patched yet (patch it from the WebUI)"
fi

ui_print ""
if [ "$FAILS" -gt 0 ]; then
    cd_sep
    ui_print "  Device is NOT supported ($FAILS problem(s))."
    ui_print "  Installation cancelled, nothing was changed."
    cd_sep
    abort "! Aborted"
fi
if [ "$WARNS" -gt 0 ]; then
    ui_print "  Compatible, with $WARNS warning(s). Continuing."
else
    ui_print "  All checks passed. Device is supported."
fi

cd_step "2/3" "Preparing files"

if [ -d "$OLD_KPNDIR" ] && [ ! -e "$KPNDIR" ]; then
    mv "$OLD_KPNDIR" "$KPNDIR" && cd_ok "Data" "migrated $OLD_KPNDIR -> $KPNDIR"
fi
rm -f /data/adb/service.d/kp-next.sh
mkdir -p "$KPNDIR"
cd_ok "Data" "$KPNDIR ready"

if [ -f "/data/adb/ap/package_config" ] && [ ! -f "$KPNDIR/package_config" ]; then
    cp "/data/adb/ap/package_config" "$KPNDIR/package_config"
    cd_ok "Config" "imported package_config from APatch"
fi

cp "$MODPATH/module.prop" "$MODPATH/module.prop.bak"

cd_links "$MODPATH/bin"
cd_ok "Binaries" "permissions and shortcuts set"

cd_step "3/3" "Finalizing"

if [ -d "$MODDIR" ]; then
    rm -rf "$MODDIR/webroot" "$MODDIR/bin" "$MODDIR/patch"
    cp -Lrf "$MODPATH/webroot" "$MODDIR/webroot"
    cp -Lrf "$MODPATH/bin" "$MODDIR/bin"
    cp -Lrf "$MODPATH/patch" "$MODDIR/patch"
    chmod -R 755 "$MODDIR/bin"
    cd_links "$MODDIR/bin"
    cd_ok "Update" "WebUI and binaries refreshed (no reboot needed for WebUI)"
else
    cd_ok "Install" "fresh install"
fi

ui_print ""
cd_sep
ui_print "  Done. Next steps:"
ui_print "   1. Reboot your device"
ui_print "   2. Open the WebUI (Action button)"
ui_print "   3. Patch your kernel, then reboot again"
cd_sep
ui_print ""
