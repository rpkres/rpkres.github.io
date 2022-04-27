#!/bin/bash

set -eu                         # -e stop on errors, -u stop on unset vars
                                # note, exits in sourced functions don't work

volName="awdpx"			# gets mounted to /Volumes/$volName
dmgPath="awdpx"			# name of physical dmg file on disc

#	Type 'man hdiutil' and search for UDIF for explation of
#	various empty image formats. UDIF gets set to the size you
#	specify, the others are dynamic and grow as needed.
#
type="UDIF"
#type="SPARSE"
#type="SPARSEBUNDLE"
prog=$(basename "${0}")

size="1g"			# might want to make a sparse soon
size="300m"

  if  [ -e "${dmgPath}.dmg" ] ; then
    echo "${prog} Exiting. DMG already exists: '${dmgPath}'"
    exit 1
  fi

  hdiutil create	-type ${type} 			\
			-size ${size}			\
			-fs HFS+J 			\
			-volname "${volName}" 		\
			"${dmgPath}"

exit 0
