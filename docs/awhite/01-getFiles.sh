#!/bin/bash

#	Files to include
#
. 00-Shared.sh			# Some funcs/vars shared by all noaa scripts
. 01-Includes.sh		# Extra funcs used by this script.

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
#day=261		# hardcode to a specific day of the year
  numberOfDays=1	# no. days to go back

  hourStart=0		# min 0
  hourEnd=23		# max 23

  interval=10		# NOAA current snapshot time in minutes

#  resolution="450x270"
#  resolution="900x540"
  resolution="1800x1080"
#  resolution="3600x2160"
#  resolution="7200x4320"

  execCurl=1		# whether to run curl(1)
  addTags=1		# whether to run metadata script on downloaded files

  suffix=jpg		# file suffix of images on the NOAA server

  descPart="GOES17-ABI-np-GEOCOLOR"

  urlPathBase="https://cdn.star.nesdis.noaa.gov/GOES17/ABI/SECTOR/NP/GEOCOLOR"

  oDirPrefix=NOAA	# output directory name prefix
  oDir=			# gets set to prefix-YY.mm.dd-resolution

  oNamePrefix=noaa	# out filenames prefix
  oName=		# gets set to prefix.#1.#2.suffix in curl glob notation

  oPath=		# gets set to oDir/oName

  theUrl=		# gets set to current hour in curl notation

  curlLimitRate=1200k	# sets a reasonable bandwidth rate for downloads

  tagScript="./02-AddTags.sh"	# script to call to add metadata
  
)

#PrintGlobals

  #	main()


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

  #	curl will glob the range in the brackets.
  #
  #	globbing order can be referenced for output filenames by their
  #	number: #1, #2 etc. This script constructs the curl output
  #	filenname this way and so the day will be referenced by #1 as 
  #	it's the first glob.
  #
  #
  dayRange=$( printf "[%.3d-%.3d]" $firstDay $lastDay )

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
  if [ $hourStart -lt 0 ]; then
    echo "Warning. Setting hourStart to 0, was '${hourStart}'"
    hourStart=0
  fi
  SetGlobalVal hourStart $hourStart	# in case it had to be fixed above

  #	Hour end
  #
  hourEnd=$( GetGlobalVal hourEnd )

  if [ "${hourEnd}" == "${nil}" ]; then
    echo "Warning. Setting hourEnd to 23, was '${hourEnd}'"
    hourEnd=23
  fi
  if [ $hourEnd -gt 23 ]; then
    echo "Warning. Setting hourEnd to 23, was '${hourEnd}'"
    hourEnd=23
  fi
  SetGlobalVal hourEnd $hourEnd		# in case it had to be fixed above

  #	Check the interval values, this gets used in PrbuildHoursArray
  #	for constructing the curl glob range
  #
  minsInterval=$( GetGlobalVal interval )

  if [ "${minsInterval}" == "${nil}" ]; then
    minsInterval=10
  fi
  if [ $minsInterval -lt 0 ]; then
    echo "Setting snapshot minute interval to 0, was '${minsInterval}'"
    minsInterval=0
  fi
  if [ $minsInterval -gt 30 ]; then
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
  fi
  SetGlobalVal oDirPrefix $oDirPrefix		# in case it had to be fixed

  oDate=$( date +"%Y.%m.%d" )			# set to today's yymmdd
  oDir="${oDirPrefix}-${oDate}-${resolution}"

  SetGlobalVal oDir $oDir

  #	If the output dir exists, append a higher, padded number (up to 10)
  #	and use that instead.
  #
  #	This might be redundant now due to adding the metadata script 
  #	execution, so I might remove it.
  #
  if [ -d "${oDir}" ]; then

    for ((i=1; i <= 10; i++)); do

      newName=$( printf "${oDir}-%.2d" $i)

      if [ ! -d "${newName}" ]; then
        oDir="${newName}"
        break				# will break out of for loop
      fi

    done		# eo for i
  fi		# eo if -d


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


  addTags=$( GetGlobalVal addTags )

  #     If the variable 'addTags' is not set, just exit 0.
  #
  if [ "${addTags}" != "1" ]; then
    echo -e "Not adding tags to the downloaded files, addTags needs to be 1"
    exit 0
  fi

  tagScript=$( GetGlobalVal tagScript )

  if [ "${tagScript}" == "${nil}" ]; then
    echo -e "Set tagScript in Global array to add memtadata to downloads."
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
#  "${tagScript}" --suffix ${suffix} "${oDir}"

exit 0
