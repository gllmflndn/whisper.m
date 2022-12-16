MEXBIN ?= mex
MEXEXT ?= mexa64
MEXOPT  =
OBJEXT ?= o
MAKE    = make
MOVE    = mv -f
DEL     = rm -f

ifndef WHISPER_NO_ACCELERATE
  ifeq ($(shell uname -s),Darwin)
    MEXOPT += LDFLAGS='$$LDFLAGS -framework Accelerate'
  endif
endif


all: @whisper/private/whisper_mex.$(MEXEXT)

@whisper/private/whisper_mex.$(MEXEXT): @whisper/private/whisper_mex.c whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT)
	$(MEXBIN) @whisper/private/whisper_mex.c -I. whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT) $(MEXOPT)
	$(MOVE) whisper_mex.$(MEXEXT) @whisper/private/

whisper.cpp/ggml.$(OBJEXT): whisper.cpp/ggml.c whisper.cpp/ggml.h
	$(MAKE) -C whisper.cpp ggml.$(OBJEXT)

whisper.cpp/whisper.$(OBJEXT): whisper.cpp/whisper.cpp whisper.cpp/whisper.h
	$(MAKE) -C whisper.cpp whisper.$(OBJEXT)

clean:
	$(DEL) -f whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT) @whisper/private/whisper_mex.$(MEXEXT)
