#!/bin/bash

parrent=`ps --no-headers -o command $PPID | cut -d' ' -f2`
if [[ $parrent =~ "runcommand.sh" ]]; then
 for arg do
  shift
  case $arg in
	(--all) : ;;
	(-depth) : ;;
        (8) : ;;
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
else
 /bin/fbseta $@
fi

