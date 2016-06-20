#!/bin/bash
set -e
set -x
set -o pipefail

SEAFILE_BASE_DIR=/var/lib/seafile
SEAFILE_SERVER_LATEST_FOLDER=$SEAFILE_BASE_DIR/scripts

export LC_ALL=en_US.utf8

SEAFILE_DATA_FOLDER=/opt/seafile/seafile-data
SEAFILE_DATA_FOLDER_TMP="$SEAFILE_DATA_FOLDER"-tmp

#Create databases on remote mysql. Only the first time executed
cd $SEAFILE_SERVER_LATEST_FOLDER

if ./first_time_executing.py
then
	FIRST_TIME=1
else
	FIRST_TIME=0
fi

cd -

# This file is generated after executing setup-seafile-mysql.sh.
# if we restart the container (or docker-compose restarts it because it fails)
# this folder will already exist. And when trying to execute the setup it will
# complain about it. So only do the setup if this folder does not exist.
if ! [ -d $SEAFILE_BASE_DIR/ccnet ]
then
	(
		# acknowledge initial message
		echo
		# server name
		echo open365_files
		# ip or domain of the server
		echo ${EYEOS_SEAFILE_PUBLIC_HOST}
		# where to put seafile data (We use a tmp folder for not overwrite the volume)
		echo ${SEAFILE_DATA_FOLDER_TMP}
		# port for seafile fileserver (we echo the default value)
		echo 8082
		# choice between:
		# 1: create new db
		# 2: use existing db
		if [ "$FIRST_TIME" = 1 ]
		then
			# we choose one because if we arrive here it is because the db has not been set up yet
			echo 1
		else
			# we choose two because if we arrive here it is because the db already exists
			echo 2
		fi
		# host of mysql server
		echo mysql.service.consul
		# host allowed to connect to mysql
		echo '%'
		# port of mysql server
		echo 3306
		if [ "$FIRST_TIME" = 1 ]
		then
			# password of mysql root user
			echo "${MYSQL_ROOT_PASSWORD}"
		fi
		# mysql user for seafile
		echo "${MYSQL_SEAFILE_USER}"
		# password for the mysql user for seafile
		echo "${MYSQL_SEAFILE_PASSWORD}"
		# name for ccnet-server db (we echo the default value)
		echo ccnet-db
		# name for seafile-server db (we echo the default value)
		echo seafile-db
		# name for seahub-server db (we echo the default value)
		echo seahub-db
		# configuration done, acknowledge review of configuration
		echo
		# all done
	) | ${SEAFILE_SERVER_LATEST_FOLDER}/setup-seafile-mysql.sh
fi

# set number of seahub workers (3 by default)
SEAHUB_WORKERS="${SEAHUB_WORKERS:-3}"
sed -i 's@^\s*workers\s*=.*@workers = '"$SEAHUB_WORKERS"'@g' "$SEAFILE_SERVER_LATEST_FOLDER/runtime/seahub.conf"

