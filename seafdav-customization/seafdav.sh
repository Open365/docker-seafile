#!/bin/bash

echo ""

SCRIPT=$(readlink -f "$0")
INSTALLPATH=$(dirname "${SCRIPT}")
TOPDIR=$(dirname "${INSTALLPATH}")
default_ccnet_conf_dir=${TOPDIR}/ccnet
central_config_dir=${TOPDIR}/conf

manage_py=${INSTALLPATH}/seahub/manage.py
gunicorn_conf=${INSTALLPATH}/runtime/seahub.conf
pidfile=${INSTALLPATH}/runtime/seahub.pid
errorlog=${INSTALLPATH}/runtime/error.log
accesslog=${INSTALLPATH}/runtime/access.log


script_name=$0
function usage () {
    echo "Usage: "
    echo
    echo "  $(basename ${script_name}) { start | stop | restart }"
    echo ""
}

# Check args
if [[ $1 != "start" && $1 != "stop" && $1 != "restart" ]]; then
    usage;
    exit 1;
fi

function check_python_executable() {
    if [[ "$PYTHON" != "" && -x $PYTHON ]]; then
        return 0
    fi

    if which python2.7 2>/dev/null 1>&2; then
        PYTHON=python2.7
    elif which python27 2>/dev/null 1>&2; then
        PYTHON=python27
    elif which python2.6 2>/dev/null 1>&2; then
        PYTHON=python2.6
    elif which python26 2>/dev/null 1>&2; then
        PYTHON=python26
    else
        echo
        echo "Can't find a python executable of version 2.6 or above in PATH"
        echo "Install python 2.6+ before continue."
        echo "Or if you installed it in a non-standard PATH, set the PYTHON enviroment varirable to it"
        echo
        exit 1
    fi
}

function validate_ccnet_conf_dir () {
    if [[ ! -d ${default_ccnet_conf_dir} ]]; then
        echo "Error: there is no ccnet config directory."
        echo "Have you run setup-seafile.sh before this?"
        echo ""
        exit -1;
    fi
}

function validate_seafdav_running () {
    if pgrep -f "${manage_py}" 2>/dev/null 1>&2; then
        echo "Seahub is already running."
        exit 1;
    fi
}

if [[ ($1 == "start" || $1 == "restart") ]]; then
    port=8080
elif [[ $1 == "stop" && $# == 1 ]]; then
    dummy=dummy
else
    usage;
    exit 1
fi

function warning_if_seafdav_not_running () {
    if ! pgrep -f "seafile-controller -c ${default_ccnet_conf_dir}" 2>/dev/null 1>&2; then
        echo
        echo "Warning: seafile-controller not running. Have you run \"./seafile.sh start\" ?"
        echo
        exit 1
    fi
}

function read_seafile_data_dir () {
    seafile_ini=${default_ccnet_conf_dir}/seafile.ini
    if [[ ! -f ${seafile_ini} ]]; then
        echo "${seafile_ini} not found. Now quit"
        exit 1
    fi
    seafile_data_dir=$(cat "${seafile_ini}")
    if [[ ! -d ${seafile_data_dir} ]]; then
        echo "Your seafile server data directory \"${seafile_data_dir}\" is invalid or doesn't exits."
        echo "Please check it first, or create this directory yourself."
        echo ""
        exit 1;
    fi
}

function before_start() {
    prepare_env;
}

function start_seafdav () {
    before_start;
    cd /usr/share/seafdav
    $PYTHON -m wsgidav.server.run_server -H 0.0.0.0
    echo "Seafdav is started"
}

function prepare_env() {
    check_python_executable;
    validate_ccnet_conf_dir;
    read_seafile_data_dir;

    if [[ -z "$LANG" ]]; then
        echo "LANG is not set in ENV, set to en_US.UTF-8"
        export LANG='en_US.UTF-8'
    fi
    if [[ -z "$LC_ALL" ]]; then
        echo "LC_ALL is not set in ENV, set to en_US.UTF-8"
        export LC_ALL='en_US.UTF-8'
    fi

    export CCNET_CONF_DIR=${default_ccnet_conf_dir}
    export SEAFILE_CONF_DIR=${seafile_data_dir}
    export SEAFILE_CENTRAL_CONF_DIR=${central_config_dir}
    export PYTHONPATH=${INSTALLPATH}/seafile/lib/python2.6/site-packages:${INSTALLPATH}/seafile/lib64/python2.6/site-packages:${INSTALLPATH}/seahub/thirdpart:$PYTHONPATH
    export PYTHONPATH=${INSTALLPATH}/seafile/lib/python2.7/site-packages:${INSTALLPATH}/seafile/lib64/python2.7/site-packages:$PYTHONPATH
}

function stop_seafdav () {
    if [[ -f ${pidfile} ]]; then
        pid=$(cat "${pidfile}")
        echo "Stopping seahub ..."
        kill ${pid}
        rm -f ${pidfile}
        return 0
    else
        echo "Seahub is not running"
    fi
}

case $1 in
    "start" )
        start_seafdav;
        ;;
    "stop" )
        stop_seafdav;
        ;;
    "restart" )
        stop_seafdav
        sleep 2
        start_seafdav
        ;;
esac

echo "Done."
echo ""
