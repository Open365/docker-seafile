FROM docker-registry.eyeosbcn.com/alpine6-node-base

ENV SEAFILE_VERSION 5.0.5
ENV ENABLE_DJANGO_DEBUG 0
ENV WHATAMI seafileServer
ENV INSTALLATION_DIR /var/service/
ENV MEMCACHED_HOST localhost
ENV MEMCACHED_PORT 11211
ENV MEMCACHED_MEMORY 256

#this is the default quota of seafile.
ENV SEAFILE_QUOTA 2

EXPOSE 10001 12001 8000 8080 8082

RUN \
	apk add --update --no-cache \
		build-base \
		git \
		memcached \
		patch

RUN npm install -g eyeos-service-ready-notify-cli

COPY x86_64 /root/
RUN apk add --update --allow-untrusted /root/*.apk

COPY [ \
	"install_seafile.sh", \
	"install_seahub.sh", \
	"package.json", \
	"${INSTALLATION_DIR}" \
]
COPY patches /opt/patches

# These environment variables are used by seafile, seahub and seafdav
# They aren't striclty required as the scripts set them, however, it is
# super useful having them here as it makes development / debugging so much easier
ENV SEAFILE_CONF_DIR /opt/seafile/seafile-data
ENV CCNET_CONF_DIR /var/lib/seafile/ccnet
ENV SEAFILE_CENTRAL_CONF_DIR /var/lib/seafile/conf
ENV PYTHONPATH /var/lib/seafile/scripts/seahub/thirdpart:/usr/lib/python2.7/site-packages

RUN ${INSTALLATION_DIR}/install_seafile.sh

VOLUME /opt/seafile/seafile-data

ENV SEAFILE_BASE /var/lib/seafile/scripts

COPY ["first_time_executing.py", "${SEAFILE_BASE}/first_time_executing.py"]
COPY [ \
	"start.sh", \
	"add_django_debug.txt", \
	"${INSTALLATION_DIR}" \
]
COPY seafdav.conf /seafdav.conf

COPY seafdav-customization/auth /opt/auth
RUN  cd /opt/auth && npm install

# put files for new users in the default library
COPY default-library-files/* ${SEAFILE_BASE}/seafile/docs/

CMD eyeos-run-server --serf ${INSTALLATION_DIR}/start.sh
