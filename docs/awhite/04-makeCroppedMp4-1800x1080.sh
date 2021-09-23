#!/bin/bash

#set -o xtrace

OIFS=$IFS				# store original IFS
IFS=$'\t\n'				# set to leave spaces intact
#IFS=$OIFS				# reset IFS to original setting

  iDir="NOAA-2021.09.15-3600x2160"
iDir="NOAA-2021.09.16-1800x1080"
iDir="NOAA-2021.09.17-1800x1080"
iDir="NOAA-2021.09.22-1800x1080"

  cWidth=1800				# original size crop width
  cHeight=1080				#     "     "    "   height
cHeight=1050

oWidth=""				# text, only for file name
oHeight=840				# width will be auto calced 
#oHeight=540

  tFile="${iDir}-${oWidth}x${oHeight}.mkv" # tmp mkv movie
  oFile="${tFile//.mkv/.mp4}"		   # just change the suffix
oFile2="${tFile//.mkv/-hwa.mp4}"


  fps=24				# use multiples of 6

#	An alternative way of parsing files to build a movie file
#
#	crop filter reference docs:
#
#		https://ffmpeg.org/ffmpeg-filters.html#crop
#
MakeMkv()
{
local oFile="${1}"
local filter

  filter="fps=$fps"
#  filter+=",crop=$cWidth:$cHeight:(in_w-out_w):(in_h-out_h)/2"		# rhs, centered verticaly
  filter+=",crop=$cWidth:$cHeight:(in_w-out_w):0"		# rhs, centered verticaly
#  filter+=",scale=-1:${oHeight}:flags=lanczos"
  filter+=",scale=-1:${oHeight}:flags=spline"

  #	pre-calc font size and round it down to an exact int based upon
  #	output image height.
  #
#local fSize=24
#local fSize="(h*.033333334)"		# approx 24px in a 720px high image

  local fH=$(echo "${oHeight} * 0.033333334" | bc -l)
  local fSize=$(printf "%.0f" $fH)
fSize=20

  local fColor="white"
#  local fFile="'/Library/Fonts/Courier New Bold.ttf'"
  local fFile="'/System/Library/Fonts/Monaco.dfont'"

  local bColor="black@.6"			# bg box color and opacity
  local bWidth=8				# bg box border size in pixels

#  local yOffset="(h-(text_h*4))"
#  local yOffset2="(h-(text_h*3))"

  # There's some bug with the ypos when there's multiple drawtexts, so 
  # hard-code in bash and not rely on drawtext expressions.
  #
  local  yOffset=$( echo "${oHeight} - ($fSize * 4)"   | bc -l )
  local yOffset2=$( echo "${oHeight} - ($fSize * 2.4)" | bc -l )

fontOptions="
:fontsize=${fSize}:fontcolor=${fColor}:fontfile=${fFile}
:box=1:boxcolor=${bColor}:boxborderw=${bWidth}
"

#	lhs overlay text
#
#,drawtext=text='\ ${fps}fps frame\: %{frame_num}\ '
#:text='\ ${fps}fps frame\: %{frame_num}\ '
filter+="
,drawtext=expansion=normal
:text='\ Frame\: %{frame_num}\ '
:x=(w*.025)
:y=${yOffset}
${fontOptions}
"

#	center text
#
filter+="
,drawtext=expansion=normal
:text='\ %{metadata\:ImageDescription\:missing metadata}\ '
:x=(w-text_w)/2
:y=${yOffset}
${fontOptions}
"

#	rhs overlay text
#
#	note that using this form of timecode fucks up the 'expansion' mode
#	and doesn't seem to work with builitin expanded text/variables
#
filter+="
,drawtext=expansion=normal
:timecode='00\:00\:00\:00'
:timecode_rate=${fps}
:text='\ ${fps}fps TC\ '
:x=(w*.975)-text_w
:y=${yOffset}
${fontOptions}
"

#	rhs lower milisecond based timecode
Zfilter+="
,drawtext=expansion=normal
:text='\ %{pts\:hms}'
:x=(w*.975)-text_w
:y=${yOffset2}
${fontOptions}
"

#	 -framerate $fps	\

  ffmpeg -hide_banner -y	\
	 -f image2 		\
	 -pattern_type glob	\
	 -i "${iDir}/*.jpg"	\
	 -filter_complex "[0:v]${filter}[v]"	\
	 -map [v] \
	"${oFile}"

}		# eo MakeMkv()


#	Run this after making the .mkv to copy the video stream
#	into a .mp4 container
#
MakeMp4()
{
local iFile="${1}"
local oFile="${2}"

  ffmpeg -hide_banner -y	\
	 -i "${iFile}"		\
	 -c copy		\
	 -movflags +faststart	\
	 "${oFile}"

}		# eo MakeMp4()

MakeMp4HWA()
{
local iFile="${1}"
local oFile="${2}"
local videoRate=3000k

    if [ $oHeight -le 540 ]; then
      videoRate=3000k
  elif [ $oHeight -le 720 ]; then
      videoRate=4000k
  else
      videoRate=6000k
  fi
#	 -c:v hevc_videotoolbox \		# h265 hardware encoder on Mac

  ffmpeg -hide_banner -y	\
	 -i "${iFile}"		\
	 -map v			\
	 -c:v h264_videotoolbox \
	 -b:v ${videoRate}	\
	 -movflags +faststart	\
	 "${oFile}"

}		# eo MakeMp4HWA()

  MakeMkv "${tFile}"
#  MakeMp4 "${tFile}" "${oFile}"
  MakeMp4HWA "${tFile}" "${oFile2}"
	
exit
