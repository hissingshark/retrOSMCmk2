#!/bin/bash
pref=$(cat /sys/class/display/mode)

if [ -z "$*" ]; then
	# Writes command usage information if no arguments are sent to the script 
	echo "Usage: tvservice [OPTION]..."
	echo " -p, --preferred"$'\t'$'\t'"List and sets the prefered HDMI mode"
	echo " -s"$'\t'$'\t'$'\t'$'\t'"Get current GROUP and MODE, broken down to resolution and other info"
	echo " -m CEA or DMT"$'\t'$'\t'$'\t'"List all selectable MODES for selected GROUP"
	echo " -o, --off"$'\t'$'\t'$'\t'$'\t'"Power off the display,from the Vero4k(+), No Signal on your TV"
	echo " -c \"PAL/NTSC\""$'\t'$'\t'$'\t'"Sets 576p/480p 16:9"
	echo " -e \"CEA mode#\""$'\t'$'\t'$'\t'"Sets the selcted  GROUP MODE(\"\" needed)"
	echo " -a, --audio"$'\t'$'\t'$'\t'"Get supported audio information"
	echo " -n, --name"$'\t'$'\t'$'\t'"Displays your display device name(might list your AVR)."
	echo " -d, --dumpedid <filename>"$'\t'"Dumps raw-EDID data into filname of your choice."
	echo " -j, --json"$'\t'$'\t'$'\t'"Needs a second command \"-m [CEA/DEA]\"."
	echo " -h, --help"$'\t'$'\t'$'\t'"Print this information"
	exit 0
fi
# Setting the displays preferred resolution
function setprefered(){
	spcap=$(cat /sys/class/amhdmitx/amhdmitx0/disp_cap | grep "*"| sed 's/\*//g')
	resol=$(resulution $spcap)
	IFS=',' sparr=(${resol})
	IFS=$OLDIFS
	sudo sh -c "echo $spcap > /sys/class/display/mode"
	echo "Setting ${sparr[7]} ${sparr[0]}" 
	fbset -g ${sparr[2]} ${sparr[3]} ${sparr[2]} $[${sparr[3]}*2] 32
	echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
}

