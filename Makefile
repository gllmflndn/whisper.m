MEX = mex
MEXEXT = mexa64
OBJEXT = o
CFLAGS = -O3 -mavx -mavx2 -mfma -mf16c # see whisper.cpp/Makefile

all: @whisper/private/whisper_mex.$(MEXEXT)

@whisper/private/whisper_mex.$(MEXEXT): speech2text.cpp @whisper/private/ggml.$(OBJEXT) @whisper/private/whisper.$(OBJEXT)
	$(MEX) @whisper/private/whisper_mex.cpp -I. @whisper/private/ggml.$(OBJEXT) @whisper/private/whisper.$(OBJEXT) -outdir @whisper/private/

@whisper/private/whisper.$(OBJEXT): whisper.cpp/whisper.cpp whisper.cpp/whisper.h
	$(MEX) -c whisper.cpp/whisper.cpp -outdir @whisper/private/

@whisper/private/ggml.$(OBJEXT): whisper.cpp/ggml.c whisper.cpp/ggml.h
	$(MEX) CFLAGS='$$CFLAGS ${CFLAGS}' -c whisper.cpp/ggml.c -outdir @whisper/private/
