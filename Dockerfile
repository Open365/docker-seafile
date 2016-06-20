FROM docker-registry.eyeosbcn.com/alpine6-node-base

ENV \
    SEAFILE_VERSION=5.0.5 \
    ENABLE_DJANGO_DEBUG=0 \
    WHATAMI=seafileServer \
    INSTALLATION_DIR=/var/service/ \
    MEMCACHED_HOST=localhost \
    MEMCACHED_PORT=11211 \
    MEMCACHED_MEMORY=256 \
    SEAFILE_QUOTA=2
    #this is the default quota of seafile.

EXPOSE 10001 12001 8000 8080 8082

COPY [ \
	"install_seafile.sh", \
	"install_seahub.sh", \
	"install_seafdav.sh", \
	"package.json", \
	"${INSTALLATION_DIR}" \
]
COPY patches /opt/patches
COPY alpine-*.list /var/service/

# These environment variables are used by seafile, seahub and seafdav
# They aren't striclty required as the scripts set them, however, it is
# super useful having them here as it makes development / debugging so much easier
ENV SEAFILE_CONF_DIR /opt/seafile/seafile-data
ENV CCNET_CONF_DIR /var/lib/seafile/ccnet
ENV SEAFILE_CENTRAL_CONF_DIR /var/lib/seafile/conf
ENV PYTHONPATH /var/lib/seafile/scripts/seahub/thirdpart:/usr/lib/python2.7/site-packages

RUN \
	/scripts-base/buildDependencies.sh --production --install && \
	npm install -g eyeos-service-ready-notify-cli && \
	${INSTALLATION_DIR}/install_seafile.sh && \
	/scripts-base/buildDependencies.sh --production --purgue && \
	npm cache clean && \
	rm -fr /etc/ssl /var/cache/apk/* /tmp/*

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
COPY seafdav-customization/seafdav.sh ${SEAFILE_BASE}/seafdav.sh
RUN  cd /opt/auth && npm install

# put files for new users in the default library
COPY default-library-files/* ${SEAFILE_BASE}/seafile/docs/

CMD eyeos-run-server --serf ${INSTALLATION_DIR}/start.sh
COPY debug/* /usr/bin/
COPY mime.types /etc/mime.types
