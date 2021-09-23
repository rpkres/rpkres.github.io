#!/bin/bash

#	Function that runs curl(1), get called multiple times to reduce
#	number of network requests and so hopefully not get banned for
#	grabbing lots of images and consuming too much bandwidth
#
#	--limit-rate kmG	be nice with bandwidth
#
#	--remote-time		try to use the remote timestamp 
#				for local file copy
#
# 	--fail	not foolproof, but if a requested file doesn't exist curl 
#		tries not to pass the transfer (often html) as the output file
#
#	--user-agent	Can pretend that we're a browser in case the site
#			blocks curl etc.
#
#
RunCurl()
{
#local theUrl="${1}"
#local theOutPath="${2}"
local oPath
local theUrl
local oPath
local userAgent
local curlLimitRate
local execCurl
local func="${FUNCNAME}"

  #	This can be added with the -A flag to curl if needed
  #
   userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_3) "
  userAgent+="AppleWebKit/605.1.15 (KHTML, like Gecko) "
  userAgent+="Version/12.0.3 Safari/605.1.15"

  echo "${Dash}"
  echo -e "${func}()\n"

  theUrl=$( GetGlobalVal theUrl )

  if [ "${theUrl}" == "${nil}" ]; then
    echo "Bailing. Something is seriously wrong, theUrl is ${nil}."
    exit 1
  fi

  oPath=$( GetGlobalVal oPath )

  if [ "${oPath}" == "${nil}" ]; then
    echo "Bailing. Something is seriously wrong, oPath is ${nil}."
    exit 1
  fi

  curlLimitRate=$( GetGlobalVal curlLimitRate )

  #	Set download bandwidth rate if ${nil}
  #
  if [ "${curlLimitRate}" == "${nil}" ]; then
    curlLimitRate=1200k
    SetGlobalVal curlLimitRate ${curlLimitRate}
  fi

PrintGlobals

  execCurl=$( GetGlobalVal execCurl )

  #	If the variable 'execCurl' is not set, just return
  #
  if [ "${execCurl}" != "1" ]; then
    echo -e "Not executing curl(1) - set Global 'execCurl=1'.\n"
    return
  fi

  curl "${theUrl}"			\
	--fail				\
	--user-agent "${userAgent}"	\
	--limit-rate 1200k		\
	--create-dirs			\
	--progress-bar			\
	--show-error			\
	--output "${oPath}"

#	--silent			\

  local curlStatus=$?			# exit status from curl
#  echo "status: '${curlStatus}'"

}		# eo RunCurl()


#	Pre-fill the global array 'curlHoursArr' used for the hours part
#	of the and format it for curl's globbing system which in turn
#	is part of the url.
#
#	Currently the NOAA snapshots appear to be every 10 mins which 
#	is passed as an argument.
#
#	Example of a listing on noaa's site:
#
#	https://cdn.star.nesdis.noaa.gov/GOES17/ABI/SECTOR/NP/GEOCOLOR/
#
PrebuildHoursArray()
{
#local interval=$1
local interval
local hour
local startMinute=0
local endMinute=50
local hoursRange

  interval=$( GetGlobalVal interval )

  for ((hour=0; hour < 24; hour++ ))
  do

    hoursRange=$( printf "[%.2d%.2d-%.2d%.2d:$interval]" \
                          $hour $startMinute $hour $endMinute )

    curlHoursArr[$hour]="${hoursRange}"

  done

}		# eo PrebuildHoursArray()


