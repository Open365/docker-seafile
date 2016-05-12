#!/bin/bash
set -e
set -x
set -o pipefail

SEAFILE_SERVER_LATEST_FOLDER=/opt/seafile/seafile-server-latest

export LC_ALL=en_US.utf8

SEAFILE_DATA_FOLDER=/opt/seafile/seafile-data
SEAFILE_DATA_FOLDER_TMP="$SEAFILE_DATA_FOLDER"-tmp

#Create databases on remote mysql. Only the first time executed
cd /opt/seafile/seafile-server-${SEAFILE_VERSION}

if ./first_time_executing.py
then
	FIRST_TIME=1
else
	FIRST_TIME=0
fi

cd -

# /opt/seafile/ccnet is generated after executing setup-seafile-mysql.sh.
# if we restart the container (or docker-compose restarts it because it fails)
# this folder will already exist. And when trying to execute the setup it will
# complain about it. So only do the setup if this folder does not exist.
if ! [ -d /opt/seafile/ccnet ]
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
	) | /opt/seafile/seafile-server-${SEAFILE_VERSION}/setup-seafile-mysql.sh
fi

cp -f /domain_controller.py "$SEAFILE_SERVER_LATEST_FOLDER/seahub/thirdpart/wsgidav/addons/seafile/domain_controller.py"
cp -f /seafdav.conf /opt/seafile/conf/seafdav.conf


# set number of seahub workers (3 by default)
SEAHUB_WORKERS="${SEAHUB_WORKERS:-3}"
sed -i 's@^\s*workers\s*=.*@workers = '"$SEAHUB_WORKERS"'@g' "$SEAFILE_SERVER_LATEST_FOLDER/runtime/seahub.conf"

# Reduce the throttle rate.
sed -i 's/\/minute/00\/second/' $SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/settings.py

# Disable transfer-owner endpoints and the buttons from the templates
sed -i '/repo_transfer_owner/s/^/#/' $SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/urls.py
sed -i '/repo_transfer_owner/d' $SEAFILE_SERVER_LATEST_FOLDER/seahub/seahub/templates/*.html

if [ "$ENABLE_DJANGO_DEBUG" = 1 ]
then
	cat ${INSTALLATION_DIR}/add_django_debug.txt >> /opt/seafile/conf/seahub_settings.py
fi

# Now we change to the default correct folder set in docker volume
find /opt/seafile/conf /opt/seafile/ccnet -maxdepth 1 -type f -print0 \
	| xargs -r -0 sed -i 's@'"$SEAFILE_DATA_FOLDER_TMP"'@'"$SEAFILE_DATA_FOLDER"'@g'

# Seahub customization
cd "$SEAFILE_SERVER_LATEST_FOLDER/seahub/media"
ln -sf ../../../seahub-data/custom .
cp -a ../../../seahub-data/media/. .
cd -

sed -i "/BRANDING_CSS/d" /opt/seafile/conf/seahub_settings.py
sed -i "$ a BRANDING_CSS = 'custom/css/eyeos.css'" /opt/seafile/conf/seahub_settings.py

sed -i -r 's@^SERVICE_URL = http(.*):8000$@SERVICE_URL = https\1/sync@g' /opt/seafile/conf/ccnet.conf
sed -i "s@INNER_FILE_SERVER_ROOT = 'http://127.0.0.1:' + FILE_SERVER_PORT@INNER_FILE_SERVER_ROOT = 'http://0.0.0.0:' + FILE_SERVER_PORT@g" \
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

cat /opt/seafile/conf/seahub_settings.py >> /tmp/newfile
mv /tmp/newfile /opt/seafile/conf/seahub_settings.py

cat >> /opt/seafile/conf/seahub_settings.py <<-SEAHUB_SETTINGS
	AUTHENTICATION_BACKENDS = (
		'eyeos.auth.EyeosCardAuthBackend',
		'seahub.base.accounts.AuthBackend'
	)

	# Attempt limit before showing a captcha when login.
	LOGIN_ATTEMPT_LIMIT = float('inf')
	gettext_noop = lambda s: s
	LANGUAGES = (
    	('en', gettext_noop('English')),
	)

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
SEAHUB_SETTINGS

if ! [ -d "$SEAFILE_DATA_FOLDER" ]
then
	mkdir -p "$SEAFILE_DATA_FOLDER"
fi

if [ "$FIRST_TIME" = 1 ]
then
	cp -a "$SEAFILE_DATA_FOLDER_TMP/." "$SEAFILE_DATA_FOLDER"
	rm -rf "$SEAFILE_DATA_FOLDER_TMP"
fi

echo -e "\n[quota]\ndefault = $SEAFILE_QUOTA\n" >> /opt/seafile/conf/seafile.conf

echo "seafile installed. Now let's start it and create the admin user"
echo "start seafile itself"
"$SEAFILE_SERVER_LATEST_FOLDER/seafile.sh" start

# now we link some static folders to the folder where the volume is exposed
ln -sf /opt/seafile/seafile-server-5.0.5/seahub/media /usr/share/nginx/html/seafmedia/media
ln -sf /opt/seafile/seahub-data/avatars /usr/share/nginx/html/seafmedia/avatars
ln -sf /opt/seafile/seahub-data/custom /usr/share/nginx/html/seafmedia/custom

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
	) | SEAFILE_FASTCGI_HOST=0.0.0.0 "$SEAFILE_SERVER_LATEST_FOLDER/seahub.sh" start
else
	SEAFILE_FASTCGI_HOST=0.0.0.0 "$SEAFILE_SERVER_LATEST_FOLDER/seahub.sh" start
fi

eyeos-service-ready-notify-cli &

# this runs all /etc/service/*/run scripts, taken from https://github.com/JensErat/docker-seafile
/sbin/my_init
