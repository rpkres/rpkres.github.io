#!/bin/bash

Usage()
{
local fps=$( GetGlobalVal fps )
local inHeight=$( GetGlobalVal inHeight )
local outHeight=$( GetGlobalVal outHeight )
local fontSize=$( GetGlobalVal fontSize )
local suffix=$( GetGlobalVal suffix )

cat <<EOD

Usage:  ${Prog} [option] inputHeight directory

	-c, --comment <string>	Write <string> to the metadata 'comment' tag.

	-fh, 			Number of <int> pixels to crop from bottom of
	--footerHeight <int>	input images.

	-fps, --fps <int>	Ouput movie's playback <int> frames per second
				(default '${fps}').

	-fs, --fontSize <int>	Overlay text font size in <int> pixels
				(default '${fontSize}').

         -h, --help    		Print this message and exit.

	-noclean, --noClean	Purge intermediary files upon completion
				(default is to remove them).

	-noframe, --noFrame	Turn off frame number overlay (default on).
	-noname, --noName	Turn off file name overlay (default on).
	-noTC, --noTC		Turn off TimeCode overlay (default on).

	-nooverlay, --noOverlay No overlays are rendered.
				(same as --noFrame, --noName and --noTC).

	-of, --outFile <string> Set the output movie name to <string>
				Default is to the input directory name.mp4

	-oh, --outHeight <int>	Set the output movie height to <int> pixels.
				Default is the same height as the input.

        -s, --suffix <string>	Set the filename suffix to <string> (default 
        			'${suffix}'). Any files ending in this suffix 
				in the input directory are added to the movie.


        ${Prog} runs ffmpeg on the files in the specified
	directory writing a .mp4 movie with the directory name as a suffix.

	Input images are expected to be 'inputHeight' pixels high.

	The output movie will be scaled to 'outHeight' pixels high,
	which is the same height as the input image unless set with the
	--outHeight option.

	The NOAA footer can be cropped out by specifying the --footerHeight
	option, this should be an even number as it will affect the
	calculation by ffmpeg of the output width.

	Note that the output width is calculated by ffmpeg based on the
	'outHeight'. ffmpeg wil exit if the calculated width isn't
	divisible by 2.


EOD

exit 1

}		# eo Usage()

#	EOF (End of File)
