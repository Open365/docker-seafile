#!/bin/bash
set -e
set -x
set -o pipefail

SEAFILE_DIR='/var/lib/seafile/scripts'
SEAHUB_DIR="$SEAFILE_DIR/seahub"

/var/service/install_seahub.sh

# This is a temporary patch. We use this for allow remote connections of mysql.
# see https://github.com/shoeper-forks/seafile/commit/36face2972813e2d9e4e0c0115e1ae6aa98321e7
# this patch is official but not present in v5.0.5 (and v5.0.6 hasn't come out yet)
patch -p2 -d "$SEAFILE_DIR" -i /opt/patches/seafile/mysql_remote_host.patch

# when choosing 'use existing db' in setup it tries to re-create the seahub db
# see https://github.com/haiwen/seafile/pull/1556
patch -p2 -d "$SEAFILE_DIR" -i /opt/patches/seafile/use_existing_db.patch

# Use seafdav from github
cd /opt/
git clone https://github.com/Open365/seafdav.git --depth 1 --branch open365
rm -rf /usr/share/seafdav
cp -rf /opt/seafdav/ /usr/share/seafdav/
rm -rf /opt/seafdav
