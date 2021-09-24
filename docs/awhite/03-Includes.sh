#!/bin/bash

#	global, this is the metadata tag we add to the ouptut movie files.
#	Currently all the key/value pairs from Globals are stored and may
#	have additional info added.
#
#	KEY		
#	comment 	-	many programs can utilize this, includin mp3
#	description	-	iTunes utilizes this
#
#	Todo - 	add itunes tags so the mp4 will show up in TV Shows or
#		Movies when added to iTunes/Apple TV, currently they'll show
#		up in "Home Movies"
#
MetadataKey="description"

#	Uses and alternative way of parsing all files in an input directory
#	to build a movie file. See the actual ffmpeg call at end of function.
#
#	Note:	this uses the CPU to render the frames at a high quality
#		and is then used as input to a hardware accellerated render
#
#	crop filter reference docs:
#
#		https://ffmpeg.org/ffmpeg-filters.html#crop
#
MakeMkv()
{
local oFile="${1}"
local iDir			# directory containing downloaded images
local suffix			# input images file suffix
local fps
local footerHeight
local iHeight			# input image height
local oHeight			# output movie height
local cHeight			# crop height = $iHeight - $footerHeight
local fontColor
local boxColor
local boxBorder
local fontSize
local fontFile
local fontOptions		# string to hold all the font crap needed
local overlayFrame
local overlayName
local overlayTC
local metaString		# keep a copy of settings used in mov metadata
local filter
local func="${FUNCNAME}()"

  echo "${Dash}"
  echo -e "${func}\n"

  iDir=$( GetGlobalVal iDir )
  if [ "${iDir}" == "${nil}" ]; then
    echo "${func} Bailing. Global 'idir' is not set."
    exit 1
  fi

  if [ ! -d "${iDir}" ]; then
    echo "${func} Bailing. No such directory: '${iDir}'"
    exit 1
  fi

  suffix=$( GetGlobalVal suffix )
  if [ "${suffix}" == "${nil}" ]; then
    suffix="jpg"
    echo "${func} 'suffix' not set in globals, assuming '${suffix}'."
    SetGlobalVal suffix "${suffix}"
  fi

  fps=$( GetGlobalVal fps )
  if [ "${fps}" == "${nil}" ]; then 
    fps=24; 
    SetGlobalVal fps ${fps}
  fi

  footerHeight=$( GetGlobalVal footerHeight )
  if [ "${footerHeight}" == "${nil}" ]; then 
    footerHeight=0; 
    SetGlobalVal footerHeight ${footerHeight}
  fi

  iHeight=$( GetGlobalVal inHeight )
  if [ "${iHeight}" == "${nil}" ]; then
    echo "${func}: Bailing. Global 'inHeight' is not set."
    exit 1
  fi

  oHeight=$( GetGlobalVal outHeight )
  if [ "${oHeight}" == "${nil}" ]; then
    echo "${func}: Bailing. Global 'outHeight' is not set."
    exit 1
  fi

  let cHeight=($iHeight - $footerHeight)

  #	Build the video filter string we'll pass to ffmpeg
  #
  #	1. Set fps then crop out the footer at full size
  #
  #	2. Scale the crop to the output size
  #		ffmpeg will barf if the calculated width isn't divisible by 2
  #
  filter="fps=$fps"
#  filter+=",crop=$cWidth:$cHeight:(in_w-out_w):(in_h-out_h)/2"		# rhs, centered verticaly
  filter+=",crop=(in_w):${cHeight}:0:0"		# top left is 0,0
#  filter+=",scale=-1:${oHeight}:flags=lanczos"
  filter+=",scale=-1:${oHeight}:flags=spline"

  #	Get vals needed for drawing text overlays
  #
  fontSize=$( GetGlobalVal fontSize )
  if [ "${fontSize}" == "${nil}" ]; then
    fontSize=24
    SetGlobalVal fontSize ${fontSize}
  fi

  fontFile=$( GetGlobalVal fontFile )
  if [ "${fontFile}" == "${nil}" ]; then
    fontFile="'/System/Library/Fonts/Monaco.dfont'"
    SetGlobalVal fontFile "${fontFile}"
  fi

  fontColor=$( GetGlobalVal fontColor )
  if [ "${fontColor}" == "${nil}" ]; then
    fontColor="white"
    SetGlobalVal fontColor "${fontColor}"
  fi

  boxColor=$( GetGlobalVal boxColor )
  if [ "${boxColor}" == "${nil}" ]; then
    boxColor="black@.6"
    SetGlobalVal boxColor "${boxColor}"
  fi 

  boxBorder=$( GetGlobalVal boxBorder )
  if [ "${boxBorder}" == "${nil}" ]; then
    boxBorder=8
    SetGlobalVal boxBorder ${boxBorder} 
  fi

  #	String to add to the video filter with all the font options
  #
  fontOptions="
:fontsize=${fontSize}:fontcolor=${fontColor}:fontfile=${fontFile}
:box=1:boxcolor=${boxColor}:boxborderw=${boxBorder}
  "

  # There's some bug with ypos when there's multiple drawtexts, so 
  # hard-code in bash and don't use drawtext expressions.
  #
  local  yOffset=$( echo "${oHeight} - ($fontSize * 5)"   | bc -l )


  #	lhs overlay text - needs to be specifically set to 0 to turn off
  #
  overlayFrame=$( GetGlobalVal overlayFrame )

  if [ ${overlayFrame} -ne 0 ]; then
    filter+=",drawtext=expansion=normal
		:text='\ Frame\: %{frame_num}\ '
		:x=(w*.025)
		:y=${yOffset}
		${fontOptions}"
  fi

  #	center text - uses metadata from input file
  #
  overlayName=$( GetGlobalVal overlayName )

  if [ ${overlayName} -ne 0 ]; then
    filter+=",drawtext=expansion=normal
		:text='\ %{metadata\:ImageDescription\:missing metadata}\ '
		:x=(w-text_w)/2
		:y=${yOffset}
		${fontOptions}"
  fi

  #	rhs overlay text
  #
  #	note that using this form of timecode fucks up the 'expansion' mode
  #	and doesn't seem to work with builitin expanded text/variables
  #
  overlayTC=$( GetGlobalVal overlayTC )

  if [ ${overlayTC} -ne 0 ]; then

    filter+=",drawtext=expansion=normal
		:timecode='00\:00\:00\:00'
		:timecode_rate=${fps}
		:text='\ ${fps}fps TC\ '
		:x=(w*.975)-text_w
		:y=${yOffset}
		${fontOptions}"
  fi

#	rhs lower milisecond based timecode - not using at the moment, but
#	keeping the code around
#
let tmp=($fontSize * 2)
let yOffset=($yOffset - $tmp)

Zfilter+="
,drawtext=expansion=normal
:text='\ %{pts\:hms}'
:x=(w*.975)-text_w
:y=${yOffset}
${fontOptions}
"

  #	Call function that loops over the Globals array to get all the
  #	settings. This will be added to the comment metadata tag of the
  #	output video.
  #
  metaString=$( MakeMetaString )

#echo "metaString: '${metaString}'"
#exit

#	 -framerate $fps	\

  ffmpeg -hide_banner -y				\
	 -f image2 					\
	 -pattern_type glob				\
	 -i "${iDir}/*.${suffix}"			\
	 -filter_complex "[0:v]${filter}[v]"		\
	 -map [v] 					\
	 -metadata ${MetadataKey}="${metaString}"	\
	"${oFile}"

}		# eo MakeMkv()

