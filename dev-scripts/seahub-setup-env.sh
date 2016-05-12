#!/bin/bash

cd /etc/service/seahub
sed -i 's/\/opt/#\/opt/' run

PYTHON_PROCESS=`pgrep -f 'python2.7 /opt' | head -n 1`
. <(xargs -0 bash -c 'printf "export %q\n" "$@"' -- < /proc/$PYTHON_PROCESS/environ)  

PID=`pgrep -f "runsv seahub"`
kill $PID
