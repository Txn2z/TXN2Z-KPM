#!/bin/sh

MODDIR=${0%/*}
KPNDIR="/data/adb/txn2z-kpm"
PATH="$MODDIR/bin:$PATH"
CONFIG="$KPNDIR/package_config"
REHOOK="$(cat $KPNDIR/rehook 2>/dev/null)"

if [ -z "$(kpatch hello)" ]; then
    touch "$MODDIR/unresolved"
    exit 0
fi

for kpm in $KPNDIR/kpm/*.kpm; do
    [ -s "$kpm" ] || continue
    kpatch kpm load "$kpm" || rm -f "$kpm"
done

if [ -n "$REHOOK" ]; then
    if [ "$REHOOK" = "enable" ] || [ "$REHOOK" = "disable" ]; then
        kpatch rehook $REHOOK
    else
        rm -f "$KPNDIR/rehook"
    fi
fi

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

[ -f "$CONFIG" ] || exit 0

tail -n +2 "$CONFIG" | while IFS=, read -r pkg exclude allow uid; do
    if [ "$exclude" = "1" ]; then
        APP_UID=$(grep "^$pkg $uid" /data/system/packages.list | cut -d' ' -f2)
        [ -z "$APP_UID" ] && APP_UID=$(grep "^$pkg " /data/system/packages.list | cut -d' ' -f2)
        [ -n "$APP_UID" ] && kpatch exclude_set "$APP_UID" 1
    fi
done
