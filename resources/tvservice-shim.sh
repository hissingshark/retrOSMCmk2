#!/bin/bash
pref=`cat /sys/class/display/mode | sed 's/\*//g'`
pref2=`echo $pref | sed 's/\p60hz/p/g'|sed 's/\i60hz/i/g'|sed 's/\hz//g'`

if [ -z "$*" ]; then
	echo "Argument missing:"
        echo " -s for Status"
        echo " -m CEA or DMT(only CEA will list on ver4k)"
        echo ' -c "PAL/NTSC"(sets 576p/480p 16:9 on vero4k)'
        echo ' -e "CEA mode#"("" needed)'
	exit 0
fi

#String position
strindex() {
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}


#Resolution and aspectratio
function resolution(){
	case $1 in
		480p)           X=720 	Y=480  	aspect="4:3"	vm=2		cs=27		hz=60	;;
		720p)           X=1280 	Y=720	aspect="16:9"	vm=4		cs=74		hz=60	;;
		1080i)     	X=1920 	Y=1080	aspect="16:9"	vm=5		cs=74		hz=60 	;;
		480i)		X=1440  Y=480  	aspect="4:3"	vm=6		cs=74		hz=60 	;;
		1080p)        	X=1920 	Y=1080	aspect="16:9"	vm=16		cs=148		hz=60 	;;
		576p50)         X=720  	Y=576 	aspect="4:3"	vm=17		cs=27		hz=50 	;;
		720p50)		X=1280 	Y=720	aspect="16:9"	vm=19		cs=74		hz=50 	;;
		576i50)		X=1440	Y=576	aspect="4:3"	vm=21		cs=27		hz=50 	;;
		1080p50)	X=1920 	Y=1080 	aspect="16:9"	vm=31		cs=148		hz=50 	;;
		1080p24)	X=1920 	Y=1080 	aspect="16:9"	vm=32		cs=74		hz=24 	;;
		1080p25)	X=1920 	Y=1080 	aspect="16:9"	vm=33		cs=74		hz=25 	;;
		1080p30)	X=1920 	Y=1080 	aspect="16:9"	vm=34		cs=74		hz=30 	;;
		1080i50)	X=1920 	Y=1080 	aspect="16:9"	vm=40		cs=148		hz=100 	;;
		*)		X="n/a" Y="n/a" aspect="n/a"  	vm="n/a"	cs="n/a"        hz="n/a"   ;;
	esac
	reso="$vm,$aspect,$X,$Y,$hz,$cs"
	echo "$reso"
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
		vicm=$(resolution $pref2)
		IFS=',' arr=(${vicm})
		IFS=$OLDIFS
		tvline="state 0x120009 [HDMI CEA (${arr[0]}) RGB lim ${arr[1]}], "${arr[2]}"x"${arr[3]}" @ ${arr[4]}.00Hz, $(intpro $pref2)"
		echo $tvline
		;;
	-m*)
		if [ -z $2 ]; then
			echo "You need to enter Group CEA/DMT"
		else
			if [ $2 = "CEA" ]; then
				dispcap=`cat /sys/class/amhdmitx/amhdmitx0/disp_cap|grep '^[1,3-9]'|sed 's/\p60/p/g'|sed 's/\i60/i/g'|sed 's/\hz//g'|sed 's/\*//g'`
				numlines=`echo "$dispcap" | wc -l`
				echo "Group CEA has "$numlines" modes:"
				for item in $dispcap
				do
					counter=`expr $counter + 1`
					infoloop=$(resolution $item)
					IFS=',' info=(${infoloop})
					IFS=$OLDIFS
					modeline[$counter]="mode ${info[0]}: ${info[2]}x${info[3]} @ ${info[4]}Hz ${info[1]}, clock:${info[5]}MHz $(intpro $item)"
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
				fbset -g 720 576 720 1152 32
			elif [[ "$2" =~ "NTSC" ]]; then
				sudo sh -c 'echo 480p60hz > /sys/class/display/mode'
				fbset -g 720 480 720 960 32
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
				"CEA 2")
					sudo sh -c 'echo 480p60hz > /sys/class/display/mode'
					fbset -g 720 480 720 960 32
				;;
		                "CEA 4")
					sudo sh -c 'echo 720p60hz > /sys/class/display/mode'
					fbset -g 1280 720 1280 1440 32
                		;;
                		"CEA 5")
					sudo sh -c 'echo 1080i60hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
		                ;;
				"CEA 6")
					sudo sh -c 'echo 480i60hz > /sys/class/display/mode'
					fbset -g 1440 480 1440 960 32
		                ;;
                		"CEA 16")
                    			sudo sh -c 'echo 1080p60hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
		                ;;
                		"CEA 17")
                    			sudo sh -c 'echo 576p50hz > /sys/class/display/mode'
					fbset -g 720 576 720 1152 32
		                ;;
                		"CEA 19")
                    			sudo sh -c 'echo 720p50hz > /sys/class/display/mode'
					fbset -g 1280 720 1280 1440 32
		                ;;
				"CEA 21")
                    			sudo sh -c 'echo 576i50hz > /sys/class/display/mode'
					fbset -g 1440 576 1440 1152 32
		                ;;
                		"CEA 31")
                    			sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
		                ;;
                		"CEA 32")
                    			sudo sh -c 'echo 1080p24hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
                		;;
                		"CEA 33")
                    			sudo sh -c 'echo 1080p25hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
		                ;;
                		"CEA 34")
                    			sudo sh -c 'echo 1080p30hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
                		;;
                		"CEA 40")
                    			sudo sh -c 'echo 1080i50hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
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
