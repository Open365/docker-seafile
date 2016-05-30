#!/bin/bash
set -e
set -x
set -o pipefail

SEAFILE_DIR="/opt/seafile/seafile-server-${SEAFILE_VERSION}"
SEAHUB_DIR="$SEAFILE_DIR/seahub"

# backup original seahub's thirdpart folder, because the github clone doesn't
# have it (and we haven't investigate in how to build it)
mv "$SEAHUB_DIR/thirdpart" /tmp

# remove original seahub or we won't be able to clone ours there
rm -rf "$SEAHUB_DIR"

# Use open365's seahub from github
git clone --depth 1 --branch open365 https://github.com/Open365/seahub.git "$SEAHUB_DIR"

# put thirdpart folder inside our seahub
rm -rf "$SEAHUB_DIR/thirdpart"
mv /tmp/thirdpart "$SEAHUB_DIR/thirdpart"

# compile and minify seahub (translations and js). We cannot do 'make dist'
# when building the image because there are some steps that must be done after
# setting up seafile, because it depends on ccnet's config and some envars.
(
	cd "$SEAHUB_DIR"
	apt-get install -y gettext
	npm install --global requirejs
	export PYTHONPATH=$PWD/../seafile/lib64/python2.6/site-packages:$PWD/thirdpart:$PWD
	export PATH=$PATH:thirdpart/Django-1.5.12-py2.6.egg/django/bin
	make locale uglify
	apt-get autoremove -y gettext
)

# This is a temporary patch. We use this for allow remote connections of mysql.
# see https://github.com/shoeper-forks/seafile/commit/36face2972813e2d9e4e0c0115e1ae6aa98321e7
# this patch is official but not present in v5.0.5 (and v5.0.6 hasn't come out yet)
patch -p2 -d "$SEAFILE_DIR" -i /opt/patches/seafile/mysql_remote_host.patch

# when choosing 'use existing db' in setup it tries to re-create the seahub db
# see https://github.com/haiwen/seafile/pull/1556
patch -p2 -d "$SEAFILE_DIR" -i /opt/patches/seafile/use_existing_db.patch

    # Custom patches in seafdav
patch -d "$SEAHUB_DIR"/thirdpart/ -p1 -i /opt/patches/seafdav/0001-wsgiServer-Reduce-the-socket-poll-time.patch
patch -d "$SEAHUB_DIR"/thirdpart/ -p1 -i /opt/patches/seafdav/0002-Make-the-webdav-server-scale-better.patch
