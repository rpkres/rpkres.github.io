#!/bin/bash

#	From the man page for xattr(1) usage. 
#
#	"Extended attributes are arbitrary metadata stored with a file, 
#	but separate from the filesystem attributes (such as modification 
#	time or file size). The metadata is often a null-terminated UTF-8 
#	string, but can also be arbitrary binary data."
#
#
#	Extended attributes are used extensively in MacOS, and Linux 
#	(not sure about Windows).
#
#
#	There's a couple of ways to check extended attributes from the
#	command line, one is ls(1) in long mode:
#
#		\ls -ld@        dirname
#		\ls -l@         filename
#
#	The other is using the xattr(1) system command, which is actually
#	a python script (so takes 10x longer than bash to fire up):
#
#		xattr -l        dirname
#		xattr -l        filename
#
#
#	See this link for persistence settings and xattr(1)
#
# https://eclecticlight.co/2020/11/02/controlling-metadata-tricks-with-persistence/
#
#
#	See this HN thread on naming a home lan domain:
#
#	apparently '.home.arpa' is the way to go, 
#	not '.local', '.lan', '.home' etc.
#
#	https://news.ycombinator.com/item?id=28340216
#

XattrBase="arpa.home.noaapics"	# used to construct the attr_name
				# also used as a Globals entry

XattrNameForVideo="${XattrBase}.video"
XattrNameForDir="${XattrBase}.dir"

