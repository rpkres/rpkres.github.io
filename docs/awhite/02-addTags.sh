#!/bin/bash

. 00-Shared.sh 			# Some funcs/vars shared by noaa scripts
. 02-Includes.sh		# Extra funcs used by this script.

#	Globals to use in this script
#
#	Note, entries can be commented out!
#
Globals=( 
  metaKey=description
  suffix=jpg
  directory=
)

  #	main()

  #	Parse command line args.
  #
  if [ $# -lt 1 ]; then
    Usage
  fi

  #	Copy command line args and place in argv array and parse
  #
  argv=($*)
  argc=${#argv[@]}

#  PrintGlobals

  for ((i=0; i<$argc; i++)); do

    arg="${argv[$i]}"

    lhs="${arg%%=*}"		# lhs of '=' char if set
    rhs="${arg##*=}"		# rhs of '=' char if set

    case "${lhs}" in
      "-h" | "--help"   ) Usage ;;
      "-s" | "--suffix" ) SetGlobalVal suffix "${rhs}" ;;
      "-k" | "--key"    ) SetGlobalVal metaKey "${rhs}" ;;
    esac

  done

  #	last arg should be the directory name, can be quoted
  #
  iDir="${argv[($argc-1)]}"

  SetGlobalVal directory "${iDir}"

  PrintGlobals

  AddMetadataWithSips "${iDir}"

exit 0
