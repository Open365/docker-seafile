#!/bin/bash

IP=`ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
PORT=8000

cd /opt/seafile/seafile-server-latest/seahub/
python2.7 manage.py runserver $IP:$PORT
