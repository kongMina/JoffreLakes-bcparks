#!/bin/bash

####
# Simple script to receive notification about available one-day-passes on Joffre Lake, BC, Canada
#
# Helping to get them as soon as they will be available, because:
# 1) even website saying that "Passes can be booked starting at 7:00am, 
# two days in advance of your planned visit." - this is not correct... 
# passes appearing around 1:30 am and by 7:01am they are already gone
#
# 2) if somebody cancelled their passes - they are appearing online, 
# but during the day they booked out in less then 20 seconds and at night
# they can be available for more then 10 minutes - so, prepare autofill for 
# information and keep webside https://reserve.bcparks.ca/dayuse/registration 
# ready to be refreshed
####

############### HELP #############
# help message in case of something
help()
{
	echo "Usage: JoffreLakes.sh [ -d | --day ] [ -s | --secondday ] [ -p | --park ] [ -t | --time ] [ -h | --help ]

			-d | --day:
				by default is 2 days ahead ($(date_plus_days 2))
				day when you are looking for tickets
				expecting YYYY-MM-DD format

			-s | --secondday:
				by default empty
				second day when you are okay to get tickets
				expecting YYYY-MM-DD format

			-t | --time:
				by default empty (beep for either slot opening up)
				only applies to parks with separate AM/PM passes (Golden-South, Golden-Gold)
				AM - only beep when the morning slot opens up
				PM - only beep when the afternoon slot opens up

			-p | --park:
				by defaul Joffre - since it's the only park where you need ticket per person, not per car

				Choose your park out of available options:
				1) Joffre - for Joffre Lakes
				2) Garibaldi-Diamond - for Diamond Head in Garibaldi Provincial Park
				3) Garibaldi-Rubble - for Rubble Creek in Garibaldi Provincial Park
				4) Garibaldi-Cheakamus - not supported yet, due to morning and evening options
				5) Golden-Boat - for Alouette Lake Boat Launch Parking in Golden Ears Provincial Park
				6) Golden-South - for Alouette Lake South Beach Day-Use Parking Lot in Golden Ears Provincial Park
				7) Golden-Gold - for Gold Creek Parking Lot in Golden Ears Provincial Park
				8) Golden-West - not supported, due to morning and evening options

			-h | --help:
				show this help message

		Example:
			search for tickets on Garibaldi-Diamond for September 2nd and 3rd:
			$ ./JoffreLakes.sh -d2023-09-02 -s2023-09-03 -p2
			"
	exit 2
}

############### PLATFORM #############
# macOS ships BSD date (no -d) and plain BSD getopt (no long options), and has
# no 'beep' command at all. Detect what's actually here once, up front.
if date -v+1d >/dev/null 2>&1
then
	IS_BSD_DATE=1
else
	IS_BSD_DATE=0
fi

# $1 = number of days from today, formatted YYYY-MM-DD
date_plus_days()
{
	if [ "$IS_BSD_DATE" = "1" ]
	then
		date -v+"$1"d +%F
	else
		date -d "+$1 days" +%F
	fi
}

# $1 = date string in YYYY-MM-DD to validate
date_is_valid()
{
	if [ "$IS_BSD_DATE" = "1" ]
	then
		date -j -f "%Y-%m-%d" "$1" >/dev/null
	else
		date -d "$1" >/dev/null
	fi
}

# only shim 'beep' if there's no real one already on the PATH (checked before
# we define our own function below, so this can't just find itself)
if ! command -v beep >/dev/null 2>&1
then
	beep()
	{
		if command -v osascript >/dev/null 2>&1
		then
			osascript -e 'beep 2' >/dev/null 2>&1
		elif command -v afplay >/dev/null 2>&1
		then
			afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1
		fi
	}
fi

############### ARGS #############
# getting and checking parameters
# (parsed manually - macOS/BSD getopt has no GNU long-option support)
while [ $# -gt 0 ]
do
	case "$1" in
		--day=*)
			DATE="${1#--day=}"
			shift
			;;
		--day)
			DATE="$2"
			shift 2
			;;
		-d*)
			DATE="${1#-d}"
			shift
			;;
		--secondday=*)
			DATE2="${1#--secondday=}"
			shift
			;;
		--secondday)
			DATE2="$2"
			shift 2
			;;
		-s*)
			DATE2="${1#-s}"
			shift
			;;
		--park=*)
			PARK="${1#--park=}"
			shift
			;;
		--park)
			PARK="$2"
			shift 2
			;;
		-p*)
			PARK="${1#-p}"
			shift
			;;
		--time=*)
			TIME_FILTER="${1#--time=}"
			shift
			;;
		--time)
			TIME_FILTER="$2"
			shift 2
			;;
		-t*)
			TIME_FILTER="${1#-t}"
			shift
			;;
		-h | --help)
			help
			;;
		*)
			echo "Unexpected option: $1"
			help
			;;
	esac