#Resolution and aspectratio
function resulution(){
	case $1 in

		"480i60hz"|"480i60hz*")           X=1440 	Y=240  	aspect="16:9"		vm=7		cs=27		hz=60	ip="interlaced"		typ="CEA";;
		"480p60hz"|"480p60hz*")           X=720 	Y=480  	aspect="16:9"		vm=3		cs=27		hz=60	ip="progressive"	typ="CEA";;
		"576i50hz"|"576i50hz*")           X=1440 	Y=288  	aspect="16:9"		vm=22		cs=27		hz=50	ip="interlaced"		typ="CEA";;
		"576p50hz"|"576p50hz*")           X=720 	Y=576  	aspect="16:9"		vm=18		cs=27		hz=50	ip="progressive"	typ="CEA";;
		"720p50hz"|"720p50hz*")           X=1280 	Y=720  	aspect="16:9"		vm=19		cs=74		hz=50	ip="progressive"	typ="CEA";;
		"720p60hz"|"720p60hz*")           X=1280 	Y=720  	aspect="16:9"		vm=4		cs=74		hz=60	ip="progressive"	typ="CEA";;
		"1080i50hz"|"1080i50hz*")          X=1920 	Y=540  	aspect="16:9"		vm=40		cs=148		hz=50	ip="interlaced"		typ="CEA";;
		"1080i60hz"|"1080i60hz*")          X=1920 	Y=540  	aspect="16:9"		vm=5		cs=74		hz=60	ip="interlaced"		typ="CEA";;
		"1080p50hz"|"1080p50hz*")          X=1920 	Y=1080 	aspect="16:9"		vm=31		cs=148		hz=50	ip="progressive"	typ="CEA";;
		"1080p30hz"|"1080p30hz*")          X=1920 	Y=1080 	aspect="16:9"		vm=34		cs=74		hz=30	ip="progressive"	typ="CEA";;
		"1080p25hz"|"1080p25hz*")          X=1920 	Y=1080 	aspect="16:9"		vm=33		cs=74		hz=25	ip="progressive"	typ="CEA";;
		"1080p24hz"|"1080p24hz*")          X=1920 	Y=1080 	aspect="16:9"		vm=32		cs=74		hz=24	ip="progressive"	typ="CEA";;
		"1080p60hz"|"1080p60hz*")          X=1920 	Y=1080 	aspect="16:9"		vm=16		cs=148		hz=60	ip="progressive"	typ="CEA";;
		"2560x1080p50hz"|"2560x1080p50hz*")     X=2560 	Y=1080 	aspect="64:27"		vm=89		cs=185		hz=50	ip="progressive"	typ="CEA";;
		"2560x1080p60hz"|"2560x1080p60hz*")     X=2560 	Y=1080 	aspect="64:27"		vm=90		cs=198		hz=60	ip="progressive"	typ="CEA";;
		"2160p30hz"|"2160p30hz*")		    X=3840 	Y=2160 	aspect="16:9"		vm=95		cs=297		hz=30	ip="progressive"	typ="CEA";;
		"2160p25hz"|"2160p25hz*")		    X=3840 	Y=2160 	aspect="16:9"		vm=94		cs=297		hz=25	ip="progressive"	typ="CEA";;
		"2160p24hz"|"2160p24hz*")		    X=3840 	Y=2160 	aspect="16:9"		vm=93		cs=297		hz=24	ip="progressive"	typ="CEA";;
		"smpte24hz"|"smpte24hz*")		    X=4096 	Y=2160 	aspect="256:135"	vm=98		cs=297		hz=24	ip="progressive"	typ="CEA";;
		"smpte25hz"|"smpte25hz*")		    X=4096 	Y=2160 	aspect="256:135"	vm=99		cs=297		hz=25	ip="progressive"	typ="CEA";;
		"smpte30hz"|"smpte30hz*")		    X=4096 	Y=2160 	aspect="256:135"	vm=100		cs=297		hz=30	ip="progressive"	typ="CEA";;
		"smpte50hz"|"smpte50hz*")		    X=4096 	Y=2160 	aspect="256:135"	vm=101		cs=594		hz=50	ip="progressive"	typ="CEA";;
		"smpte50hz420"|"smpte50hz420*")		X=4096 	Y=2160 	aspect="256:135"	vm=101		cs=594		hz=50	ip="progressive"	typ="CEA";;
		"smpte60hz"|"smpte60hz*")		    X=4096 	Y=2160 	aspect="256:135"	vm=102		cs=594		hz=60	ip="progressive"	typ="CEA";;
		"smpte60hz420"|"smpte60hz420*")	    X=4096 	Y=2160 	aspect="256:135"	vm=102		cs=594		hz=60	ip="progressive"	typ="CEA";;
		"2160p60hz"|"2160p60hz*")		    X=3840 	Y=2160 	aspect="16:9"		vm=97		cs=594		hz=60	ip="progressive"	typ="CEA";;
		"2160p50hz"|"2160p50hz*")		    X=3840 	Y=2160 	aspect="16:9"		vm=96		cs=594		hz=50	ip="progressive"	typ="CEA";;
		"2160p60hz420"|"2160p60hz420*")	    X=3840 	Y=2160 	aspect="16:9"		vm=97		cs=594		hz=60	ip="progressive"	typ="CEA";; #alias same vic diffrent dispcap
		"2160p50hz420"|"2160p50hz420*")	    X=3840 	Y=2160 	aspect="16:9"		vm=96		cs=594		hz=50	ip="progressive"	typ="CEA";;
