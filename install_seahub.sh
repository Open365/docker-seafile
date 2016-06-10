#!/bin/bash
set -e
set -x
set -o pipefail

apk add --no-cache bash \
	 py-dateutil py-mako py-simplejson py-pillow py-pip py-virtualenv py-six python-dev \
	 python py-django1.5 py-gunicorn py-chardet py-django-djblets py-ccnet py-libsearpc \
	 py-django-simple-captcha py-django-registration py-flup py-seafile seafile-server py-mysqldb

SEAFILE_HOME='/var/lib/seafile'
SEAFILE_DIR="$SEAFILE_HOME/scripts"
SEAHUB_DIR="$SEAFILE_DIR/seahub"

# Use open365's seahub from github
git clone --depth 1 --branch open365 https://github.com/Open365/seahub.git "$SEAHUB_DIR"

cd $SEAHUB_DIR

echo python-memcached >> requirements.txt
pip install -r requirements.txt

mkdir -m 755 -p $SEAFILE_HOME/seafile-server
ln -s $SEAFILE_DIR/seahub $SEAFILE_HOME/seafile-server

mkdir -m 755 $SEAFILE_HOME/scripts/seafile
mkdir -m 755 $SEAFILE_HOME/scripts/runtime
cp $SEAFILE_HOME/scripts/seahub.conf $SEAFILE_HOME/scripts/runtime/seahub.conf

# compile and minify seahub (translations and js). We cannot do 'make dist'
# when building the image because there are some steps that must be done after
# setting up seafile, because it depends on ccnet's config and some envars.
(
	cd "$SEAHUB_DIR"
	apk add gettext
	npm install --global requirejs
	export PYTHONPATH=$PWD/../seafile/lib64/python2.6/site-packages:$PWD/thirdpart:$PWD
	export PATH=$PATH:thirdpart/Django-1.5.12-py2.6.egg/django/bin
	make locale uglify
	#apt-get autoremove -y gettext
)

# FIXME: Move the runtime translation script over here!
