[y,Fs] = audioread('sounds/FEP-Friston.wav');
assert(Fs==16000,'16kHz only');
%speech2text(single(y));

mex whisper_mex.cpp whisper.o ggml.o

ctx = whisper_mex('init','whisper.cpp/models/ggml-base.en.bin');
whisper_mex('run',ctx,single(y),struct('new_segment_callback',@()disp('hello')))
whisper_mex('free',ctx)
