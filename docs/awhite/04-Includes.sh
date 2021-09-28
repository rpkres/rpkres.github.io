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
local theData
local array
local argc
local tvEpisode
local tvSeason
local tvAirDate
local tvShow
local tvTitle
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


  #	Put the data into a Global called $XattrName on success
  #
  GetXattr "${iFile}"

  #	Get the attribute data string
  #
  theData=$( GetGlobalVal "${XattrName}" )

  #	Split the data into seperate array items using $Xseperator
  #
  IFS="${Xseperator}" array=(${theData[*]})
  argc=${#array[@]}

  #	Set variables based on the appropriate array index
  #
  tvEpisode="${array[0]}"	# uses day of year movie file created
  tvSeason="${array[1]}"	# uses the year of movie file created
  tvAirDate="${array[2]}"	# uses the date in UTC format for broadcast date
  tvShow="${array[3]}"		# uses defined name for TV show
  tvTitle="${array[4]}"		# uses show name+height for the episode name

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
	--TVNetwork	"NOAA"		\
	--year 		"${tvAirDate}"	\
	--title		"${tvTitle}"	\
	--storedes 	"Movie made from NOAA Satellite images."
	
}		# eo AddiTunesMetadata()

#	EOF
