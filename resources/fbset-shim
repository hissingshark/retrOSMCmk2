#!/bin/bash
#debuging
#[[ -d /home/osmc/RetroPie/logs ]] || mkdir /home/osmc/RetroPie/logs
#[[ -e /home/osmc/RetroPie/logs/fbsetshim.log ]] || touch /home/osmc/RetroPie/logs/fbsetshim.log
#chmod 666 /home/osmc/RetroPie/logs/fbsetshim.log

if [[ -z $1 ]]; then
 fbsetret=`/bin/fbseta`
 echo "$fbsetret"
 exit
fi
#echo $@ >>  /home/osmc/RetroPie/logs/fbsetshim.log

for arg do
 shift
 case $arg in
	(--all) : ;;
	(*) set -- "$@" "$arg" ;;
 esac
done

for arg do
 shift
 case $arg in
        (-depth) : ;;
        (*) set -- "$@" "$arg" ;;
 esac
done

for arg do
 shift
 case $arg in
        (8) : ;;
        (*) set -- "$@" "$arg" ;;
 esac
done

for arg do
 shift
 case $arg in
        (32) : ;;
        (*) set -- "$@" "$arg" ;;
 esac
done
while test $# -gt 0
do
    case "$1" in
        --geometry) 
		setup="-xres $2 -yres $3 -vxres $4 -vyres $5"
		/bin/fbseta $setup
		exit
            ;;
        *) 
		/bin/fbseta $@
            ;;
    esac
    shift
done

