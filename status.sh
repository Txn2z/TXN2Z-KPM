#!/bin/sh

MODDIR="/data/adb/modules/Txn2z-KPM"
KPNDIR="/data/adb/txn2z-kpm"
PATH="$MODDIR/bin:$PATH"

PROP_FILE="$MODDIR/module.prop"
PROP_BAK="$PROP_FILE.bak"

set_prop() {
    local prop="$1"
    local value="$2"
    local file="$3"

    if ! grep -q "^$prop=" "$file"; then
        echo "$prop=$value" >> "$file"
        return
    fi
    sed "s/^$prop=.*/$prop=$value/" "$file" > "$file.tmp"
    cat "$file.tmp" > "$file"
    rm -f "$file.tmp"
}

restore_prop_if_needed() {
    grep -q "^id=" "$PROP_FILE" && return
    [ -f "$PROP_BAK" ] && cat "$PROP_BAK" > "$PROP_FILE"
}

if [ ! -d "$MODDIR" ]; then
    rm -f "$(realpath "$0")"
    exit 0
fi

active="[ACTIVE]"
inactive="[INACTIVE]"
info="Kernel not patched yet - open WebUI to patch"
string="$inactive $info"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

if [ -n "$(kpatch hello)" ]; then
    KPM_COUNT="$(kpatch kpm num 2>/dev/null || echo 0)"
    [ -z "$KPM_COUNT" ] && KPM_COUNT=0

    REHOOK_MODE="$(kpatch rehook_status 2>/dev/null | awk '{print $NF}')"
    [ -z "$REHOOK_MODE" ] && REHOOK_MODE="enabled"

    string="$active Kernel patched | KPM loaded: $KPM_COUNT | Rehook: $REHOOK_MODE"
fi

restore_prop_if_needed

set_prop "description" "$string" "$PROP_FILE"