#DMT-modes

		"640x480p60hz"|"640x480p60hz*")	    X=640 	Y=480 	aspect="4:3"		vm=4		cs=25		hz=60	ip="progressive"	typ="DMT";;
		"800x600p60hz"|"800x600p60hz*")	    X=800 	Y=600 	aspect="4:3"		vm=9		cs=40		hz=60	ip="progressive"	typ="DMT";;
		"1024x768p60hz"|"1024x768p60hz*")	    X=1024 	Y=768 	aspect="4:3"		vm=16		cs=65		hz=60	ip="progressive"	typ="DMT";;
		"1152x864p75hz"|"1152x864p75hz*")	    X=1024 	Y=768 	aspect="4:3"		vm=21		cs=108		hz=75	ip="progressive"	typ="DMT";;
		"1280x768p60hz"|"1280x768p60hz*")	    X=1280	Y=768 	aspect="15:9"		vm=23		cs=68		hz=60	ip="progressive"	typ="DMT";;
		"1280x800p60hz"|"1280x800p60hz*")	    X=1280	Y=800 	aspect="16:10"		vm=28		cs=71		hz=60	ip="progressive"	typ="DMT";;
		"1280x960p60hz"|"1280x960p60hz*")	    X=1280	Y=960 	aspect="4:3"		vm=32		cs=108		hz=60	ip="progressive"	typ="DMT";;
		"1280x1024p60hz"|"1280x1024p60hz*")	    X=1280	Y=1024 	aspect="5:4"		vm=35		cs=108		hz=60	ip="progressive"	typ="DMT";;
		"1280x1024"|"1280x1024*")	   		X=1280	Y=1024 	aspect="5:4"		vm=35		cs=108		hz=60	ip="progressive"	typ="DMT";; # alias same DMT# diffrent dispcap
		"1360x768p60hz"|"1360x768p60hz*")	    X=1360	Y=768 	aspect="16:9"		vm=39		cs=85		hz=60	ip="progressive"	typ="DMT";;
		"1366x768p60hz"|"1366x768p60hz*")	    X=1366	Y=768 	aspect="16:9"		vm=81		cs=85		hz=60	ip="progressive"	typ="DMT";;
		"1400x1050p60hz"|"1400x1050p60hz*")	    X=1400	Y=1050 	aspect="4:3"		vm=42		cs=101		hz=60	ip="progressive"	typ="DMT";;
		"1440x900p60hz"|"1440x900p60hz*")	    X=1440	Y=900 	aspect="16:10"		vm=47		cs=106		hz=60	ip="progressive"	typ="DMT";;
		"1600x900p60hz"|"1600x900p60hz*")	    X=1600	Y=900 	aspect="16:9"		vm=83		cs=108		hz=60	ip="progressive"	typ="DMT";;
		"1600x1200p60hz"|"1600x1200p60hz*")	    X=1600	Y=1200 	aspect="4:3"		vm=51		cs=162		hz=60	ip="progressive"	typ="DMT";;
		"1680x1050p60hz"|"1680x1050p60hz*")	    X=1680	Y=1050 	aspect="16:10"		vm=58		cs=146		hz=60	ip="progressive"	typ="DMT";;
		"1920x1200p60hz"|"1920x1200p60hz*")	    X=1920	Y=1200 	aspect="16:10"		vm=69		cs=193		hz=60	ip="progressive"	typ="DMT";;
		"2560x1600p60h"|"2560x1600p60hz*")	    X=2560	Y=1600 	aspect="16:10"		vm=77		cs=348		hz=60	ip="progressive"	typ="DMT";;

# custom resolution for adafruit LCD 5" screens? Ignored insetting resolution
		"800x480p60hz"|"800x480p60hz*")	    X=800 	Y=480 	aspect="5:3"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";;
	
# more custom resolutions that can't be traced to any standard DMT Ignored insetting resolution
		"852x480p60hz"|"852x480p60hz*")	    X=852 	Y=480 	aspect="16:9"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";;
		"854x480p60hz"|"854x480p60hz*")	    X=854 	Y=480 	aspect="16:9"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";;
		"1024x600p60hz"|"1024x600p60hz*")	    X=1024 	Y=600 	aspect="15:9"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";;
		"1280x600p60hz"|"1280x600p60hz*")	    X=1280 	Y=600 	aspect="2.13:1"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";;
		"1440x2560p60hz"|"1440x2560p60hz*")	    X=1440	Y=2560 	aspect="9:16"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";;
		"2160x1200p60hz"|"2160x1200p60hz*")	    X=2160	Y=1200 	aspect="16:9"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";; # close to DMT 84, 2048x1152
		"2560x1080p60hz"|"2560x1080p60hz*")	    X=2560	Y=1080 	aspect="64:27"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";; # identical to CEA 90
		"2560x1440p60hz"|"2560x1440p60hz*")	    X=2560	Y=1440 	aspect="16:9"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";; # no clue
		"3440x1440p60hz"|"3440x1440p60hz*")	    X=3440	Y=1440 	aspect="21:9"		vm=87		cs=0		hz=60	ip="progressive"	typ="DMT";; # no clue
	
	*)	X="n/a" Y="n/a" aspect="n/a" vm="n/a" cs="n/a" hz="n/a"  ip="n/a" typ="n/a" ;;
	esac
	reso="$vm,$aspect,$X,$Y,$hz,$cs,$ip,$typ"
	if echo x"$1" | grep -q '*' ;then
		reso="$reso,(prefer)"
	fi
	echo "$reso"
}

