#!/bin/bash

/var/lib/seafile/scripts/seahub.sh stop

PID=`ps | grep python | grep manage.py | awk '{ print $1 }'`
kill $PID

/var/lib/seahub/manage.py runserver 0.0.0.0:8000
