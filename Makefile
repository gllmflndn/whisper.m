MEX = mex
MEXEXT = mexa64
OBJEXT = o

all: speech2text.$(MEXEXT)

speech2text.$(MEXEXT): speech2text.cpp ggml.$(OBJEXT) whisper.$(OBJEXT)
	$(MEX) speech2text.cpp ggml.$(OBJEXT) whisper.$(OBJEXT)

whisper.$(OBJEXT): whisper.cpp/whisper.cpp whisper.cpp/whisper.h
	$(MEX) -c whisper.cpp/whisper.cpp -outdir .

ggml.$(OBJEXT): whisper.cpp/ggml.c whisper.cpp/ggml.h
	$(MEX) CFLAGS='$$CFLAGS -O3 -mavx -mavx2 -mfma -mf16c' -c whisper.cpp/ggml.c -outdir .
# see whisper.cpp/Makefile
