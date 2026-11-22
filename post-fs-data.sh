#!/system/bin/sh

MODDIR=${0%/*}
SERVICE_D="/data/adb/service.d"
STATUS_SH="$SERVICE_D/txn2z-kpm.sh"

mkdir -p "$SERVICE_D"
rm -f "$SERVICE_D/txn2zkpm.sh" "$SERVICE_D/kp-next.sh"
cp "$MODDIR/status.sh" "$STATUS_SH"
chmod 755 "$STATUS_SH"
