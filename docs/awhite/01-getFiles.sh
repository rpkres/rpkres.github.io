#!/bin/bash

#	Files to include
#
. 00-Shared.sh			# Some funcs/vars shared by all noaa scripts
. 00-Xattr.sh			# For handling extended attributes xattr(1)
. 01-Includes.sh		# Extra funcs used by this script.
. 01-Usage.sh			# Name says it all

declare -a curlHoursArr		# A global array that we'll pre-populate 
				# formatted for curl's globbing that matchs 
				# the hours of the NOAA satellite pics 
				# which currently uses a 10 minute snapshot. 
				# This helps to request only 6 files an hour
				# compared to the 60 files curl's globbing
				# would request.

#       Globals to use in this script and the ones it includes at the top
#
#       Entries can be commented out.
#
#	Beware, that duplicate entries can be created and only the last
#	one will be returned by GetGlobalVal
#
#	There should be no space characters on either side of the seperator
#	('=') character.
#
Globals=( 

  year=			# this gets set to current year
  day=			# this gets set to current day of year if not hardcoded
  numberOfDays=1	# no. days to go back

  hourStart=0		# min 0
  hourEnd=23		# max 23

  interval=10		# NOAA current snapshot time in minutes

#  resolution="450x270"
  resolution="900x540"
#  resolution="1800x1080"
#  resolution="3600x2160"
#  resolution="7200x4320"

  execCurl=true		# whether to run curl(1)
  addMeta=true		# whether to run metadata script on downloaded files

  suffix=jpg		# file suffix of images on the NOAA server

  descPart="GOES17-ABI-np-GEOCOLOR"

  urlPathBase="https://cdn.star.nesdis.noaa.gov/GOES17/ABI/SECTOR/NP/GEOCOLOR"

  oDirPrefix=NOAA	# output directory name prefix
  oDir=${nil}		# sets to prefix-YY.mm.dd-resolution

  oNamePrefix=noaa	# out filenames prefix
  oName=		# sets to prefix.#1.#2.suffix in curl glob notation

  oPath=		# sets to oDir/oName

  theUrl=		# sets to current hour in curl notation

  curlRateLimit=2000k	# set to a reasonable bandwidth rate for downloads

  tagScript="./02-AddTags.sh"	# script to call to add metadata
  
)

