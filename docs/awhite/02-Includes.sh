#!/bin/bash

Usage()
{
local suffix=$( GetGlobalVal suffix )
local metaKey=$( GetGlobalVal metaKey )

cat <<EOD

Usage: ${Prog} [option] directory

	-h, --help		Prints this message and exits.

        -k, --key <string>	Set the metadata keyword to <string> (default 
                        	'${metaKey}'). The associated value of the 
				key is set to the filename.

        -s, --suffix <string>	Set the suffix to <string> (default '${suffix}').

	${Prog} runs find(1) on the specified directory for files 
	ending with the suffix (default '${suffix}') and adds it to a list.

	Then sips(1) is run on each file in the list and sets the value 
	associated with the metadata keyword (default '${metaKey}') to the 
	filename if the key hasn't already been set.

	This allows tools such as ffmpeg(1) to use the metadata to display
	the filename in an overlay on the output video. Quite hacky, but
	it works.

EOD

exit 1

}		# eo Usage()

#
#	Add the filename as a metadata tag to the files, this helps
#	to render filenames on the video with ffmpeg.
#	
#
AddMetadataWithSips()
{
#local theDir="${1}"
local theDir=$( GetGlobalVal directory )
local theSuffix=$( GetGlobalVal suffix )
local theMetaKey=$( GetGlobalVal metaKey )
local sips=/usr/bin/sips
local find=/usr/bin/find
local list
local array
local aSize
local i
local thePath
local theName
local oldMeta			# for checking if set
local sipsString		# just to store the noisy output		
local func="${FUNCNAME}"

  echo "${Dash}"
  echo -e "${func}()\n"

  if [ ! -x "${sips}" ]; then
    echo -e "Returning. Not a Mac? No such program: '${sips}'\n"
    return 1
  fi

  if [ ! -x "${find}" ]; then
    echo -e "Somethings up. No such program: '${find}'\n"
    return 1
  fi

  if [ ! -d "${theDir}" ]; then
    echo -e "Bailing. No such directory: '${theDir}'\n"
    exit 1
  fi

  local tSize=$(stty size)                # returns rows space columns
  local charMax=( ${tSize##* } - 10 )     # rhs of space char minus value

  #	Save the output of find(1) to a list
  #
  list=$( ${find} "${theDir}" -iname "*.${theSuffix}" -print)

  array=(${list})		# copy list into index based array
  aSize=${#array[*]}		# no. indicies

  for ((i=0; i < ${aSize}; i++ ))
  do

    # print a <CR> if $i % some value is zero
    #	terminates periods printed to screen
    ((cr=$i % ${charMax})); if [ $cr -eq 0 ]; then echo -en "\n"; fi

    echo -en "."

    thePath="${array[${i}]}"

    #	Keep chars on the rhs of last slash, strips directory names etc.
    #	Similar to basename(1) but should run faster
    #
    theName="${thePath##*/}"

    #	Get the value for the key
    #	sips prints the path and key and ${nil} if not defined, so strip
    #	the string afterwards
    #
    oldMeta=$( ${sips} --getProperty "${theMetaKey}" "${thePath}" )

    #	Strip the string. Keep chars on rhs of 'descritption: ' 
    #   (note ths space char)
    #
    oldMeta="${oldMeta##*description: }"	

    #	If the current oldMeta is ${nil} set it to the file name.
    #	sips is noisy, so ignore it's output unless it has 
    #	a bad exit status which is stored in $?
    #
    if [ "${oldMeta}" == "${nil}" ]; then
      sipsString=$(${sips} --setProperty "${theMetaKey}" \
					"${theName}" "${thePath}")

      if [ $? -ne 0 ]; then
        echo "Bailing. ${sips} barfed, here's the output:"
        echo "${sipsString}"
        return 1
      fi

    fi		# eo if $oldMeta

  done		# eo for i

  echo -e "\nFinished checking/adding metadata.\n"

  return 0
}		# eo AddMetadataWithSips()
