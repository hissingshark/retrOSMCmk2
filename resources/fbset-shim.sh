#!/bin/bash

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
		/bin/fbset $setup
		exit
            ;;
        *)
		/bin/fbset $@
           ;;
    esac
    shift
 done