#PrintGlobals

  #	main()

  #     Copy command line args and place in argv array and parse
  #
  #     Note use of IFS is set only for the following command (there's 
  #     no semicolon). In this case items are only split on \n, not
  #     spaces or tabs so the user can passed quoted strings with spaces
  #     as a single argument.
  #
  IFS=$'\n' argv=($*)
  argc=${#argv[@]}
  let cnt=($argc - 0)   # last args don't get parsed as options

  for ((i=0; i<$cnt; i++)); do

    arg="${argv[$i]}"

    case "${arg}" in
      "-am" | "--addMeta" )
	let i++
	SetGlobalVal addMeta "${argv[@]:$i:1}"
	;;
      "-d" | "--desc" )
	let i++
	SetGlobalVal descPart "${argv[@]:$i:1}"
	;;
      "-ec" | "--execCurl" )
	let i++
	SetGlobalVal execCurl "${argv[@]:$i:1}"
	;;
      "-h" | "--help"   ) Usage ;;
      "-he" | "--hourEnd" )
	let i++
	SetGlobalVal hourEnd "${argv[@]:$i:1}"
	;;
      "-hs" | "--hourStart" )
	let i++
	SetGlobalVal hourStart "${argv[@]:$i:1}"
	;;
      "-i" | "--interval" )
	let i++
	SetGlobalVal interval "${argv[@]:$i:1}"
	;;
      "-nd" | "--numberOfDays" )
	let i++
	SetGlobalVal numberOfDays "${argv[@]:$i:1}"
	;;
      "-odp" | "--outDirPrefix" )
	let i++
	SetGlobalVal oDirPrefix "${argv[@]:$i:1}"
	;;
      "-onp" | "--outNamePrefix" )
	let i++
	SetGlobalVal oNamePrefix "${argv[@]:$i:1}"
	;;
      "-od" | "--outDir" )
	let i++
	SetGlobalVal oDir "${argv[@]:$i:1}"
	;;
      "-r" | "--resolution" )
	let i++
	SetGlobalVal resolution "${argv[@]:$i:1}"
	;;
      "-rl" | "--rateLimit" )
	let i++
	SetGlobalVal curlRateLimit "${argv[@]:$i:1}"
	;;
      "-s" | "--suffix" ) 
       let i++
       SetGlobalVal suffix "${argv[@]:$i:1}"
       ;;
      "-ub" | "--urlBase" ) 
       let i++
       SetGlobalVal urlPathBase "${argv[@]:$i:1}"
       ;;
      * )
        echo -e "${Prog}. Bailing. Unrecognized option: '${arg}'."
        exit 1
    esac

  done		# eo for i

  #	CONSTRUCTING FILE NAME PART FOR CURL
  #
  #	Filename example:
  #
  #	20212531700_GOES17-ABI-np-GEOCOLOR-450x270.jpg
  #
  #	YYYYdayHour - noaa sat description - resolution - suffix
  #

  #	YEAR AND DAY PART
  #
  #	See strftime(3) for date(1) conversion specifications
  #
  #	Check to see if the year number is hard-coded in Globals, if not
  #	set it to this year. Only useful to hardcode around the new year.
  #
  theYear=$( GetGlobalVal year )

  if [ "${theYear}" == "${nil}" ]; then
    theYear=$( date +"%Y" )	# decimal year with century, e.g. 2021
  fi

  SetGlobalVal year ${theYear}		# in case it was fixed above

  #	Check to see if the day number is hard-coded in Globals, if not
  #	set it to the day of the year
  #
  theDay=$( GetGlobalVal day )

  if [ "${theDay}" == "${nil}" ]; then
    theDay=$( date +"%j" )	# decimal day of the year,   e.g. 001-366
  fi

  SetGlobalVal day ${theDay}		# in case it was fixed above


  #	How many days (1 = today) we want to go back, this is used
  #	in a globbing range which we pass to curl.
  #
  #	I've seen big jumps of missing pics, so going back several days
  #	doesn't guarantee a smooth animation.
  #
  #	Check to see if theNumberOfDays is hard-coded in Globals, if not
  #	set it to 1
  #
  theNumberOfDays=$( GetGlobalVal numberOfDays )

  if [ "${theNumberOfDays}" == "${nil}" ]; then
    theNumberOfDays=1
  fi
  SetGlobalVal numberOfDays $theNumberOfDays	# in case it was fixed

  #	Use bc(1) to calc the first day as bash won't do math operations
  #	on strings.
  #	These vars will be used to generate a globbed range in curl notation
  #
  firstDay=$( echo "$theDay - $theNumberOfDays + 1" | bc -l)
  lastDay=$theDay

  #	Save the days in case we need them elsewere
#  SetGlobalVal firstDay ${firstDay}
#  SetGlobalVal lastDay ${lastDay}

  #	curl will glob the range in the brackets.
  #
  #	globbing order can be referenced for output filenames by their
  #	number: #1, #2 etc. This script constructs the curl output
  #	filenname this way and so the day will be referenced by #1 as 
  #	it's the first glob.
  #
  #
  dayRange=$( printf "[%.3d-%.3d]" $firstDay $lastDay )

  SetGlobalVal dayRange "${dayRange}"
