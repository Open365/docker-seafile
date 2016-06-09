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


COPY [ \
	"install_seafile.sh", \
	"package.json", \
	"${INSTALLATION_DIR}" \
]
COPY patches /opt/patches

RUN \
	apk add --update --no-cache \
		build-base \
		git \
		memcached \
		patch

#RUN pip install python-memcached

RUN npm install -g eyeos-service-ready-notify-cli

COPY x86_64 /root/
RUN apk add --update --allow-untrusted /root/*.apk

# vHanda: Temporary until we patch out this requirement!
RUN cp /var/lib/seafile/default/scripts/seahub.conf /var/lib/seafile/default/scripts/runtime/seahub.conf

VOLUME [ "/opt/seafile/seafile-data" ]

# vHanda: How do we translate this into alpine?
RUN mkdir -p /etc/service/seafile /etc/service/seahub /etc/service/memcached
COPY seafile.sh /etc/service/seafile/run
COPY seahub.sh /etc/service/seahub/run
COPY memcached.sh /etc/service/memcached/run

ENV SEAFILE_BASE /var/lib/seafile/default/scripts

COPY ["first_time_executing.py", "${SEAFILE_BASE}/first_time_executing.py"]
COPY seahub-customization/custom-template /opt/seafile/seahub-data/custom
COPY seahub-customization/media /opt/seafile/seahub-data/media
COPY dev-scripts/* /usr/bin/
COPY ["seahub-customization/django", "${SEAFILE_BASE}/seahub/eyeos"]
COPY [ \
	"start.sh", \
	"add_django_debug.txt", \
	"${INSTALLATION_DIR}" \
]
#COPY seafdav.conf /opt/seafile/conf/seafdav.conf
#COPY seafdav.conf /seafdav.conf

COPY seahub-customization/auth /opt/auth
RUN  cd /opt/auth && npm install

RUN chmod +x ${INSTALLATION_DIR}/start.sh /etc/service/seafile/run /etc/service/seahub/run

# put files for new users in the default library
# vHanda: FIXME!!
# RUN rm -rf ${SEAFILE_BASE_DIR}/seafile/docs/*
# COPY default-library-files/* /opt/seafile/seafile-server-${SEAFILE_VERSION}/seafile/docs/

CMD eyeos-run-server --serf ${INSTALLATION_DIR}/start.sh

ENV MediaDir /usr/share/nginx/html/seafmedia

RUN mkdir -p ${MediaDir}

VOLUME ${MediaDir}
VOLUME /opt/seafile
# vHanda: Why is this a volume?
