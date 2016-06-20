#!/bin/sh

cd /var/lib/seafile/scripts
./seahub.sh stop

cd seahub

# FIXME: Change logging in settings
python manage.py runserver 0.0.0.0:8000
