#!/bin/bash

#set -o xtrace			# echo commands as they're being executed
#set -o pipefail                # any piped command fails will stop
#set -eu                         # -e stop on errors, -u stop on unset vars
set -u                         # -e stop on errors, -u stop on unset vars
                                # n.b., exit() in sourced functions don't work


Prog=$(basename $0)		# The calling script's name.

Dash=""				# For printing seperator dash, gets set
				# if empty see MakeDash().

nil="<nil>"			# used extensively to check returned keys etc.

#	Set up a global "poor mans" associate array so it will run
#	on older versions of bash, such as a Mac.
#
#	Each array entry (index) is holding a word=word combo (key/val pair)
#	that can be change later if wanted. 
#
#	This can be used by calling scripts to set their own individual
#	globals for the specific script:
#
#		declare -a Globals=( 
#		  key="description"
#		  suffix="jpg"
#		  directory="some quoted path"
#		)
#
#	It can also be dynamically added to by using the SetGlobalVal() func.
#
declare -a Globals


#	LIFO (Last-In-First-Out) search of the Globals array for the passed
#	key. 
#
#	Each entry has the form key=value (the '=' character is the seperator).
#
#	On a successful key match, the associated value is returned otherwise
#	$nil
#
#	For a FIFO version (First-In-First-Out) use GetGlobalValFIFO() instead.
#
GetGlobalVal()
{
local theKey="${1}"
local theValue
local i
local nEntries
local entry
local key

  let nEntries=(${#Globals[@]} - 1)	# zero based arrays, so size -1

  for ((i=nEntries; i >= 0; i-- ))
  do
    entry="${Globals[$i]}"

    key="${entry%%=*}"		# lhs of '=' char if set

    if [ "${key}" == "${theKey}" ]; then
      theValue="${entry##*=}"		# rhs of '=' char if set
      break
    fi   

  done

  #	If theValue is empty, set to ${nil}
  #
  if [ "${theValue}" == "" ]; then theValue="${nil}"; fi

  #	If there was no seperator ('=' char), set theValue to ${nil}
  #
  if [ "${theValue}" == "${theKey}" ]; then theValue="${nil}"; fi

  echo "${theValue}"

}		# eo GetGlobalVal()


#	FIFO (First-In-First-Out) version of GetGlobalVal(), which is LIFO
#
GetGlobalValFIFO()
{
local theKey="${1}"
local theValue="${nil}"
local i
local nEntries
local entry
local key

  let nEntries=(${#Globals[@]} - 1)

  for ((i=0; i < $nEntries; i++ ))
  do
    entry="${Globals[$i]}"

    key="${entry%%=*}"		# lhs of '=' char if set

    if [ "${key}" == "${theKey}" ]; then
      theValue="${entry##*=}"		# rhs of '=' char if set
      break
    fi   

  done

  echo "${theValue}"

}		# eo GetGlobalValFIFO()

#
#	Replace a Globals array entry if the key portion matches the passed 
#	key and set it to the passed value.
#
#	This will need tweaks if the $theKey or $theValue contain an
#	equals '=' character.
#
#	If there was no match for the key, it will be appended to the
#	the Globals array, so you can dynamically add new key/value pairs.
#
#	Note - LIFO - last entry gets modified in case of duplicates
#
#	Also note, if no val arg is specified, it will be set to ${nil}
#
SetGlobalVal()
{
local theKey
local theVal
local i
local key
local nEntries
local replacement

  case $# in
    1 ) theKey="${1}"; theVal="${nil}" ;;
    2 ) theKey="${1}"; theVal="${2}" ;;
    * ) echo -e "${func} Bailing. Missing args, count is '$$'"; exit 1;;
  esac

  replacement="${theKey}=${theVal}"

  let nEntries=(${#Globals[@]} - 1)	# zero based arrays, so size -1

  for ((i=nEntries; i >= 0; i-- ))
  do
    entry="${Globals[$i]}"

    key="${entry%%=*}"		# lhs of '=' char if set

    if [ "${key}" == "${theKey}" ]; then
      Globals[$i]="${replacement}"
      return 0
    fi
  done

  #	The passed key wasn't matched, so add a new entry to the end of array
  #
  let nEntries++
#  Globals[$i]="${replacement}"
  Globals[$nEntries]="${replacement}"

  return 1		# There was no match, this sets the status which
			# can be checked with $? after the function ran.

}		# eo SetGlobalVal()

PrintGlobals()
{
local i
local func="${FUNCNAME}"

#  echo "${Dash}"
#  echo -e "${func}()\n"

  for i in "${Globals[@]}"; do
    echo -e "\t${i}"
  done

  echo
}		# eo PrintGlobals()

MakeDash()
{
local i
local tSize=$(stty size)		# returns rows space columns
local charMax=( ${tSize##* } - 10 ) 	# rhs of space char minus value

  for ((i=0; i<$charMax; i++)); do Dash+="-"; done

}		# eo MakeDash()

if [ "${Dash}" == "" ]; then MakeDash; fi
