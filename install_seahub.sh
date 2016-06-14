#!/bin/bash
set -e
set -x
set -o pipefail

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
	USER_NAME = open365_files
	ID = bf8eec45344c4c37970e5ba6152fdc43e520d0e9
	NAME = open365_files
	SERVICE_URL = https://192.168.5.151/sync
	END

	npm install --global requirejs
	export PYTHONPATH=$PWD/thirdpart:$PWD
	export PATH=$PATH:thirdpart/Django-1.5.12-py2.6.egg/django/bin
	make dist
	npm uninstall --global requirejs

	rm -rf ${SEAFILE_HOME}/conf
)

apk del python-dev gettext gettext-dev glib-dev libsearpc-dev ccnet-dev seafile-dev
