MEXBIN ?= mex
MEXOPT  =
OBJEXT ?= o
LIBEXT ?= a
MAKE    = make
MOVE    = mv -f
DEL     = rm -f
GIT     = git
MATLAB  = matlab -nodesktop -nodisplay -nosplash -batch
OCTAVE  = octave --no-gui --quiet --eval
EXEC   ?= $(MATLAB)

PLATFORM ?= $(shell uname)

ifeq ($(PLATFORM),Linux)
  MEXEXT = mexa64
endif

ifeq ($(PLATFORM),Darwin)
  MEXEXT = mexmaca64
  ifndef WHISPER_NO_ACCELERATE
    MEXOPT += LDFLAGS='$$LDFLAGS -framework Accelerate'
  endif
  ifndef WHISPER_NO_METAL
    MEXOPT += LDFLAGS='$$LDFLAGS -framework Foundation -framework Metal -framework MetalKit'
  endif
endif

ifndef MEXEXT
  MEXEXT = mexw64
  MEXOPT += CLIBS='$$CLIBS -lstdc++'
endif


all: @whisper/private/whisper_mex.$(MEXEXT)

@whisper/private/whisper_mex.$(MEXEXT): @whisper/private/whisper_mex.c whisper.cpp/libwhisper.$(LIBEXT)
	$(MEXBIN) @whisper/private/whisper_mex.c -I. whisper.cpp/libwhisper.$(LIBEXT) $(MEXOPT)
	$(MOVE) whisper_mex.$(MEXEXT) @whisper/private/

whisper.cpp/libwhisper.$(LIBEXT):
	$(MAKE) -C whisper.cpp libwhisper.$(LIBEXT)

clean:
	$(DEL) whisper.cpp/*.$(OBJEXT) whisper.cpp/*.$(LIBEXT) @whisper/private/whisper_mex.$(MEXEXT)
        
update:
	$(GIT) submodule update --remote --merge --recursive

test: @whisper/private/whisper_mex.$(MEXEXT)
	$(EXEC) "whisper.demo()"