#	Traverse all of the globals return a string with all the key/val pairs
#
MakeMetaString()
{
local i
local nEntries
local entry
local meta=""

  let nEntries=(${#Globals[@]})

  for ((i=0; i<$nEntries; i++)); do

    entry="${Globals[$i]}"

    meta+="${entry}\n"

  done

  echo -e "${meta}"

}		# eo MakeMetaString()


#	Run this after making the .mkv to copy the video stream
#	into a .mp4 container
#
MakeMp4()
{
local iFile="${1}"
local oFile="${2}"
local func="${FUNCNAME}()"

  echo "${Dash}"
  echo -e "${func}\n"

  if [ ! -f "${iFile}" ]; then
    echo "${func} Bailing. Can't locate source file: '${iFile}'"
    exit 1
  fi

  ffmpeg -hide_banner -y	\
	 -i "${iFile}"		\
	 -c copy		\
	 -movflags +faststart	\
	 "${oFile}"

}		# eo MakeMp4()

#	Use hardware accelleration on the Mac - will need a different
#	routine for linux machines
#
#	Could build a test along the lines of:
#
#		ffmpeg -hide_banner -hwaccels | \
#			grep -e videotoolbox -e vaapi  | sort -u
#
MakeMp4HWA()
{
local iFile="${1}"
local oFile="${2}"
local videoRate
local encoder="h264_videotoolbox"		# h264 hardware encoder on Mac
#local encoder="hevc_videotoolbox"		# h265 hardware encoder on Mac
local metaString
local func="${FUNCNAME}()"

  echo "${Dash}"
  echo -e "${func}\n"

  if [ ! -f "${iFile}" ]; then
    echo "${func} Bailing. Can't locate source file: '${iFile}'"
    exit 1
  fi

  videoRate=$( GetGlobalVal videoRate )

  #	If videoRate isn't hard-coded use a basic formula to calculate
  #	the bitrate that seems suited to the level of detail of thes maps
  #
  #	Currently not testing that fps and outHeight are set
  #
  if [ "${videoRate}" == "${nil}" ]; then  

    local oHeight=$( GetGlobalVal outHeight )
    local fps=$( GetGlobalVal fps )

#    local kbps=$( echo "scale=0;${oHeight} * ($fps / 4 )" | bc -l )
    local kbps=$( echo "scale=0;${oHeight} * ($fps * .3 )" | bc -l )

    videoRate="${kbps}k"

  fi			# eo if videoRate = $nil

  #	Add the videoRate to globals so it shows up in the metadata
  #
  SetGlobalVal videoRate ${videoRate}

  echo -e "Transcoding video with bitrate: '${videoRate}'\n"

  metaString=$( MakeMetaString )

#	 -c:v hevc_videotoolbox \	# h265 hardware encoder on Mac

  ffmpeg -hide_banner -y				\
	 -i "${iFile}"					\
	 -map v						\
	 -c:v ${encoder}				\
	 -b:v ${videoRate}				\
	 -metadata ${MetadataKey}="${metaString}"	\
-metadata show="noaa"	 \
	 -movflags +faststart				\
	 "${oFile}"

}		# eo MakeMp4HWA()

#	EOF (End of File)
