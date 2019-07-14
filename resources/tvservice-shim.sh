#!/bin/bash
pref=`cat /sys/class/display/mode`

#String position
strindex() { 
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

# PAL or NTSC

#function tvmode(){
#	if [[ "$1" =~ (p100|p50|p24|p25) ]]; then
# 		mode="PAL"
#	fi
#	if [[ "$1" =~ (p120|p60|p30) ]]; then
#        	mode="NTSC"
#	fi
#	echo "$mode"
#}

#Resolution and aspectratio
function resulution(){
	case $1 in
  		480*)            X=720  Y=480 ;;
  		576*)            X=720  Y=576 ;;
	  	720p*)           X=1280 Y=720 ;;
                720i*)           X=1280 Y=720 ;;
  		1080p*)          X=1920 Y=1080 ;;
                1080i*)          X=1920 Y=1080 ;;
  		2160p*)          X=3840 Y=2160 ;;
  		*)               X=1920 Y=1080 ;;
	esac
	reso=$X"x"$Y
	echo "$reso"
}

#function ratio(){
#        case $1 in
#                480*)            ratio="16:9" ;;
#                576*)            ratio="16:9" ;;
#                *)               ratio="16:9" ;;
#        esac
#	echo "$ratio"
#}

function vicmode(){
	case $1 in
               	480*)            vm=3 ;;
               	576*)            vm=18 ;;
               	720p5*)          vm=19 ;;
               	720p6*)          vm=4 ;;
               	1080p24*)        vm=32 ;;
               	1080p25*)        vm=33 ;;
               	1080p30*)        vm=34 ;;
               	1080p50*)        vm=31 ;;
      		1080p60*)        vm=16 ;;
      		1080i5*)         vm=20 ;;
		1080i6*)         vm=5 ;;
		*)		 vm="unknown" ;;
	esac
	echo $vm
}

function clockspeed(){
        case $1 in
                480*)            cs=27 ;;
                576*)            cs=27 ;;
                720p5*)          cs=74 ;;
                720p6*)          cs=74 ;;
                1080p24*)        cs=74 ;;
                1080p25*)        cs=74 ;;
                1080p30*)        cs=74 ;;
                1080p50*)        cs=148 ;;
                1080p60*)        cs=148 ;;
                1080i5*)         cs=74 ;;
                1080i6*)         cs=74 ;;
                *)               cs="unknown" ;;
        esac
        echo $cs
}

#Hertz
function gethz(){
	a=$1
	b=hz
	vartend=$(strindex $a $b)
	if [[ "$1" =~ "p" ]]; then
			vartbeg=`echo $a | grep -aob 'p' | grep -oE '[0-9]+'`
	fi
	if [[ "$1" =~ "i" ]]; then
			vartbeg=`echo $a | grep -aob 'i' | grep -oE '[0-9]+'`
	fi
	startpos=`expr $vartbeg + 1`
	endpos=`expr $vartend - 1`
 	hzlong=`expr $endpos - $vartbeg`
	hznum=${a:$startpos:$hzlong}
	echo "$hznum"
}

#Interface /Progressive this solution doesn't work
function intpro(){
	if [[ "$1" =~ "p" ]]; then
	    interprog="progressive"
	fi
	if [[ "$1" =~ "i" ]]; then
	    interprog="interlaced"
	fi
	echo "$interprog"
}
case $1 in

	-s)
#		tvline="state 0x00401 [HDMI CEA ("$(vicmode $pref)")], "$(resulution $perf)" @ "$(gethz $pref)".00Hz, "$(intpro $pref)
		tvline="state 0x120009 [HDMI CEA ("$(vicmode $pref)") RGB lim 16:9], "$(resulution $perf)" @ "$(gethz $pref)".00Hz, "$(intpro $pref)
		echo $tvline
		;;
	-m*)
		if [ -z $2 ]; then
			echo "You need to enter Group CEA/DMT"
		else
			if [ $2 = "CEA" ]; then
#				dispcap=`cat /sys/class/amhdmitx/amhdmitx0/disp_cap`
				dispcap=`cat /sys/class/amhdmitx/amhdmitx0/disp_cap|grep '^[1,3-9]'`
				numlines=`echo "$dispcap" | wc -l`
				echo "Group CEA has "$numlines" modes:"
				for item in $dispcap
				do
					counter=`expr $counter + 1`
#					modeline="mode "$counter": "$(resulution $item)" @ "$(gethz $item)"Hz "$(ratio $item)", clock:25MHz "$(intpro $item)
					modeline[$counter]="mode "$(vicmode $item)": "$(resulution $item)" @ "$(gethz $item)"Hz 16:9, clock:"$(clockspeed $item)"MHz "$(intpro $item)
				done
				IFS=$'\n' sorted=($(sort -V <<<"${modeline[*]}"))
				unset IFS
				printf "%s\n" "${sorted[@]}"

			elif [ $2 = "DMT" ]; then
				echo "Group DMT has 0 modes:"
			else
				echo "Unknown group"
			fi
		fi
		;;
	-c*)
		if [[ -z $2 ]]; then
			echo "You need to set PAL/NTSC 4:3/16:9" 
		else 
			if [[ "$2" =~ "PAL" ]]; then
				sudo sh -c 'echo 576p50hz > /sys/class/display/mode'
			elif [[ "$2" =~ "NTSC" ]]; then
				sudo sh -c 'echo 480p60hz > /sys/class/display/mode' 
			else
				echo "Not cointaing right information, set PAL or NTSC"
			fi
		fi
	;;

	-e*)
		if [[ -z $2 ]]; then
                        echo 'You need to set CEA mode# (tvservice -e "CEA 4")'
		else
			case $2 in
				"CEA 3")
					sudo sh -c 'echo 480p60hz > /sys/class/display/mode'
				;;
                                "CEA 4")
                                        sudo sh -c 'echo 720p60hz > /sys/class/display/mode'
                                ;;
                                "CEA 5")
                                        sudo sh -c 'echo 1080i60hz > /sys/class/display/mode'
                                ;;
                                "CEA 16")
                                        sudo sh -c 'echo 1080p60hz > /sys/class/display/mode'
                                ;;
                                "CEA 18")
                                        sudo sh -c 'echo 576p50hz > /sys/class/display/mode'
                                ;;
                                "CEA 19")
                                        sudo sh -c 'echo 720p50hz > /sys/class/display/mode'
                                ;;
                                "CEA 20")
                                        sudo sh -c 'echo 1080i50hz > /sys/class/display/mode'
                                ;;
                                "CEA 31")
                                        sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
                                ;;
                                "CEA 32")
                                        sudo sh -c 'echo 1080p24hz > /sys/class/display/mode'
                                ;;
                                "CEA 33")
                                        sudo sh -c 'echo 1080p25hz > /sys/class/display/mode'
                                ;;
                                "CEA 34")
                                        sudo sh -c 'echo 1080p30hz > /sys/class/display/mode'
                                ;;
				*)
					echo "Not a valid mode"
				;;
			esac
		fi
	;;

	*)
		echo "Argument missing:"
		echo " -s for Status"
		echo " -m CEA or DMT(only CEA will list on ver4k)"
		echo ' -c "PAL/NTSC"(sets 576p/480p 16:9 on vero4k)'
		echo ' -e "CEA mode#"("" needed)'
	;;
esac

exit
