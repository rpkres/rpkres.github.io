#!/bin/bash

Usage()
{
local hourStart=$( GetGlobalVal hourStart )
local hourEnd=$( GetGlobalVal hourEnd )
local numberOfDays=$( GetGlobalVal numberOfDays )
local resolution=$( GetGlobalVal resolution )
local interval=$( GetGlobalVal interval )
local addMeta=$( GetGlobalVal addMeta )
local execCurl=$( GetGlobalVal execCurl )
local suffix=$( GetGlobalVal suffix )
local desc=$( GetGlobalVal descPart )
local urlBase=$( GetGlobalVal urlPathBase )
local oDirPrefix=$( GetGlobalVal oDirPrefix )
local oDate=$( date +"%Y.%m.%d" )
local oDir
local oNamePrefix=$( GetGlobalVal oNamePrefix )
local curlRateLimit=$( GetGlobalVal curlRateLimit )

  oDir="${oDirPrefix}-${oDate}-${resolution}"

cat<<EOD

Usage:  ${Prog} [option]

        -at, --addTags <bool>	Add metadata to download (default '${addMeta}').

        -d, --desc <str>	Description part of filename to download
				(default '${desc}').  

        -ec, --execCurl <bool>	Execute curl(1) (default '${execCurl}').  

        -h, --help    		Print this message and exit.

	-he, --hourEnd <int>	Set hour end to download
				(default '${hourEnd}').

	-hs, --hourStart <int>	Set hour start to download  
				(default '${hourStart}').

	-i, --interval <int>	No. minutes between each snapshot image
				(default '${interval}').

	-nd, 			Number of days back from including today to
	--numberOfDays <int>	download (default '${numberOfDays}').

	-odp, 			Set the output directory name prefix to <str>
	--outDirPrefix <str>	(default '${oDirPrefix}'").

	-onp, 			Set the output file name prefix to <str>
	--outNamePrefix <str>	(default '${oNamePrefix}'").

	-od, --outDir <str>	Override the output directory name to <str>.

				Default is built from prefix-YY.mm.dd-resolution
				e.g. '${oDir}'

	-r, --resoultion 	Resolution of input images
	      <width>x<height>	(default '${resolution}').

	-rl, --rateLimit <str> 	Sets the curl download bandwidth rate limit
				(default '${curlRateLimit}').

	-s, --suffix <str>	File suffix <str> of the files to download
				(default '${suffix}').

	-ub, --urlBase <str>	Use <str> for url base of files to download 
			(default '${urlBase}').

        ${Prog} downloads individual satellite images from a NOAA
	site using curl(1).


EOD

exit 1

}		# eo Usage()

#	EOF (End of File)
