Docker Seafile
==============

## Overview

## How to use it

** Build **

docker build -t docker-registry.eyeosbcn.com/docker-seafile .

** Enable extra logging **

Run the container passing the envar `ENABLE_DJANGO_DEBUG=1`. If you are using
eyeos-cli you can set `seafile.enable_django_debug = 1` in settings.cfg. With
that you'll have some extra logs in `/opt/seafile/logs/django.log`

## Quick help