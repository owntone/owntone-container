#!/bin/sh -e

cleanup() {
    echo "Caught SIGTERM, stopping processes..."
    kill -TERM "$@" 2>/dev/null || true
    wait "$@" 2>/dev/null || true
    exit 0
}

ensureuser() {
  if ! getent passwd "$1" >/dev/null 2>&1; then
    sed "/^owntone:/s/1000/$1/g" /etc/passwd > /tmp/passwd
    export NSS_WRAPPER_PASSWD=/tmp/passwd
    export NSS_WRAPPER_GROUP=/etc/group
    export LD_PRELOAD=/usr/lib/libnss_wrapper.so
  fi
}    
 
ensureuser $(id -u)
mkdir -p -m 700 /run/dbus

/usr/bin/dbus-daemon --config-file=/etc/dbus-1/dbus-local.conf --nofork &
PID_DBUS=$!

while [ ! -S /run/dbus/system_bus_socket ]; do
   sleep 5
   echo Waiting for dbus...
done
 
/usr/sbin/avahi-daemon --no-drop-root &
PID_AVAHI=$!

/usr/sbin/owntone -P /run/owntone.pid -d ${LOG_LEVEL}
PID_OWNTONE=$(cat /run/owntone.pid)

trap "cleanup $PID_OWNTONE $PID_AVAHI $PID_DBUS" TERM INT

while kill -0 $PID_DBUS 2>/dev/null && \
      kill -0 $PID_AVAHI 2>/dev/null && \
      kill -0 $PID_OWNTONE 2>/dev/null;  do
    sleep 1
done

cleanup $PID_OWNTONE $PID_AVAHI $PID_DBUS
exit 1
