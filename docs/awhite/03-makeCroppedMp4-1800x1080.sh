#!/bin/bash

#       Files to include
#
. 00-Shared.sh                  # Some funcs/vars shared by all noaa scripts
. 03-Includes.sh                # Extra funcs used by this script.

#	snapshots are often 10 min intervals = 6 per hour which divides
#	into 24 for fps and works well, however fps can be anything.
#
#	fontFile is needed for overlay text
#
Globals=(

  iDir="NOAA-2021.09.23-1800x1080"	# directory of downloaded images

  suffix="jpg"		# images file format suffix

  fps=24		# works well for 10 minute snapshots

  footerHeight=30	# height of image footer to crop out

  inHeight=1080		# height of input images
  outHeight=840		# ffmpeg will barf if height isn't divisible by 2

  overlayFrame=1		# set to 0 to disable frame no. overlay
  overlayName=1			# set to 0 to disable filename metadata overlay
  overlayTC=1			# set to 0 to disable timecode overlay

  comment="If set, added to the movie metadata"

#  videoRate=3000k	# if set, overrides MakeMp4HWA() calculated settings

  #	No need to mess with settings below this line, but you can
  #

  fontSize=20			# in pixels?
  fontColor="white"
  boxColor="black@.6"		# bg box color and opacity
  boxBorder=8			# bg box border size

#  fontFile="'/Library/Fonts/Courier New Bold.ttf'"
#  fontFile="'/System/Library/Fonts/Monaco.dfont'"
  fontFile='/System/Library/Fonts/Monaco.dfont'

)

  #	main()
  #

  #	Generate output file names based on input directory name and
  #	outHeight.
  #
  iDir=$( GetGlobalVal iDir )
  oHeight=$( GetGlobalVal outHeight )

  mFile="${iDir}-x${oHeight}.mkv" 	# tmp mkv movie
  tFile="${mFile//.mkv/-big.mp4}"	# just change the suffix
  oFile="${mFile//.mkv/.mp4}"		# just change the suffix

  #	First generate an image file based mkv with all the files
  #	in the input directory.
  #
  #	The routine also crops out the noaa footer and scales it the
  #	outHeight set above
  #
#  MakeMkv "${mFile}"

  #	The following routine will just copy the video stream from the
  #	source video and package it into a mp4 container - however the
  #	playback bitrate and file-size will be wayyy larger
  #
#  MakeMp4 "${mFile}" "${tFile}"

  #	Convert the mkv version to mp4 using the Mac hardware accelerator
  #
  MakeMp4HWA "${mFile}" "${oFile}"

  #	Clean up - nuke mkv and stream copy version
  #
#  rm "${mFile}" "${tFile}"
	
exit 0
