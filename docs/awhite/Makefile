IBASE=ffmpeg-4.2.2-macos64-static
ODIR=/usr/local/bin
IDOC=${IBASE}/doc
ODOC=/usr/local/share/doc/ffmpeg/html
USER=rpk

PROG1=ffmpeg
PROG2=ffprobe
PROG3=ffplay

all:	${ODIR}/${PROG1} 	\
	${ODIR}/${PROG2}	\
	${ODIR}/${PROG3}	

${ODIR}/${PROG1}: ${IBASE}/bin/${PROG1}
	sudo install -o ${USER} -g staff $? ${ODIR}

${ODIR}/${PROG2}: ${IBASE}/bin/${PROG2}
	sudo install -o ${USER} -g staff $? ${ODIR}

${ODIR}/${PROG3}: ${IBASE}/bin/${PROG3}
	sudo install -o ${USER} -g staff $? ${ODIR}

DOCS:	${IDOC}/*.css ${IDOC}/*.html
	sudo install -m 644 $? ${ODOC}




