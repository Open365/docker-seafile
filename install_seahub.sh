#!/bin/bash
set -e
set -x
set -o pipefail

# These are required for pillow and specially zlib needs to be in /usr/lib
# because that's where the python setup script looks
# without this seahub will not have thumbnails!
apk add --no-cache zlib-dev jpeg-dev
cp /lib/libz.* /usr/lib/

apk add --no-cache bash \
	 py-dateutil py-mako py-simplejson py-pillow py-pip py-six python-dev \
	 python py-django1.5 py-gunicorn py-chardet py-django-djblets \
	 py-django-simple-captcha py-django-registration py-flup py-mysqldb gettext

SEAFILE_HOME='/var/lib/seafile'
SEAFILE_DIR="$SEAFILE_HOME/scripts"
SEAHUB_DIR="$SEAFILE_DIR/seahub"

# Use open365's seahub from github
git clone --depth 1 --branch open365 https://github.com/Open365/seahub.git "$SEAHUB_DIR"

cd $SEAHUB_DIR
rm -rf .git

echo python-memcached >> requirements.txt
pip install -r requirements.txt

mkdir -m 755 -p $SEAFILE_HOME/seafile-server
ln -s $SEAFILE_DIR/seahub $SEAFILE_HOME/seafile-server
ln -s $SEAFILE_DIR/seahub /var/lib/seahub

mkdir -m 755 $SEAFILE_HOME/scripts/seafile
mkdir -m 755 $SEAFILE_HOME/scripts/runtime
cp $SEAFILE_HOME/scripts/seahub.conf $SEAFILE_HOME/scripts/runtime/seahub.conf

# compile and minify seahub (translations and js).
(
	cd "$SEAHUB_DIR"
	mkdir -p ${SEAFILE_HOME}/conf
	cat <<-END >> ${SEAFILE_HOME}/conf/ccnet.conf
	[General]
	ID = id-does-not-matter
	SERVICE_URL = https://this-does-not-matter/
	END

	npm install --global requirejs
	export PYTHONPATH=$PWD/thirdpart:$PWD
	export PATH=$PATH:thirdpart/Django-1.5.12-py2.6.egg/django/bin
	./build.sh
	npm uninstall --global requirejs

	rm -rf ${SEAFILE_HOME}/conf
)

apk del python-dev gettext gettext-dev glib-dev libsearpc-dev ccnet-dev seafile-dev