done

if [ -n "$TIME_FILTER" ] && [ "$TIME_FILTER" != "AM" ] && [ "$TIME_FILTER" != "PM" ]
then
	echo "Expected -t/--time to be AM or PM (${TIME_FILTER})"
	exit 1
fi

############### DATE #############
## checking and confirming date value
if [ -z "$DATE" ]
then
	#by default 2 days ahead
	DATE=$(date_plus_days 2)
elif ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
then
	echo "Expected date in YYYY-MM-DD format (${DATE})"
	exit 1
elif ! date_is_valid "$DATE"
then
	echo "Incorrect date specified: $DATE"
	exit 1
fi

if [ -z "$DATE2" ]
then
	#no default value
	DATE2=
elif ! [[ "$DATE2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
then
	echo "Expected date in YYYY-MM-DD format (${DATE2})"
	exit 1
elif ! date_is_valid "$DATE2"
then
	echo "Incorrect date specified: $DATE2"
	exit 1
fi

############### PARK #############
## checking and confirming park value
## got them based on API request here: https://reserve.bcparks.ca/dayuse/
HEADERS="-H 'sec-ch-ua: \"Google Chrome\";v=\"117\", \"Not;A=Brand\";v=\"8\", \"Chromium\";v=\"117\"'   -H 'Accept: application/json, text/plain, */*'   -H 'Referer: https://reserve.bcparks.ca/'   -H 'sec-ch-ua-mobile: ?0'   -H 'User-Agent: Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36'   -H 'sec-ch-ua-platform: \"Chrome OS\"'   --compressed"
URL_BASE="https://reserve.bcparks.ca/api/reservation?"

case "$PARK" in
	"" | 1 | "Joffre" ) 
		PARK_NAME="Joffre Lakes"
		URL="${URL_BASE}facility=Joffre%20Lakes&park=0363"
		Response='{ "2023-08-10": { "DAY": { "capacity": "Full", "max": 0 } }, "2023-08-11": { "DAY": { "capacity": "Full", "max": 0 } }, "2023-08-12": { "DAY": { "capacity": "Full", "max": 0 } } }'
		;;

	2 | "Garibaldi-Diamond" ) 
		PARK_NAME="Garibaldi Provincial Park - Diamond Head"
		URL="${URL_BASE}facility=Diamond%20Head&park=0007"
		Response='{ "2023-08-10": { "DAY": { "capacity": "Low", "max": 1 } }, "2023-08-11": { "DAY": { "capacity": "Full", "max": 0 } }, "2023-08-12": { "DAY": { "capacity": "Full", "max": 0 } } }'
		;;

	3 | "Garibaldi-Rubble" ) 
		PARK_NAME="Garibaldi Provincial Park - Rubble Creek"
		URL="${URL_BASE}facility=Rubble%20Creek&park=0007"
		Response='{ "2023-08-10": { "DAY": { "capacity": "Low", "max": 1 } }, "2023-08-11": { "DAY": { "capacity": "Full", "max": 0 } }, "2023-08-12": { "DAY": { "capacity": "Full", "max": 0 } } }'
		;;

	4 | "Garibaldi-Cheakamus" )
		PARK_NAME="Garibaldi Provincial Park - Cheakamus"
		URL="${URL_BASE}facility=Cheakamus&park=0007"
		Responce='{ "2023-08-10": { "AM": { "capacity": "Low", "max": 1 }, "PM": { "capacity": "Full", "max": 0 } }, "2023-08-11": { "AM": { "capacity": "Low", "max": 1 }, "PM": { "capacity": "Low", "max": 1 } }, "2023-08-12": { "AM": { "capacity": "Full", "max": 0 }, "PM": { "capacity": "Full", "max": 0 } } }'
		echo "Sorry, ${PARK_NAME} is not supported yet."
		exit 2
		;;

	5 | "Golden-Boat" ) 
		PARK_NAME="Golden Ears Provincial Park - Alouette Lake Boat Launch Parking - Parking "
		URL="${URL_BASE}facility=Alouette%20Lake%20Boat%20Launch%20Parking&park=0008"
		Response='{"2023-08-10":{"DAY":{"capacity":"Moderate","max":1}},"2023-08-11":{"DAY":{"capacity":"Low","max":1}},"2023-08-12":{"DAY":{"capacity":"Full","max":0}}}'
		;;

	6 | "Golden-South" )
		PARK_NAME="Golden Ears Provincial Park - Alouette Lake South Beach Day-Use Parking Lot - Parking "
		URL="${URL_BASE}facility=Alouette%20Lake%20South%20Beach%20Day-Use%20Parking%20Lot&park=0008"
		Response='{"2023-08-10":{"AM":{"capacity":"High","max":1},"PM":{"capacity":"Moderate","max":1}},"2023-08-11":{"AM":{"capacity":"High","max":1},"PM":{"capacity":"Moderate","max":1}},"2023-08-12":{"AM":{"capacity":"Low","max":1},"PM":{"capacity":"Full","max":0}}}'
		SLOT_TYPE="AMPM"
		;;

	7 | "Golden-Gold" )
		PARK_NAME="Golden Ears Provincial Park - Gold Creek Parking Lot - Parking "
		URL="${URL_BASE}facility=Gold%20Creek%20Parking%20Lot&park=0008"
		Response='{"2023-08-10":{"AM":{"capacity":"Moderate","max":1},"PM":{"capacity":"Full","max":0}},"2023-08-11":{"AM":{"capacity":"Low","max":1},"PM":{"capacity":"Full","max":0}},"2023-08-12":{"AM":{"capacity":"Full","max":0},"PM":{"capacity":"Full","max":0}}}'
		SLOT_TYPE="AMPM"
		;;

	8 | "Golden-West" )
		PARK_NAME="Golden Ears Provincial Park - West Canyon Trailhead Parking Lot - Parking "
		URL="${URL_BASE}facility=West%20Canyon%20Trailhead%20Parking%20Lot&park=0008"
		Response='{"2023-08-10":{"AM":{"capacity":"Moderate","max":1},"PM":{"capacity":"Full","max":0}},"2023-08-11":{"AM":{"capacity":"Low","max":1},"PM":{"capacity":"Full","max":0}},"2023-08-12":{"AM":{"capacity":"Full","max":0},"PM":{"capacity":"Full","max":0}}}'
		echo "Sorry, ${PARK_NAME} is not supported yet."
		exit 2
		;;

	*)
		echo "Unexpected park has been specified: ${PARK}"
		exit 2
		;;
