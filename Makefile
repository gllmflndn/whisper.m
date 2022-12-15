MEX    ?= mex
MEXEXT ?= mexa64
OBJEXT ?= o
MAKE   = make
MOVE   = mv -f
DEL    = rm -f

all: @whisper/private/whisper_mex.$(MEXEXT)

@whisper/private/whisper_mex.$(MEXEXT): @whisper/private/whisper_mex.c whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT)
	$(MEX) @whisper/private/whisper_mex.c -I. whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT)
	$(MOVE) whisper_mex.$(MEXEXT) @whisper/private/

whisper.cpp/ggml.$(OBJEXT): whisper.cpp/ggml.c whisper.cpp/ggml.h
	$(MAKE) -C whisper.cpp ggml.$(OBJEXT)

whisper.cpp/whisper.$(OBJEXT): whisper.cpp/whisper.cpp whisper.cpp/whisper.h
	$(MAKE) -C whisper.cpp whisper.$(OBJEXT)

clean:
	$(DEL) -f whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT) @whisper/private/whisper_mex.$(MEXEXT)