XattrNameForVideo+="#PCS"	# set flags for the OS regarding copying and
XattrNameForDir+="#PCS"		# backing up etc. to retain xattr's

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
GetMovieXattr()
{
local theFile="${1}"
local theData
local arr
local argc
local func="${FUNCNAME}()"

  if [ ! -f "${theFile}" ]; then
    echo -e "${func} Bailing. No such file: '${theFile}'"
    exit 1
  fi

  #	Call the routine that reads the extended attributes, it
  #	places the results in the a Global using the attributeName
  #
  ReadXattrData ${XattrNameForVideo} "${theFile}"

  theData=$( GetGlobalVal ${XattrNameForVideo} )

  #	fields are seperated with whatever $Xseperator is set to
  #	Check number of items is correct.
  #
  IFS="${Xseperator}" arr=(${theData[*]})
  argc=${#arr[@]}

  if [ ${argc} -ne 5 ]; then
    echo -e "${func} Bailing. Expecting 5 items, but there's '${argc}'"
    exit 1
  fi

  return 0
}		# eo GetMovieXattr()


SetMovieXattr()
{
local theFile="${1}"
local sep="${Xseperator}"		# for brevity
local dirData
local vidData
local func="${FUNCNAME}()"

  if [ ! -f "${theFile}" ]; then
    echo -e "${func} Returning. No such file: '${theFile}'"
    return 1
  fi

  #	Attempt to get the xattr's stored in the directory for
  #	use as the dayOfYear
  #
  local theDirectory=$( GetGlobalVal directory )
  local dayOfYear
  local arr
  local argc

  ReadXattrData ${XattrNameForDir} "${theDirectory}"

  dirData=$( GetGlobalVal ${XattrNameForDir} )

  #	We'll just use todays day of the year as a fallback
  if [ "${dirData}" == "${nil}" ]; then
    echo -e "${func} Can't locate extended attr for ${XattrNameForDirectory}"
    echo -e "setting values to current day of the year.\n"
    dayOfYear=$(date +"%j")	# will be used for 'TV episode'
    dirData="${dayOfYear}${Xseperator}${dayOfYear}"
  fi

  #	Store data in the Global $XattrName and call the func to write
  #	the extended attriubtes
  #
  SetGlobalVal ${XattrNameForDir} "${dirData}"
  WriteXattrData ${XattrNameForDir} "${theFile}"

  #	fields are seperated with whatever $Xseperator is set to
  #
  #	Just using the first field, which is firstDay
  #
  IFS="${Xseperator}" arr=(${dirData[*]})
#  argc=${#arr[@]}

  dayOfYear=${arr[0]}


  local theHeight=$( GetGlobalVal outHeight )

  if [ "${theHeight}" == "${nil}" ]; then
    theHeight="unknown"
  fi

#  local dayOfYear=$(date +"%j")	# will be used for 'TV episode'
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
   vidData="${dayOfYear}${Xseperator}"
  vidData+="${theYear}${Xseperator}"
  vidData+="${theDate}${Xseperator}"
  vidData+="${theShow}${Xseperator}"
  vidData+="${theTitle}"

  #	Store data in the Global $XattrName and call the func to write
  #	the extended attriubtes
  #
  SetGlobalVal ${XattrNameForVideo} "${vidData}"
  WriteXattrData ${XattrNameForVideo} "${theFile}"

  return 0

}		# eo SetMovieXattr()


#
#	Create/update extended attributes for the passed file/dir, this
#	func handles/checks for specific data, but can be used as a template
#
UpdateDirXattrData()
{
local theAttrName="${1}"
local theFile="${2}"
local theData
local oldData
local status
local func="${FUNCNAME}()"

  if [ "${theAttrName}" == "" ]; then
    echo -e "${func} Returning. Empty extended attribute name passed."
    return 1
  fi

  #	-e = true if file exists, regardless of type, ie file or dir
  #
  if [ ! -e "${theFile}" ]; then		
    echo -e "${func} Returning. No such file/directory: '${theFile}'"
    return 1
  fi

  oldData=$( xattr -p "${theAttrName}" "${theFile}" 2>&1 )

  #	xattr has all manner of exit codes, we'll dangerously assume it's
  #	was just 'No suck xattr'
  #	0 = success
  #	1 = all manner of things including 'no such xattr'
  #
  status=$?

  #	deal with exit codes outside of 0-1
  #
  if [ $status -gt 1 ]; then
    echo -e "${func} Bailing. Bad status '${status}' return from xattr(1):\n"
    echo -e "${oldData}\n"
    exit 1
  fi

  #	This is dangerous as 1 can mean 'no such file' and 'no such xattr'
  #	and god knows what else. We'll just assume we can write and return.
  #
  if [ $status -eq 1 ]; then
    WriteXattrData $theAttrName "${theFile}"
    return 0
  fi

  #	The rest of the func is for $status -eq 0, so there was already
  #	an old xattr but we'll just overwrite the contents.
  #
  theData=$( GetGlobalVal $theAttrName )

  #	If old and new data match, just return
  #
  if [ "${oldData}" == "${theData}" ]; then
    return 0
  fi

  #	Build arrays of new and old array to compare their values
  #
  #	Need to check that argc is 2 etc, not bothering yet.
  #
  local oldArray
  local newArray
  local oldArgc
  local newArgc

  IFS="${Xseperator}" oldArray=(${oldData[*]})
  oldArgc=${#oldArray[@]}

  IFS="${Xseperator}" newArray=(${theData[*]})
  newArgc=${#newArray[@]}

  #	MUST use braces otherwise [1] etc. gets appended as a string and
  #	fucks up the values let alone if statements etc.
  #
  #		i.e value will be set like 270[0] or 15[1] etc.
  #
  local oFirstDay=${oldArray[0]}; local oLastDay=${oldArray[1]}
  local nFirstDay=${newArray[0]}; local nLastDay=${newArray[1]}

  local firstDay=${nFirstDay}
  local lastDay=${nLastDay}

  if [ ${oFirstDay} -lt $firstDay ]; then firstDay=${oFirstDay}; fi
  if [ ${oLastDay}  -gt $lastDay  ]; then lastDay=${oLastDay}; fi

#echo "old0: '${oFirstDay}' new0: '${nFirstDay}' first: '$firstDay'"
#echo "old1: '${oLastDay}' new1: '${nLastDay}' last: '$lastDay'"

  #	build updated data string
  #
  theData="${firstDay}${Xseperator}${lastDay}${Xseperator}${theFile}"

  #	Update Global and write the xattr
  #
  SetGlobalVal $theAttrName "${theData}"
  WriteXattrData $theAttrName "${theFile}"

  return 0
}		# eo UpdateDirXattrData()

#
#	Gets exteneded attributes from the passed file and stores them
#	in the Global $XattrName
#
#	Individual datum are seperated by $Xseperator
#
ReadXattrData()
{
local theAttrName="${1}"
local theFile="${2}"
local status
local theData
local func="${FUNCNAME}()"

  if [ "${theAttrName}" == "" ]; then
    echo -e "${func} Returning. Empty extended attribute name passed."
    return 1
  fi

  #     -e = true if file exists, regardless of type, ie file or dir
  #
  if [ ! -e "${theFile}" ]; then
    echo -e "${func} Returning. No such file: '${theFile}'"
    return 1
  fi

  #	Call xattr(1) for the given name and save the contents in $theData
  #
  theData=$( xattr -p "${theAttrName}" "${theFile}" )

  status=$?
  if [ ${status} -ne 0 ]; then
    echo -e "${func} Bailing. Bad status return from xattr(1): '${status}'."
    exit 1
  fi

  if [ "${theData}" == "" ]; then
    echo -e "${func} Warning. Extended attributes are empty."
  fi

  #	Store the data in a Global named $theAttrName
  #
  SetGlobalVal "${theAttrName}" "${theData}"

  return 0
}		# eo ReadXattrData()

#
#	Adds passed data to the extended attriubes of the specified file.
#
#	Individual datum should be seperated by $Xseperator
#
WriteXattrData()
{
local theAttrName="${1}"
local theFile="${2}"
local theData
local status
local func="${FUNCNAME}()"

  if [ "${theAttrName}" == "" ]; then
    echo -e "${func} Returning. Empty extended attribute name passed."
    return 1
  fi

  #     -e = true if file exists, regardless of type, ie file or dir
  #
  if [ ! -e "${theFile}" ]; then
    echo -e "${func} Returning. No such file: '${theFile}'"
    return 1
  fi

  #	Get the data from the Global var $XattrName value
  #
  theData=$( GetGlobalVal ${theAttrName} )

  if [ "${theData}" == "${nil}" ]; then
    echo -e "${func} Warning. Empty Global '${theAttrName}'."
  fi

  #	Write the metadata as ascii text string (-w)
  #
  xattr -w "${theAttrName}" "${theData}" "${theFile}"

  status=$?
  if [ ${status} -ne 0 ]; then
    echo -e "${func} Bailing. Bad status return from xattr(1): '${status}'."
    exit 1
  fi

  return 0

}		# eo WriteXattrData()

#	EOF