esac

############### MATCH #############
## checking whether the last log line shows a "Low" (just-opened) capacity for a given date
## DAY-slot parks (Joffre, Diamond Head, Rubble Creek, Boat Launch): single all-day slot
## AMPM-slot parks (South Beach, Gold Creek): separate AM/PM slots
##   - TIME_FILTER=AM/PM restricts to just that slot; unset beeps if either opens up
check_low()
{
	local check_date=$1
	local line=$(tail -1 $LOG)

	if [ "$SLOT_TYPE" = "AMPM" ]; then
		case "$TIME_FILTER" in
			AM)
				echo "$line" | grep -E "\"${check_date}\":\{\"AM\":\{\"capacity\":\"Low\"" > /dev/null
				;;
			PM)
				echo "$line" | grep -E "\"${check_date}\":\{\"AM\":\{[^}]*\},\"PM\":\{\"capacity\":\"Low\"" > /dev/null
				;;
			*)
				echo "$line" | grep -E "\"${check_date}\":\{\"AM\":\{\"capacity\":\"Low\"|\"${check_date}\":\{\"AM\":\{[^}]*\},\"PM\":\{\"capacity\":\"Low\"" > /dev/null
				;;
		esac
	else
		echo "$line" | grep "\"${check_date}\":{\"DAY\":{\"capacity\":\"Low\"" > /dev/null
	fi
}

############### MAIN #############

LOG=${LOG:-log.txt}

echo "CHECKING PASSES FOR:
		DATE(S): ${DATE} ${DATE2}
		PARK: ${PARK_NAME}

	Please CTRL+C when you want to stop the script
	"

echo "Checking beep command..."
beep
echo "if you didn't hear a beep sound, please check your speakers and try to run 'beep' command in your console.
	"

while true; do
	echo curl \'$URL\' $HEADERS | bash 2>/dev/null | tee -a $LOG
	echo -n ",${PARK_NAME}," | tee -a $LOG
	date | tee -a $LOG
	
	check_low "$DATE" && echo "Found passes for $DATE !!!" && beep
	[ ! -z "$DATE2" ] && check_low "$DATE2" && echo "Found passes for $DATE2 !!!" && beep
	
	sleep 5
done
