#!/bin/sh
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

export BASEDIR=<enter the snmp_exporter install location here>

case "$1" in
  start)
	$BASEDIR/snmp_exporter --config.file="$BASEDIR/snmp.yml" &
    ;;

  stop)
	killall -9 snmp_exporter
    ;;

  restart)
    $0 stop
    $0 start
    ;;

  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac

exit 0
