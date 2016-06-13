#!/bin/bash
set -e
set -x
set -o pipefail

SEAFILE_DIR='/var/lib/seafile/scripts'
SEAHUB_DIR="$SEAFILE_DIR/seahub"

# Use seafdav from github
cd /opt/
git clone https://github.com/Open365/seafdav.git --depth 1 --branch open365
rm -rf /usr/share/seafdav
cp -rf /opt/seafdav/ /usr/share/seafdav/
rm -rf /opt/seafdav

