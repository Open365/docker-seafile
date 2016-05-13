FROM phusion/baseimage

MAINTAINER eyeos

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
	export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install -y curl nano && \
	curl -sL https://deb.nodesource.com/setup | bash - && \
	apt-get install -y --no-install-recommends \
		build-essential \
		git \
		nodejs \
		unzip \
		memcached \
		python2.7 \
		python-imaging \
		python-memcache \
		python-mysqldb \
		python-setuptools \
		python-simplejson \
		patch \
		dnsmasq \
        g++ \
	&& \
	npm config set registry http://artifacts.eyeosbcn.com/nexus/content/groups/npm/ && \
	curl -L https://releases.hashicorp.com/serf/0.6.4/serf_0.6.4_linux_amd64.zip -o serf.zip && \
	unzip serf.zip && \
	mv serf /usr/bin/serf && \
	rm serf.zip && \
	npm install -g \
		eyeos-run-server \
		eyeos-service-ready-notify-cli \
		eyeos-tags-to-dns \
	&& \
	mkdir -p /opt/seafile && \
	curl -L https://bintray.com/artifact/download/seafile-org/seafile/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz \
		| tar -zx -C /opt/seafile && \
	chmod +x ${INSTALLATION_DIR}/install_seafile.sh && \
	${INSTALLATION_DIR}/install_seafile.sh && \
	apt-get clean && \
	apt-get -y autoremove --purge \
		curl \
		git \
		build-essential \
	&& \
	apt-get -y autoremove --purge && \
	rm -rf /var/lib/apt/lists/*

VOLUME [ "/opt/seafile/seafile-data" ]

RUN mkdir -p /etc/service/seafile /etc/service/seahub /etc/service/memcached
COPY seafile.sh /etc/service/seafile/run
COPY seahub.sh /etc/service/seahub/run
COPY memcached.sh /etc/service/memcached/run

COPY ["first_time_executing.py", "/opt/seafile/seafile-server-${SEAFILE_VERSION}/first_time_executing.py"]
COPY seahub-customization/custom-template /opt/seafile/seahub-data/custom
COPY seahub-customization/media /opt/seafile/seahub-data/media
COPY dnsmasq.conf /etc/dnsmasq.d/
COPY dev-scripts/* /usr/bin/
COPY ["seahub-customization/django", "/opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/eyeos"]
COPY seahub-customization/domain_controller.py /
COPY [ \
	"start.sh", \
	"add_django_debug.txt", \
	"${INSTALLATION_DIR}" \
]
COPY seafdav.conf /opt/seafile/conf/seafdav.conf
COPY seafdav.conf /seafdav.conf

COPY seahub-customization/auth /opt/auth
RUN  cd /opt/auth && npm install

RUN chmod +x ${INSTALLATION_DIR}/start.sh /etc/service/seafile/run /etc/service/seahub/run

# put files for new users in the default library
RUN rm -rf /opt/seafile/seafile-server-${SEAFILE_VERSION}/seafile/docs/*
COPY default-library-files/* /opt/seafile/seafile-server-${SEAFILE_VERSION}/seafile/docs/

CMD eyeos-run-server --serf ${INSTALLATION_DIR}/start.sh

ENV MediaDir /usr/share/nginx/html/seafmedia

RUN mkdir -p ${MediaDir}

VOLUME ${MediaDir}
VOLUME /opt/seafile