#echo "dayRange: '${dayRange}'"

  #	HOURS PART
  #
  #	We're interesting in *all* of the images for the given hours/mins
  #	for the given days. Once again, I'm assuming the hours are zero
  #	padded like the day range above. So change the printf format if not.
  #
  #	Note that you can add a step value to curl. e.g.
  #
  #		[0-100:2].jpg
  #
  #	would grab every second image, it would be a pain to work something
  #	out with the 10 min intervals of the satellite images though.
  #
  #	You can do alphabetical and list ranges, but they're not much 
  #	use in this case. e.g.
  #
  #		section[a-z].html
  #		http://example.com/{one,two,three,alpha,beta}.html
  #
  #	Any of the above methods can also be combined. e.g.
  #
  #	http://example.com/{Ben,Alice,Frank}-{100x100,1000x1000}.jpg
  #
  hourStart=$( GetGlobalVal hourStart )

  if [ "${hourStart}" == "${nil}" ]; then
    echo "Warning. Setting hourStart to 0, was '${hourStart}'"
    hourStart=0
  fi
  hs=$( printf "%.0f" ${hourStart} )	# cast to int for check

  if [ $hs -lt 0 ]; then
    echo "Warning. Setting hourStart to 0, was '${hourStart}'"
    hourStart=0
    SetGlobalVal hourStart $hourStart
  fi

  #	Hour end
  #
  hourEnd=$( GetGlobalVal hourEnd )

  if [ "${hourEnd}" == "${nil}" ]; then
    echo "Warning. Setting hourEnd to 23, was '${hourEnd}'"
    hourEnd=23
  fi
  he=$( printf "%.0f" ${hourEnd} )	# cast to int for check

  if [ $he -gt 23 ]; then
    echo "Warning. Setting hourEnd to 23, was '${hourEnd}'"
    hourEnd=23
    SetGlobalVal hourEnd $hourEnd	
  fi

  #	Check hourStart <= hourEnd
  if [ $hs -gt $he ]; then
    echo "Bailing. hourStart is greater than hourEnd."
    exit 1
  fi

  #	Check the interval values, this gets used in PrbuildHoursArray
  #	for constructing the curl glob range
  #
  minsInterval=$( GetGlobalVal interval )

  if [ "${minsInterval}" == "${nil}" ]; then
    minsInterval=10
  fi
  tmpI=$( printf "%.0f" ${minsInterval} )	# cast to int for check

  if [ $tmpI -lt 0 ]; then
    echo "Setting snapshot minute interval to 0, was '${minsInterval}'"
    minsInterval=0
  fi
  if [ $tmpI -gt 30 ]; then
    echo "Setting snapshot minute interval to 30, was '${minsInterval}'"
    minsInterval=30
  fi
  SetGlobalVal interval $minsInterval	# in case it had to be fixed above

  #	This formats in curls globbed pattern for each of 24 hours as 
  #	we'll run curl in a loop from $hourStart to $hourEnd below
  #	and the interval in minutes
  #
  PrebuildHoursArray 


  #	DESCRIPTION PART
  #
  #	The description part of the name, this will vary depending on
  #	which satellite and the kind of renderings being used.
  #
#  descPart="GOES17-ABI-np-GEOCOLOR"

  descPart=$( GetGlobalVal descPart )

  if [ "${descPart}" == "${nil}" ]; then
    echo "Bailing. Missing from Globals: 'descPart'"
    exit 1
  fi

  #	The resolution, maybe test with lower-res, these are different based
  #	on which sector you're downloading.
  #
  resolution=$( GetGlobalVal resolution )

  if [ "${resolution}" == "${nil}" ]; then
    echo "Bailing. Missing from Globals: 'resolution'"
    exit 1
  fi
  

  #	OUTPUT PART
  #
  #	Set your output path here. curl is flaggerd to create the output 
  #	dir if it doesn't exist rather than create it. However, we'll test
  #	to see if the directory part exists, if so we'll increment up so
  #	as to not accidentaly overwrite already downloaded files.
  #
  #	Base the dir name on *todays* date and the resolution, which will
  #	make it easier to parse for creating a gif later.
  #
  oDirPrefix=$( GetGlobalVal oDirPrefix )

  if [ "${oDirPrefix}" == "${nil}" ]; then
    oDirPrefix="NOAA"
    SetGlobalVal oDirPrefix $oDirPrefix		# store it
  fi


  oDir=$( GetGlobalVal oDir )

  #	If the user didn't override via the command line, set a default
  #
  if [ "${oDir}" == "${nil}" ]; then
