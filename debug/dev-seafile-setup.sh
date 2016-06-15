#!/bin/sh

apk update
apk add autoconf automake bash curl-dev glib-dev \
        intltool jansson-dev libarchive-dev libevent-dev libevhtp-dev \
        libtool libzdb-dev openssl-dev sqlite-dev util-linux-dev \
        vala bsd-compat-headers libevhtp-dev git build-base vim

BASE_URL="https://s3-eu-west-1.amazonaws.com/apk-packages"
wget \
	${BASE_URL}/ccnet-dev-5.0.5-r0.apk \
    ${BASE_URL}/libsearpc-dev-3.0.7-r0.apk

apk add --allow-untrusted *.apk
rm *.apk

mkdir -p /src
cd /src

if [[ ! -d /src/seafile ]]; then
    mkdir -p /src/seafile
    git clone https://github.com/open365/seafile.git
fi

cd seafile

./autogen.sh
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --mandir=/usr/share/man \
    --infodir=/usr/share/info \
    --enable-server \
    --enable-python \
    --disable-fuse \
    --disable-client \
    --disable-console

make CFLAGS="$CFLAGS $(pkgconf --cflags evhtp)"
make DESTDIR="/" install
