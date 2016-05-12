#!/bin/bash
exec /sbin/setuser memcache \
	/usr/bin/memcached -m "${MEMCACHED_MEMORY}" >> /var/log/memcached.log 2>&1
