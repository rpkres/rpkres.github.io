#!/bin/bash

. 00-Shared.sh 			# Some funcs/vars shared by noaa scripts
. 00-Xattr.sh			# Funcs/vars for extended file attributes
. 04-Includes.sh		# Extra funcs used by this script.

#	Globals to use in this script
#
#	Note, entries can be commented out!
#
Globals=( 

  tvEpisode=			# uses day of year movie file created
  tvSeason=			# uses the year of movie file created
  tvAirDate=			# uses the date in UTC format for broadcast date
  tvShow=			# uses defined name for TV show
  tvTitle=			# uses show name+height for the episode title

)

  #	main()

  #	Parse command line args.
  #
  if [ $# -lt 1 ]; then
    Usage
  fi

  #     Copy command line args and place in argv array and parse
  #
  #     Note use of IFS is set only for the following command (there's 
  #     no semicolon). In this case items are only split on \n, not
  #     spaces or tabs so the user can passed quoted strings with spaces
  #     as a single argument.
  #
  IFS=$'\n' argv=($*)
  argc=${#argv[@]}
  let cnt=($argc - 1)   # last args don't get parsed as options

  for ((i=0; i<$cnt; i++)); do

    arg="${argv[$i]}"

    case "${arg}" in
      "-h" | "--help"   ) Usage ;;
#      "-s" | "--suffix" ) 
#	let i++
#        SetGlobalVal suffix "${argv[@]:$i:1}"
#	;;
      * )
	echo -e "${Prog}. Bailing. Unrecognized option: '${arg}'."
	exit 1
    esac

  done

  #	last arg should be a movie file, can be quoted on the command line
  #
  iFile="${argv[($argc-1)]}"

  SetGlobalVal inputFile "${iFile}"

  AddiTunesMetadata "${iFile}"

#  PrintGlobals

exit 0
