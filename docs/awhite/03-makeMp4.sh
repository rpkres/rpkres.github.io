#!/bin/bash

#       Files to include
#
. 00-Shared.sh                  # Some funcs/vars shared by all noaa scripts
. 00-Xattr.sh                   # Funcs/vars for extended file attributes
. 03-Includes.sh                # Extra funcs used by this script.


#	snapshots are often 10 min intervals = 6 per hour which divides
#	into 24 for fps and works well, however fps can be anything.
#
#	fontFile is needed for overlay text
#
Globals=(

  fps=24		# works well for 10 minute snapshots
  footerHeight=0	# height of input image footer to crop out
  suffix="jpg"		# images file format suffix

  compFrame=true	# if true, renders frame no. overlay
  compName=true		# if true, renders file name overlay
  compTC=true		# if true, renders timecode overlay

#  comment="A comment"	# Added to the movie metadata 'comment' tag if defined
  cleanUp=true		# If true, removes intermediate files (mkv etc).

#  videoRate=3000k	# if set, overrides MakeMp4HWA() calculated settings

  fontSize=20		# in pixels

# outFile=		# by default, uses input directory name

  #	The following cannot be changed on the command line, but 
  #	can be set here.
  #
  fontColor="white"
  boxColor="black@.6"		# bg box color and opacity
#  fontFile="/Library/Fonts/Courier New Bold.ttf"
  fontFile="/System/Library/Fonts/Monaco.dfont"

)			# eo Globals

  #	main()
  #

  #     Parse command line args.
  #
  if [ $# -lt 2 ]; then
    Usage
  fi

  #     Copy command line args and place in argv array and parse
  #
  #	Note use of IFS is set only for the following command (there's 
  #	no semicolon). In this case items are only split on \n, not
  #     spaces or tabs so the user can passed quoted strings with spaces
  #	as a single argument.
  #
  IFS=$'\n' argv=($*)
  argc=${#argv[@]}
  let cnt=($argc - 2)	# last args don't get parsed as options

#  PrintGlobals

  #	Uses 'array slicing' for options with value as next argv as 
  #	it returns a null if the array index being referenced doesn't exist.
  #	'len' is number of entries
  #
  #		${array[@]:index:len}
  #
  #	Note that $i get's incemented to get the next index.
  #
  for ((i=0; i<$cnt; i++)); do

    arg="${argv[$i]}"

    case "${arg}" in
      "-c"   | "--comment" )
	let i++
	SetGlobalVal comment "${argv[@]:$i:1}"
	;;
      "-fh"  | "--footerHeight" ) 
	let i++
	SetGlobalVal footerHeight "${argv[@]:$i:1}"
	;;
      "-fps" | "--fps" )
	let i++
	SetGlobalVal fps "${argv[@]:$i:1}"
	;;
      "-h"   | "--help"   ) 	  
	Usage 
	;;
      "-fs" | "--fontSize" ) 
	let i++
	SetGlobalVal fontSize "${argv[@]:$i:1}"
	;;
      "-noframe"  | "--noFrame" ) 	  
	SetGlobalVal compFrame false
	;;
      "-noname"  | "--noName" ) 	  
	SetGlobalVal compName false
	;;
      "-nooverlay" | "--noOverlay" )
	SetGlobalVal compFrame false
	SetGlobalVal compName false
	SetGlobalVal compTC false
	;;
      "-noTC" | "--noTC" ) 	  
	SetGlobalVal compTC false
	;;
      "-noclean"  | "--noClean" )
	SetGlobalVal cleanUp false
	;;
      "-of" | "--outFile" )
	let i++
	SetGlobalVal outFile "${argv[@]:$i:1}"
	;;
      "-oh" | "--outHeight" )
	let i++
	SetGlobalVal outHeight "${argv[@]:$i:1}"
	;;
      "-s" | "--suffix" )
	let i++
	SetGlobalVal suffix "${argv[@]:$i:1}"
	;;
      * )
	echo -e "${Prog}. Bailing. Unrecognized option: '${arg}'."
	exit 1
    esac

  done

  #     last args should be the inputHeight and directory
  #
  iHeight="${argv[($argc-2)]}"
  iDir="${argv[($argc-1)]}"


  oHeight=$( GetGlobalVal outHeight )

  #	If 'outHeight' wasn't set on the command-line make it the same
  #	as 'inHeight' minus 'footerHeight'
  #
  if [ "${oHeight}" == "${nil}" ]; then
    fHeight=$( GetGlobalVal footerHeight )
    let oHeight=(${iHeight} - ${fHeight})

    SetGlobalVal outHeight "${oHeight}"
  fi

  SetGlobalVal inHeight  "${iHeight}"
  SetGlobalVal directory "${iDir}"

  #	Figure out base name of output file, by default it's the input
  #	directory name.
  #
  outName=$( GetGlobalVal outFile )

  if [ "${outName}" == "${nil}" ]; then
    outName="${iDir}"
  else
    outName="${outName//.mp4/}"		# strip .mp4 from name 
  fi

  #	Generate output file names based on outName and outHeight.
  #
  oHeight=$( GetGlobalVal outHeight )

  mFile="${outName}-x${oHeight}.mkv" 	# tmp mkv movie
  tFile="${mFile//.mkv/-big.mp4}"	# copy of mkv in a mp4 container
  oFile="${mFile//.mkv/.mp4}"		# output movie

  SetGlobalVal outFile "${oFile}"


  #	First generate an image file based mkv with all the files
  #	in the input directory.
  #
  #	The routine also crops out the noaa footer and scales it the
  #	outHeight set above
  #
  MakeMkv "${mFile}"

  #	The following routine will just copy the video stream from the
  #	source video and package it into a mp4 container - however the
  #	playback bitrate and file-size will be wayyy larger
  #
#  MakeMp4 "${mFile}" "${tFile}"

  #	Convert the mkv version to mp4 using the Mac hardware accelerator
  #
  MakeMp4HWA "${mFile}" "${oFile}"

  #	Add extended attributes to the output movie so that some info can
  #	be easily accessed at a later time.
  #
  SetMovieXattr "${oFile}"
PrintGlobals

  #	Clean up - nuke mkv and stream copy versions if flagged
  #
  cleanUp=$( GetGlobalVal cleanUp )

  if [ ${cleanUp} == "true" ] 
  then
    if [ -f "${mFile}" ]; then rm "${mFile}"; fi
    if [ -f "${tFile}" ]; then rm "${tFile}"; fi
  fi
	
exit 0
