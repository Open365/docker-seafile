#!/bin/bash

log=/var/log/seafile.log

function stop_server() {
  ps ax | grep run_gunicorn | awk '{ print $1 }' | xargs kill
}

trap stop_server SIGINT SIGTERM

echo "****** STARTING SEAHUB ******"

/opt/seafile/seafile-server-latest/seahub.sh start # >> $log 2>&1

# Script should not exit unless seahub died
while pgrep -f "manage.py runfcgi" 2>&1 >/dev/null
do
	sleep 5;
done

echo "** SEAHUB has died. exiting..."

exit 0
