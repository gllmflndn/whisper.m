MEXBIN ?= mex
MEXOPT  =
OBJEXT ?= o
LIBEXT ?= a
MAKE    = make
CMAKE   = cmake
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

@whisper/private/whisper_mex.$(MEXEXT): @whisper/private/whisper_mex.c whisper.cpp/install/lib/libwhisper.$(LIBEXT)
	$(MEXBIN) @whisper/private/whisper_mex.c -Iwhisper.cpp/install/include/ whisper.cpp/install/lib/*.$(LIBEXT) $(MEXOPT)
	$(MOVE) whisper_mex.$(MEXEXT) @whisper/private/

whisper.cpp/install/lib/libwhisper.$(LIBEXT):
	$(CMAKE) -S whisper.cpp/ -B whisper.cpp/build  -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=whisper.cpp/install -DCMAKE_BUILD_TYPE=Release 
	$(CMAKE) --build whisper.cpp/build
	$(CMAKE) --build whisper.cpp/build --target install

.PHONY: clean
clean:
	$(CMAKE) --build whisper.cpp/build --target clean
	$(DEL) @whisper/private/whisper_mex.$(MEXEXT)

.PHONY: update
update:
	$(GIT) submodule update --remote --merge --recursive

.PHONY: test
test: @whisper/private/whisper_mex.$(MEXEXT)
	$(EXEC) "whisper.demo()"
