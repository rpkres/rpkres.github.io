#!/bin/bash

set -eu                         # -e stop on errors, -u stop on unset vars
                                # note, exits in sourced functions don't work

volName="awdpx"			# gets mounted to /Volumes/$volName
dmgPath="awdpx"			# name of physical dmg file on disc

#	Type 'man hdiutil' and search for UDIF for explation of
#	various empty image formats. UDIF gets set to the size you
#	specify, the others are dynamic and grow as needed.
#
#	To open the man page for hdiutl(1) in Preview on the mac, type the 
#	following on the command line:
#
#		man -t hdiutil | open -f -a Preview.app
#	
#	If the type is dynamic (SPARSE..) you can reclaim space at a later
#	time by running:
#
#		hdiutil compact "${iFile}"
#
#	or resize it it it's +HFS or APFS:
#
#		hdiutil resize -size 2g "${iFile}"
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