# Disable transfer-owner endpoints and the buttons from the templates
sed -i '/repo_transfer_owner/s/^/#/' $SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/urls.py
sed -i '/repo_transfer_owner/d' $SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/templates/*.html

CONF_DIR="$SEAFILE_BASE_DIR/conf"
if [ "$ENABLE_DJANGO_DEBUG" = 1 ]
then
	cat ${INSTALLATION_DIR}/add_django_debug.txt >> $CONF_DIR/seahub_settings.py
fi

# Now we change to the default correct folder set in docker volume
find $SEAFILE_BASE_DIR/conf $SEAFILE_BASE_DIR/ccnet -maxdepth 1 -type f -print0 \
	| xargs -r -0 sed -i 's@'"$SEAFILE_DATA_FOLDER_TMP"'@'"$SEAFILE_DATA_FOLDER"'@g'

sed -i "/BRANDING_CSS/d" $CONF_DIR/seahub_settings.py
sed -i "$ a BRANDING_CSS = 'custom/css/eyeos.css'" $CONF_DIR/seahub_settings.py

sed -i -r 's@^SERVICE_URL = http(.*):8000$@SERVICE_URL = https\1/sync@g' $CONF_DIR/ccnet.conf
sed -i "s@INNER_FILE_SERVER_ROOT = 'http://127.0.0.1:' + FILE_SERVER_PORT@INNER_FILE_SERVER_ROOT = 'http://0.0.0.0:' + FILE_SERVER_PORT@g" \
    "$SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/settings.py"
sed -i "s@LOGO_PATH = 'img/seafile_logo.png'@LOGO_PATH = 'custom/img/open365.svg'@g" \
    "$SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/settings.py"

#prepending configs to seahub settings
echo "SERVE_STATIC = True" > /tmp/newfile
echo "MEDIA_URL = '/seafmedia/'" >> /tmp/newfile
echo "COMPRESS_URL = MEDIA_URL" >> /tmp/newfile
echo "STATIC_URL = MEDIA_URL + 'assets/'" >> /tmp/newfile
echo "SITE_ROOT = '/sync/'" >> /tmp/newfile
echo "LOGIN_URL = '/sync/accounts/login/'" >> /tmp/newfile
echo "SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTOCOL', 'https')" >> /tmp/newfile
echo "import os" >> /tmp/newfile
echo "FILE_SERVER_ROOT = os.environ.get('FILE_SERVER_ROOT', 'https://127.0.0.1')" >> /tmp/newfile
echo "FILE_SERVER_PORT = os.environ.get('FILE_SERVER_PORT','8082')" >> /tmp/newfile

cat $CONF_DIR/seahub_settings.py >> /tmp/newfile
mv /tmp/newfile $CONF_DIR/seahub_settings.py

mkdir -p '/opt/seafile/seahub-data/thumbnail/thumb/'
cat >> $CONF_DIR/seahub_settings.py <<-SEAHUB_SETTINGS
	AUTHENTICATION_BACKENDS = (
		'eyeos.auth.EyeosCardAuthBackend',
		'seahub.base.accounts.AuthBackend'
	)

	# Attempt limit before showing a captcha when login.
	LOGIN_ATTEMPT_LIMIT = float('inf')

	# Enable or disable thumbnails
	ENABLE_THUMBNAIL = True

	# Absolute filesystem path to the directory that will hold thumbnail files.
	THUMBNAIL_ROOT = '/opt/seafile/seahub-data/thumbnail/thumb/'
	THUMBNAIL_EXTENSION = 'png'
	THUMBNAIL_DEFAULT_SIZE = '24'
	PREVIEW_DEFAULT_SIZE = '24'

	SITE_NAME = 'Open365'
	SITE_TITLE = 'Open365'

	CACHES = {
	    'default': {
	        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
	        'LOCATION': '$MEMCACHED_HOST:$MEMCACHED_PORT',
	    }
	}
	LANGUAGE_CODE = '$SEAHUB_LANGUAGE'

	def string_to_bool(s):
	    return str(s).lower() in ('true', 'yes', 'y', '1')

	EMAIL_USE_TLS = string_to_bool(os.environ.get('SEAFILE_MAIL_USE_TLS', 'False'))
	EMAIL_HOST = os.environ.get('SEAFILE_MAIL_HOST', 'mailserver.service.consul')
	EMAIL_PORT = int(os.environ.get('SEAFILE_MAIL_PORT', '25'))
	# email user & password have no sane defaults, should be passed always or
	# else we will crash
	EMAIL_HOST_USER = os.environ['SEAFILE_MAIL_NOREPLY_USER']
	EMAIL_HOST_PASSWORD = os.environ['SEAFILE_MAIL_NOREPLY_PASSWORD']
	DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
	SERVER_EMAIL = EMAIL_HOST_USER
SEAHUB_SETTINGS

if ! [ -d "$SEAFILE_DATA_FOLDER" ]
then
	mkdir -p "$SEAFILE_DATA_FOLDER"
fi

if [ "$FIRST_TIME" = 1 ]
then
	cp -a "$SEAFILE_DATA_FOLDER_TMP/." "$SEAFILE_DATA_FOLDER" || true
	rm -rf "$SEAFILE_DATA_FOLDER_TMP"
fi

echo -e "\n[quota]\ndefault = $SEAFILE_QUOTA\n" >> $CONF_DIR/seafile.conf

echo "seafile installed. Now let's start it and create the admin user"
echo "start seafile itself"
"$SEAFILE_SERVER_LATEST_FOLDER/seafile.sh" start

# now start seahub, creating the admin user if it's the first time running
if [ "$FIRST_TIME" = 1 ]
then
	echo "now configure user while starting seahub"
	(
		# admin user
		echo ${SEAFILE_ADMIN_EMAIL}
		# admin pass
		echo ${SEAFILE_ADMIN_PASSWORD}
		# admin pass again
		echo ${SEAFILE_ADMIN_PASSWORD}
	) | "$SEAFILE_SERVER_LATEST_FOLDER/seahub.sh" start
else
	"$SEAFILE_SERVER_LATEST_FOLDER/seahub.sh" start
fi

# Starting seafdav!!
cp -f /seafdav.conf /var/lib/seafile/conf/seafdav.conf
export SEAFDAV_CONF=/var/lib/seafile/conf/seafdav.conf
$SEAFILE_SERVER_LATEST_FOLDER/seafdav.sh start

eyeos-service-ready-notify-cli &

/usr/bin/memcached -u root -m "${MEMCACHED_MEMORY}" >> /var/log/memcached.log 2>&1 &

cat <<-END
Seafile is ready and happy to serve requests


     .-""""""-.
   .'          '.
  /   O      O   \
 :                :
 |                |
 : ',          ,' :
  \  '-......-'  /
   '.          .'
     '-......-'


END

tail -f /var/lib/seafile/logs/seahub_gunicorn_access.log