case $1 in
	-o|--off)
		# Turns off HDMI on Vero4k(+), effetivly causing no-signal on your display

		echo 0 >/sys/class/amhdmitx/amhdmitx0/phy
	;;
	-j|--json)
		# Here we list the DMT/CEA modes available in json format

		if [ -z $2 ]; then
			echo "You need to enter -m GROUPNAME (CEA or DMT)"
		elif [[ "$2" =~ "-m" ]]; then
			if [ -z $3 ]; then
				echo "You forgot to select group to list in json format"
			else
				case $3 in
					CEA|cea)
						jdispcap=$(cat /sys/class/amhdmitx/amhdmitx0/disp_cap)
						for jcea in $jdispcap
						do
							jccounter=$(($jccounter + 1))
							jinfoloop=$(resulution $jcea)
							IFS=',' jcinfo=(${jinfoloop})
							IFS=$OLDIFS
							jcmline[$jccounter]='{ "code": '${jcinfo[0]}', "width": '${jcinfo[2]}', "height": '${jcinfo[3]}', "rate": '${jcinfo[4]}', "aspect_ratio": "'${jcinfo[1]}'", "scan": "'${jcinfo[6]}'","3d_modes":[] },'
						done
						IFS=$'\n' jsorted=($(sort -V <<<"${jcmline[*]}"))
						unset IFS
						echo "["
						jjoined=$(printf "%s\n" "${jsorted[@]}")
						tempjsrt=$(rev <<< "$jjoined"| cut -c 1- | rev)
						tempjsrt2=$(echo $tempjsrt | sed $'s/] }, /"] },\\\n/g')
						tempjsrt3=${tempjsrt2::-1}
						printf "%s\n" "$tempjsrt3"
						echo "]"
					;;
					DMT|dmt)
						jvesacap=$(cat /sys/class/amhdmitx/amhdmitx0/vesa_cap)
						for jdmt in $jvesacap
						do
							jvcounter=$(($jvcounter + 1))
							jvinfoloop=$(resulution $jdmt)
							IFS=',' jvinfo=(${jvinfoloop})
							IFS=$OLDIFS
							jvmline[$jvcounter]='{ "code": '${jvinfo[0]}', "width": '${jvinfo[2]}', "height": '${jvinfo[3]}', "rate": '${jvinfo[4]}', "aspect_ratio": "'${jvinfo[1]}'", "scan":"'${jvinfo[6]}'","3d_modes":[] },'
						done
						IFS=$'\n' jvsorted=($(sort -V <<<"${jvmline[*]}"))
						unset IFS
						echo "["
						jvjoined=$(printf "%s\n" "${jvsorted[@]}")
						tempjvsrt=$(rev <<< "$jvjoined"| cut -c 1- | rev)
						tempjvsrt2=$(echo $tempjvsrt | sed $'s/] }, /"] },\\\n/g')
						tempjvsrt3=${tempjvsrt2::-1}
						printf "%s\n" "$tempjvsrt3"
						echo "]"
					;;
					*)
						echo "Not a valid group"
					;;
				esac
			fi
		fi
	;;	
	-d|--dumpedid)
        # Tries to convert the vero rawedid hexdump to a binary file like the pi does when it dumps the edid-data
		# else we write the rawedit-hex to textfile
		
		if [ -z $2 ]; then
			echo "You need to enter filename to dump EDID-data"
		else
            namnfil=$2
            if [ -f "$namnfil" ] | [ -d "$namnfil" ]; then
                namnfil="new."$namnfil
            fi 
            if [ -f temp.edid.txt ]; then
                rm --force temp.edid.txt
            fi

            ediddata=$(cat /sys/class/amhdmitx/amhdmitx0/rawedid)
			oLang=$LANG
			oLcAll=$LC_ALL
			LANG=C
			LC_ALL=C
			edidlen=${#ediddata}
			LANG=$oLang
			LC_ALL=$oLcAll
			if hash xxd 2>/dev/null; then
				echo $ediddata > temp.edid.txt
            	xxd -r -p temp.edid.txt $namnfil
				echo "Written $edidlen bytes to $namnfil"
			else
				echo $ediddata > $namnfil
				echo "Since xxd was not found in system, EDID will be dumped das hexdata."
				echo "Written 512 bytes of hexdata to $namnfil"
			fi
		fi
	;;
	-a)
		# Displaying aud_cap as close to rpbs tvservice layout as posible

		audcap=$(tr -d '\0' < /sys/class/amhdmitx/amhdmitx0/aud_cap )
		audcap2=$(awk 'NR != 1' <<< "$audcap")
		readarray -t ainfo <<< "$audcap2"
		for lines in "${ainfo[@]}"
		do
			acounter=$(($acounter + 1))
			IFS=',' alinfo=(${lines})
			IFS=$OLDIFS
			numchan=$(rev <<< "${alinfo[1]}" | cut -c 4- | rev)
			samprate=${alinfo[2]:(-6)}
			if [[ "${alinfo[3]}" =~ "bit" ]]; then
				sampsize="Max samplesize ${alinfo[3]:(-6)}s"
			elif [[ "${alinfo[3]}" =~ "MaxBitRate" ]]; then
				tempostr=$(cut -c 12- <<< "${alinfo[3]}")
				temppsrt=$(rev <<< "$tempostr"| cut -c 4- | rev)
				sampsize="Max rate $temppsrt kb/s"
			else
				sampsize=${alinfo[3]}
			fi
			if [[ ${#alinfo[0]} -gt 8 ]] ; then
				aline[$acounter]="${alinfo[0]} "$'\t'"supported: Max channels: $numchan, Max samplerate:  $samprate, $sampsize"
			else
				aline[$acounter]=$'\t'"${alinfo[0]} "$'\t'"supported: Max channels: $numchan, Max samplerate:  $samprate, $sampsize"
			fi
		done
		printf "%s\t\n" "${aline[@]}"

	;;
	-s)
		# List current CEA/DMT mode, with aspect, resolution, refreshrate and scanning method, the state number is still fixed

		vicm=$(resulution $pref)
		IFS=',' arr=(${vicm})
		IFS=$OLDIFS
		tvline="state 0x120009 [HDMI ${arr[7]} (${arr[0]}) RGB lim ${arr[1]}], "${arr[2]}"x"${arr[3]}" @ ${arr[4]}.00Hz, ${arr[6]}]"
		echo $tvline
	;;

	-m*)
		# List all the modes your display is capable off, divided into two groups CEA/DMT

		if [ -z $2 ]; then
			echo "You need to enter Group CEA/DMT"
		else
			if [[ "$2" =~ "CEA" ]]; then
				dispcap=$(cat /sys/class/amhdmitx/amhdmitx0/disp_cap)
				cealines=$(echo "$dispcap" | wc -l)
				echo "Group CEA has "$cealines" modes:"
				for cea in $dispcap
				do
					ccounter=$(($ccounter + 1))
					infoloop=$(resulution $cea)
					IFS=',' cinfo=(${infoloop})
					IFS=$OLDIFS
					if [[ "${cinfo[8]}" =~ "(prefer)" ]]; then
						cpost1=${cinfo[8]}
					else	
						cpost1=$'\t'
					fi					
					cmline[$ccounter]="$cpost1 mode ${cinfo[0]}: ${cinfo[2]}x${cinfo[3]} @ ${cinfo[4]}Hz ${cinfo[1]}, clock:${cinfo[5]}MHz ${cinfo[6]}"
				done
				IFS=$'\n' sorted=($(sort -V <<<"${cmline[*]}"))
				unset IFS
				printf "%s\n" "${sorted[@]}"

			elif [[ "$2" =~ "DMT" ]]; then
				vesacap=$(cat /sys/class/amhdmitx/amhdmitx0/vesa_cap)
				dmtlines=$(echo "$vesacap" | wc -l)
				echo "Group DMT has "$dmtlines" modes:"
				for dmt in $vesacap
				do
					vcounter=$(($vcounter + 1))
					vinfoloop=$(resulution $dmt)
					IFS=',' vinfo=(${vinfoloop})
					IFS=$OLDIFS
					if [[ "${vinfo[8]}" =~ "(prefer)" ]]; then
						vpost1=${vinfo[8]}
					else	
						vpost1=$'\t'
					fi	
					dmline[$vcounter]="$vpost1 mode ${vinfo[0]}: ${vinfo[2]}x${vinfo[3]} @ ${vinfo[4]}Hz ${vinfo[1]}, clock:${vinfo[5]}MHz ${vinfo[6]}"
				done
				IFS=$'\n' vsorted=($(sort -V <<<"${dmline[*]}"))
				unset IFS
				printf "%s\n" "${vsorted[@]}"
			else
				echo "Unknown group"
			fi
		fi
	;;
	-c*)
		# Not really used on Vero4k(+), unless you use the analog output in a/v-jack (3,5 mm mini jack, NOT the same pin layout as on rbp)

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
		# Sets custom CEA/DMT mode, fb-resolution and power on for HDMI
		
		if [[ -z $2 ]]; then
                        echo 'You need to set CEA/DMT mode# (tvservice -e "CEA 4")'
		else
			case $2 in
				# CEA modes
				
				"CEA 3")
					sudo sh -c 'echo 480p60hz > /sys/class/display/mode'
					fbset -g 720 480 720 960 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 4")
					sudo sh -c 'echo 720p60hz > /sys/class/display/mode'
					fbset -g 1280 720 1280 1440 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
                ;;
                "CEA 5")
					sudo sh -c 'echo 1080i60hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
				"CEA 7")
					sudo sh -c 'echo 480i60hz > /sys/class/display/mode'
					fbset -g 1440 480 1440 960 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 16")
                	sudo sh -c 'echo 1080p60hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 18")
                	sudo sh -c 'echo 576p50hz > /sys/class/display/mode'
					fbset -g 720 576 720 1152 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 19")
                	sudo sh -c 'echo 720p50hz > /sys/class/display/mode'
					fbset -g 1280 720 1280 1440 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
				"CEA 22")
                	sudo sh -c 'echo 576i50hz > /sys/class/display/mode'
					fbset -g 1440 576 1440 1152 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 31")
                	sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 32")
                	sudo sh -c 'echo 1080p24hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
                ;;
                "CEA 33")
                	sudo sh -c 'echo 1080p25hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 34")
                	sudo sh -c 'echo 1080p30hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
                ;;
                "CEA 40")
                	sudo sh -c 'echo 1080i50hz > /sys/class/display/mode'
					fbset -g 1920 1080 1920 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 89")
                	sudo sh -c 'echo 2560x1080p50hz > /sys/class/display/mode'
					fbset -g 2560 1080 2560 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 90")
                	sudo sh -c 'echo 2560x1080p60hz > /sys/class/display/mode'
					fbset -g 2560 1080 2560 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 93")
                	sudo sh -c 'echo 2160p24hz > /sys/class/display/mode'
					fbset -g 3840 2160 3840 2160 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 94")
                	sudo sh -c 'echo 2160p25hz > /sys/class/display/mode'
					fbset -g 3840 2160 3840 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
                "CEA 95")
                	sudo sh -c 'echo 2160p30hz > /sys/class/display/mode'
					fbset -g 3840 2160 3840 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
		        ;;
		        "CEA 96")
					sudo sh -c 'echo 2160p50hz > /sys/class/display/mode'
					fbset -g 3840 2160 3840 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 97")
					sudo sh -c 'echo 2160p6hz > /sys/class/display/mode'
					fbset -g 3840 2160 3840 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 98")
					sudo sh -c 'echo smpte24hz > /sys/class/display/mode'
					fbset -g 4096 2160 4096 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 99")
					sudo sh -c 'echo smpte25hz > /sys/class/display/mode'
					fbset -g 4096 2160 4096 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 100")
					sudo sh -c 'echo smpte30hz > /sys/class/display/mode'
					fbset -g 4096 2160 4096 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 101")
					sudo sh -c 'echo smpte50hz > /sys/class/display/mode'
					fbset -g 4096 2160 4096 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "CEA 102")
					sudo sh -c 'echo smpte60hz > /sys/class/display/mode'
					fbset -g 4096 2160 4096 4320 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
				# DMT modes
		        
				"DMT 4")
					sudo sh -c 'echo 640x480p60hz > /sys/class/display/mode'
					fbset -g 640 480 640 960 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 9")
					sudo sh -c 'echo 800x600p60hz > /sys/class/display/mode'
					fbset -g 800 600 800 1200 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 16")
					sudo sh -c 'echo 1024x768p60hz > /sys/class/display/mode'
					fbset -g 1024 768 1024 1536 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 21")
					sudo sh -c 'echo 1152x864p75hz > /sys/class/display/mode'
					fbset -g 1152 864 1152 1728 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 23")
					sudo sh -c 'echo 1280x768p60hz > /sys/class/display/mode'
					fbset -g 1280 768 1280 1536 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 28")
					sudo sh -c 'echo 1280x800p60hz > /sys/class/display/mode'
					fbset -g 1280 800 1280 1600 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 32")
					sudo sh -c 'echo 1280x960p60hz > /sys/class/display/mode'
					fbset -g 1280 960 1280 1920 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 35")
					sudo sh -c 'echo 1280x1024p60hz > /sys/class/display/mode'
					fbset -g 1280 1024 1280 2048 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 39")
					sudo sh -c 'echo 1360x768p60hz > /sys/class/display/mode'
					fbset -g 1360 768 1360 1536 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 81")
					sudo sh -c 'echo 1366x768p60hz > /sys/class/display/mode'
					fbset -g 1366 768 1366 1536 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 42")
					sudo sh -c 'echo 1400x1050p60hz > /sys/class/display/mode'
					fbset -g 1400 1050 1400 2100 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 47")
					sudo sh -c 'echo 1440x900p60hz > /sys/class/display/mode'
					fbset -g 1440 900 1440 1800 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 83")
					sudo sh -c 'echo 1600x900p60hz > /sys/class/display/mode'
					fbset -g 1600 900 1600 1800 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 51")
					sudo sh -c 'echo 1600x1200p60hz > /sys/class/display/mode'
					fbset -g 1600 1200 1600 2400 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 58")
					sudo sh -c 'echo 1680x1050p60hz > /sys/class/display/mode'
					fbset -g 1680 1050 1680 2100 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 69")
					sudo sh -c 'echo 1920x1200p60hz > /sys/class/display/mode'
					fbset -g 1920 1200 1920 2400 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
		        "DMT 77")
					sudo sh -c 'echo 2560x1600p60h > /sys/class/display/mode'
					fbset -g 2560 1604 2560 3200 32
					echo 1 >/sys/class/amhdmitx/amhdmitx0/phy
				;;
				*)
					echo "Not a valid mode"
				;;
			esac
		fi
	;;

	-p|--preferred)
		# Sets the displays preferred CEA/DMT mode, fb-resolution and powers on HDMI. All done via a funtion writen earlier in the code and
		# writes the
		
		setting=$(setprefered)
		echo $setting
	;;

	-n|--name)
		# Grabbs the displays Product name from EDID data and returns it to console
		dispresult=$(cat /sys/class/amhdmitx/amhdmitx0/edid | grep "Rx Product Name:"|sed 's/.*Rx Product Name: '//)
		echo "device_name="$dispresult
	;;

	*)
	# Writes command usage information if anything unknown is sent as an argument (cathes -h parameter too)
	echo "Usage: tvservice [OPTION]..."
	echo " -p, --preferred"$'\t'$'\t'"List and sets the prefered HDMI mode"
	echo " -s"$'\t'$'\t'$'\t'$'\t'"Get current GROUP and MODE, broken down to resolution and other info"
	echo " -m CEA or DMT"$'\t'$'\t'$'\t'"List all selectable MODES for selected GROUP"
	echo " -o, --off"$'\t'$'\t'$'\t'$'\t'"Power off the display,from the Vero4k(+), No Signal on your TV"
	echo " -c \"PAL/NTSC\""$'\t'$'\t'$'\t'"Sets 576p/480p 16:9"
	echo " -e \"CEA mode#\""$'\t'$'\t'$'\t'"Sets the selcted  GROUP MODE(\"\" needed)"
	echo " -a, --audio"$'\t'$'\t'$'\t'"Get supported audio information"
	echo " -n, --name"$'\t'$'\t'$'\t'"Displays your display device name(might list your AVR)."
	echo " -d, --dumpedid <filename>"$'\t'"Dumps raw-EDID data into filname of your choice."
	echo " -j, --json"$'\t'$'\t'$'\t'"Needs a second command \"-m [CEA/DEA]\"."
	echo " -h, --help"$'\t'$'\t'$'\t'"Print this information"

	;;
esac

exit
