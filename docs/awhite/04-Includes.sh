#!/bin/bash

Usage()
{
#local suffix=$( GetGlobalVal suffix )
#local metaKey=$( GetGlobalVal metaKey )

# -s, --suffix <string>	Set the suffix to <string> (default '${suffix}').

cat <<EOD

Usage: ${Prog} [option] movie

	-h, --help		Prints this message and exits.

	${Prog} attempts to derive certain metadata values from the
	input movie file's extended attributes using xattr(1).

	If sucessful the attributes will be used to set iTunes compatible
	metadata values via *AtomicParsley on the movie file:
	
	    kind:		    TV Show
	    show name:		    $XattrShowName
	    episode title:	    $XattrShowName + movie height
	    episode number:	    day of the year created
	    series number:	    the year created
	    broadcast/air date:	    creation time of movie file in UTC

	*AtomicParsley must be installed and in your path in order to run.

EOD

exit 1

}		# eo Usage()

AddiTunesMetadata()
{
local iFile="${1}"
local appName="AtomicParsley"
local appPath
local dirData
local dirArray
local dirArgc
local vidData
local vidArray
local vidArgc
local tvEpisode
local tvSeason
local tvAirDate
local tvShow
local tvTitle
local longDesc
local storeDesc
local func="${FUNCNAME}()"

  echo "${Dash}"
  echo -e "${func}\n"

  if [ ! -f "${iFile}" ]; then
    echo "Bailing. Can't access file: '${iFile}'"
    exit 1
  fi

  #	Check that AtomicParsley is in our path
  #
  appPath=$( command -v "${appName}" )
  status=$?

  if [ $status -ne 0 ]; then
    echo -e "${func} Bailing. command can't locate '${appName}'"
    exit 1
  fi

  #	Make copy of current directory extended attibutes as AtomicParsley
  #	seems to blow it away. This routine makes a global with the
  #	attribute name and stores a value associated with it.
  #
  ReadXattrData "${XattrNameForDir}" "${iFile}"
  dirData=$( GetGlobalVal "${XattrNameForDir}" )

  #	Split the data into seperate array items using $Xseperator
  #	and use the source directory name in the store description string.
  #
  IFS="${Xseperator}" dirArray=(${dirData[*]})
  dirArgc=${#dirArray[@]}

  #	Could do a better job of determining path and adding it here
  #

   storeDesc="Movie made from individual NOAA satellite images "
  storeDesc+="downloaded to directory: ${dirArray[2]}"

  #	iTunes often truncates the description metadata tag, so store it for
  #	use in the longDesc
  #
  longDesc=$( ffprobe -v 0 -hide_banner -show_entries format_tags=description -of default=noprint_wrappers=1:nokey=1 "${iFile}" )

  if [ "${longDesc}" == "" ]; then longDesc="N/A"; fi


  #	Make copy of current video extended attibutes as AtomicParsley
  #	seems to blow it away. This routine makes a global with the
  #	attribute name and stores a value associated with it.
  #
  ReadXattrData "${XattrNameForVideo}" "${iFile}"
  vidData=$( GetGlobalVal "${XattrNameForVideo}" )

  #	Split the data into seperate array items using $Xseperator
  #
  IFS="${Xseperator}" vidArray=(${vidData[*]})
  vidArgc=${#vidArray[@]}

  #	Set variables based on the appropriate array index
  #
  tvEpisode="${vidArray[0]}"	# uses day of year movie file created
  tvSeason="${vidArray[1]}"	# uses the year of movie file created
  tvAirDate="${vidArray[2]}"	# uses the date in UTC format for broadcast date
  tvShow="${vidArray[3]}"	# uses defined name for TV show
  tvTitle="${vidArray[4]}"	# uses show name+height for the episode name

  tvEpisodeID="${tvSeason}|${tvEpisode}"

  #	Update the Global values with the data in case we want to print it
  #
  SetGlobalVal tvEpisode "${tvEpisode}"
  SetGlobalVal tvSeason  "${tvSeason}"
  SetGlobalVal tvAirDate "${tvAirDate}"
  SetGlobalVal tvShow    "${tvShow}"
  SetGlobalVal tvTitle   "${tvTitle}"

  AtomicParsley "${iFile}"		\
	--freefree			\
	--overWrite			\
	--stik 		"TV Show"	\
	--TVShowName 	"${tvShow}"	\
	--TVSeasonNum	"${tvSeason}"	\
	--TVEpisodeNum	"${tvEpisode}"	\
	--TVEpisode	"${tvEpisodeID}" \
	--TVNetwork	"NOAA"		\
	--year 		"${tvAirDate}"	\
	--title		"${tvTitle}"	\
	--longdesc	"${longDesc}"	\
	--storedes 	"${storeDesc}"	

  #	Atomic parsley seems to strip the extended attriutes, so we
  #	need to add them back again.
  #
  SetGlobalVal "${XattrNameForDir}"   "${dirData}"
  SetGlobalVal "${XattrNameForVideo}" "${vidData}"

  WriteXattrData "${XattrNameForDir}"   "${iFile}"
  WriteXattrData "${XattrNameForVideo}" "${iFile}"
	
}		# eo AddiTunesMetadata()

#	EOF
