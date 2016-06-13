#!/bin/bash
set -e
set -x
set -o pipefail

SEAFILE_DIR='/var/lib/seafile/scripts'
SEAHUB_DIR="$SEAFILE_DIR/seahub"

cd /root/
BASE_URL="https://s3-eu-west-1.amazonaws.com/apk-packages"

wget \
	${BASE_URL}/ccnet-5.0.5-r0.apk \
	${BASE_URL}/ccnet-dev-5.0.5-r0.apk \
	${BASE_URL}/ccnet-libs-5.0.5-r0.apk \
	${BASE_URL}/libsearpc-3.0.7-r0.apk \
	${BASE_URL}/libsearpc-dev-3.0.7-r0.apk \
	${BASE_URL}/py-ccnet-5.0.5-r0.apk \
	${BASE_URL}/py-libsearpc-3.0.7-r0.apk \
	${BASE_URL}/py-seafile-5.0.5-r1.apk \
	${BASE_URL}/seafile-5.0.5-r1.apk \
	${BASE_URL}/seafile-common-5.0.5-r1.apk \
	${BASE_URL}/seafile-dev-5.0.5-r1.apk \
	${BASE_URL}/seafile-server-5.0.5-r1.apk \
	${BASE_URL}/seafobj-5.0.5-r1.apk

apk add --no-cache --allow-untrusted /root/*.apk
rm /root/*.apk

# This is a temporary patch. We use this for allow remote connections of mysql.
# see https://github.com/shoeper-forks/seafile/commit/36face2972813e2d9e4e0c0115e1ae6aa98321e7
# this patch is official but not present in v5.0.5 (and v5.0.6 hasn't come out yet)
patch -p2 -d "$SEAFILE_DIR" -i /opt/patches/seafile/mysql_remote_host.patch

# when choosing 'use existing db' in setup it tries to re-create the seahub db
# see https://github.com/haiwen/seafile/pull/1556
patch -p2 -d "$SEAFILE_DIR" -i /opt/patches/seafile/use_existing_db.patch

/var/service/install_seahub.sh
/var/service/install_seafdav.sh
