#!/usr/bin/env bash

APPDIR="/home/edos/nom/projects/production/transcoder-manager"
CURDIR=$(pwd)

if [[ $# -lt 1 ]]
then
    echo
    echo "Usage:"
    echo "  $0 <start|stop|restart|status>"
    echo
    exit 1
fi

case $1 in
    "status")
        cat $APPDIR/tmp/pids/thin.* &> /dev/null
        if [[ $? -ne 0 ]]
        then
            echo "Service stopped"
        else
            for i in $(ls -C1 $APPDIR/tmp/pids/thin.*)
            do
                echo "Running: $(cat $i)"
            done
        fi
    ;;
    "start")
        echo "Making thin dirs..."
        mkdir -p $APPDIR/tmp/thin
        mkdir -p $APPDIR/tmp/pids
        mkdir -p $APPDIR/tmp/sockets

        echo "Starting thin..."
        cd $APPDIR
        # Production
        thin start -e production -C $APPDIR/config/thin.yml
        cd $CURDIR
        sleep 2
        $0 status
    ;;
    "stop")
        cat $APPDIR/tmp/pids/thin.* &> /dev/null
        if [[ $? -eq 0 ]]
        then
            for i in $(ls -C1 $APPDIR/tmp/pids/thin.*)
            do
                PID=$(cat $i)
                echo -n "Stopping thin ${PID}..."
                kill $PID
                if [[ $? -eq 0 ]]
                then
                    echo "OK"
                else
                    echo "FAIL"
                fi
            done
        fi
        $0 status
    ;;
    "restart")
        $0 stop
        $0 start
        $0 status
    ;;
esac
