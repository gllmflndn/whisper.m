[y,Fs] = audioread('whisper.cpp/samples/jfk.wav');

%Fs has to be 16000

speech2text(single(y));
