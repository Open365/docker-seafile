#!/bin/sh

cd /src/seafile
cd seafile

make CFLAGS="$CFLAGS $(pkgconf --cflags evhtp)"
make DESTDIR="/" install
