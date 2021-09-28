#!/bin/bash

# See this link for persistence settings and xattr(1)
#
# https://eclecticlight.co/2020/11/02/controlling-metadata-tricks-with-persistence/
#
#
# See this HN thread on naming a home lan domain:
#
# apparently '.home.arpa' is the way to go, not '.local', '.lan', '.home' etc.
#
#	https://news.ycombinator.com/item?id=28340216

XattrName="arpa.home.noaapics"	# used for extended attributes via xattr(1)
				# also used as a Globals entry

XattrName+="#PCS"		# so attributes don't get removed by the OS

XattrShowName="NOAA Pics"

Xseperator=";"			# char to seperate the items stored

#	Get the data associated with the $XattrName (if it exists) and
#	set a Global with the name as the key and the attriubte data as
#	the value.
#
#	Currently using 5 items in the data string:
#
#		episode, season, release/air date, TV show, episode title
#
#		dayOfYear, year, date(utc), show name, episode title
#
#

GetXattr()
{
local theFile="${1}"
local sep="${Xseperator}"			# for brevity
local theData
local arr
local argc
local func="${FUNCNAME}()"

  if [ ! -f "${theFile}" ]; then
    echo -e "${func} Bailing. No such file: '${theFile}'"
    exit 1
  fi

  theData=$( xattr -p "${XattrName}" "${theFile}")

  status=$?
  if [ ${status} -ne 0 ]; then
    echo -e "${func} Bailing. Bad status return from xattr(1): '${status}'."
    exit 1
  fi

  #	fields are seperated with whatever $Xseperator is set to
  #	Check number of items is correct.
  #
  IFS="${Xseperator}" arr=(${theData[*]})
  argc=${#arr[@]}

  if [ ${argc} -ne 5 ]; then
    echo -e "${func} Bailing. Expecting 5 items, but there's '${argc}'"
    exit 1
  fi

  SetGlobalVal "${XattrName}" "${theData}"

  return 0
}		# eo GetXattr()

AddXattr()
{
local theFile="${1}"
local sep="${Xseperator}"		# for brevity
local theData
local func="${FUNCNAME}()"

  if [ ! -f "${theFile}" ]; then
    echo -e "${func} Returning. No such file: '${theFile}'"
    return 1
  fi

  local theHeight=$( GetGlobalVal outHeight )

  if [ "${theHeight}" == "${nil}" ]; then
    theHeight="unknown"
  fi

  local dayOfYear=$(date +"%j")	# will be used for 'TV episode'
#  local theYear=$(date +"%Y")		# will be used for 'TV season'
  local theYear=$(date +"%g")		# will be used for 'TV season'
  local theDate=$(date -u)		# will be used for 'TV air date'

  local theShow="${XattrShowName}"	# will be used for 'TV Show'
#  local theTitle="${XattrShowName}-${oHeight}"	# will be used for 'Episode Name'
  local theTitle="${theFile//.mp4/}"

  #	How the data is stored in the attribute - the $Xseperator character
  #	is used as a seperator, if an item includes the same character I've
  #	no idea if it'll fuck things up.
  #
   theData="${dayOfYear}${Xseperator}"
  theData+="${theYear}${Xseperator}"
  theData+="${theDate}${Xseperator}"
  theData+="${theShow}${Xseperator}"
  theData+="${theTitle}"

  #	Write the metadata as ascii text string (-w)
  #
  xattr -w "${XattrName}" "${theData}" "${theFile}"

  status=$?
  if [ ${status} -ne 0 ]; then
    echo -e "${func} Bailing. Bad status return from xattr(1): '${status}'."
    exit 1
  fi

  #	Just for the fuck of it
  #
  SetGlobalVal "${XattrName}" "${theData}"

  return 0

}		# eo AddXattr()


#	EOF