#  oDate=$( date +"%Y.%m.%d" )			# set to today's yymmdd
#    oDir="${oDirPrefix}-${oDate}-${resolution}"
    oDir="${oDirPrefix}-${dayRange}-${resolution}"
    SetGlobalVal oDir $oDir
  fi

  #	Create the output directory and store some extended attributes
  #	in it.
  #
  if [ ! -d "${oDir}" ]; then
    mkdir -p "${oDir}"
  fi

  #	Create, 
  #
  theData="${firstDay}${Xseperator}${lastDay}${Xseperator}${oDir}"

  SetGlobalVal $XattrNameForDir "${theData}"

  UpdateDirXattrData $XattrNameForDir "${oDir}"


  #	If the output dir exists, append a higher, padded number (up to 10)
  #	and use that instead.
  #
  #	This might be redundant now due to adding the metadata script 
  #	execution, so I might remove it.
  #
#  if [ -d "${oDir}" ]; then
#
#    for ((i=1; i <= 10; i++)); do
#
#      newName=$( printf "${oDir}-%.2d" $i)
#
#      if [ ! -d "${newName}" ]; then
#        oDir="${newName}"
#        break				# will break out of for loop
#      fi
#
#    done		# eo for i
#  fi		# eo if -d


  #	Image file suffix on noaa servers
  #
  suffix=$( GetGlobalVal suffix )

  if [ "${suffix}" == "${nil}" ]; then
    echo "Bailing. Missing from Globals: 'suffix'"
    exit 1
  fi

  #	This has curl(1) use the first and second globbing we 
  #	defined	in the output name referenced by #1 and #2
  #
  #	So the individual file names will be something like (zezo padded):
  #
  #		noaa.DAY.HOUR.suffix
  #
  oNamePrefix=$( GetGlobalVal oNamePrefix )

  if [ "${oNamePrefix}" == "${nil}" ]; then
    oDirPrefix="noaa"
  fi
  SetGlobalVal oNamePrefix $oNamePrefix		# in case it had to be fixed

  oName="${oNamePrefix}.#1.#2.${suffix}"

  SetGlobalVal oName "${oName}"

  #	Full output path format including the directory in curl format
  #
  oPath="${oDir}/${oName}"

  SetGlobalVal oPath "${oPath}"

  #	Call the function to print some info
  #
#  PrintGlobals

  #	sequentially run up to 24 instances of curl
  #	  	each instance currently runs 6 times to match 10 min snapshots
  #
  #	Put all the image name parts together in a format curl will parse.
  #
  urlPathBase=$( GetGlobalVal urlPathBase )

  for ((hour=$hourStart; hour <= $hourEnd; hour++ ))
  do

    hoursRange="${curlHoursArr[$hour]}"

    urlFilePart="${theYear}${dayRange}${hoursRange}"
    urlFilePart+="_${descPart}-${resolution}.${suffix}"

    theUrl="${urlPathBase}/${urlFilePart}"

    SetGlobalVal theUrl "${theUrl}"

    RunCurl

  done


  #	If there's no outDir, no need to run the metadata script
  #
  if [ ! -d "${oDir}" ]; then
    echo -e "Exiting. No such directory: '${oDir}'"
    exit 0
  fi

  addMeta=$( GetGlobalVal addMeta )

  #     If the variable 'addMeta' is not set, just exit 0.
  #
  if [ "${addMeta}" != "true" ]; then
    echo -e "Exiting. Not adding metadata to the downloaded files,"
    echo -e "Global addMeta isn't set to 'true'"
    exit 0
  fi

  tagScript=$( GetGlobalVal tagScript )

  if [ "${tagScript}" == "${nil}" ]; then
    echo -e "Set tagScript in Global array to add metadata to downloads."
    exit 0
  fi

  #	Check that the metadata script exists and is executable
  #
  if [ ! -x "${tagScript}" ]; then
    echo -e "Metadata script missing or not executable: '${tagScript}'."
    exit 1
  fi

  #	If we got this far, run the script that generates metadata on the files
  #	in $oDir
  #
  "${tagScript}" --suffix ${suffix} "${oDir}"

exit 0
