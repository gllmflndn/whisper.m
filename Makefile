MEXBIN ?= mex
MEXOPT  =
OBJEXT ?= o
MAKE    = make
MOVE    = mv -f
DEL     = rm -f
MATLAB  = matlab -nodesktop -nodisplay -nosplash -batch
OCTAVE  = octave --no-gui --quiet --eval
EXEC   ?= $(MATLAB)

PLATFORM ?= $(shell uname)

ifeq ($(PLATFORM),Linux)
  MEXEXT = mexa64
endif

ifeq ($(PLATFORM),Darwin)
  MEXEXT = mexmaci64
  ifndef WHISPER_NO_ACCELERATE
    MEXOPT += LDFLAGS='$$LDFLAGS -framework Accelerate'
  endif
endif

ifndef MEXEXT
  MEXEXT = mexw64
  MEXOPT += CLIBS='$$CLIBS -lstdc++'
endif


all: @whisper/private/whisper_mex.$(MEXEXT)

@whisper/private/whisper_mex.$(MEXEXT): @whisper/private/whisper_mex.c whisper.cpp/ggml.$(OBJEXT) whisper.cpp/ggml-alloc.$(OBJEXT) whisper.cpp/ggml-backend.$(OBJEXT) whisper.cpp/ggml-quants.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT)
	$(MEXBIN) @whisper/private/whisper_mex.c -I. whisper.cpp/ggml.$(OBJEXT) whisper.cpp/ggml-alloc.$(OBJEXT) whisper.cpp/ggml-backend.$(OBJEXT) whisper.cpp/ggml-quants.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT) $(MEXOPT)
	$(MOVE) whisper_mex.$(MEXEXT) @whisper/private/

whisper.cpp/ggml.$(OBJEXT): whisper.cpp/ggml.c whisper.cpp/ggml.h
	$(MAKE) -C whisper.cpp ggml.$(OBJEXT)

whisper.cpp/ggml-alloc.$(OBJEXT): whisper.cpp/ggml-alloc.c whisper.cpp/ggml.h whisper.cpp/ggml-alloc.h
	$(MAKE) -C whisper.cpp ggml-alloc.$(OBJEXT)
        
whisper.cpp/ggml-backend.$(OBJEXT): whisper.cpp/ggml-backend.c whisper.cpp/ggml.h whisper.cpp/ggml-backend.h
	$(MAKE) -C whisper.cpp ggml-backend.$(OBJEXT)
        
whisper.cpp/ggml-quants.$(OBJEXT): whisper.cpp/ggml-quants.c whisper.cpp/ggml.h whisper.cpp/ggml-quants.h
	$(MAKE) -C whisper.cpp ggml-quants.$(OBJEXT)

whisper.cpp/whisper.$(OBJEXT): whisper.cpp/whisper.cpp whisper.cpp/whisper.h
	$(MAKE) -C whisper.cpp whisper.$(OBJEXT)

clean:
	$(DEL) -f whisper.cpp/ggml.$(OBJEXT) whisper.cpp/whisper.$(OBJEXT) @whisper/private/whisper_mex.$(MEXEXT)
        
update:
	git submodule update --remote --merge

test: @whisper/private/whisper_mex.$(MEXEXT)
	$(EXEC) "whisper.demo()"
