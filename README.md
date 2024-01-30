# whisper.m

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/gllmflndn/whisper.m/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/gllmflndn/whisper.m/actions/workflows/test.yml)

Automatic speech recognition in MATLAB/Octave based on the excellent [whisper.cpp](https://github.com/ggerganov/whisper.cpp) from [Georgi Gerganov](https://github.com/ggerganov) and models from [OpenAI's Whisper](https://github.com/openai/whisper).

## Installation

First, clone the repository with submodules:

```
git clone --recurse-submodules https://github.com/gllmflndn/whisper.m.git
```

### MATLAB

Run `make` from a Terminal:

```
make
```

The Accelerate and Metal frameworks will be used on macOS. On Windows, use [MSYS2](https://www.msys2.org/) and [MinGW-w64](https://www.mingw-w64.org/), see [MATLAB Support](https://uk.mathworks.com/matlabcentral/fileexchange/52848-matlab-support-for-mingw-w64-c-c-compiler).

### GNU Octave

Run the following from a Terminal:

```
make MEXBIN="mkoctfile --mex" MEXEXT=mex MEXOPT=""
```

## Usage

To run `whisper.m` on a pre-recorded audio file (mono, 16kHz) called `input.wav`:

```matlab
w = whisper('small');
[segments,tokens] = w.transcribe('input.wav',...
                                 'print_realtime', true,...
                                 'print_progress', false);
whisper.display_tokens(tokens);
```

Pre-trained models will be downloaded automatically from [Hugging Face](https://huggingface.co/ggerganov/whisper.cpp) when needed and stored in a `models` directory. Model options are `tiny`, `tiny.en`, `base`, `base.en`, `small`, `small.en`, `medium`, `medium.en` and `large`.

Another example to record audio data and run `whisper.m`:

```matlab
Fs = 16000;
nbits = 16;
nchannels = 1;
id = 1; % see audiodevinfo to select the audio device
rec = audiorecorder(Fs, nbits, nchannels, id);

recDuration = 10;
disp('Begin speaking.')
recordblocking(rec, recDuration);
disp('End of recording.')
y = getaudiodata(rec);

w = whisper('small');
[segments,tokens] = w.transcribe(y','print_progress', false);
whisper.display_tokens(tokens);
```

To extrac the audio track from a video at 16kHz mono, you can use `ffmpeg`:

```
ffmpeg -i video.mp4 -f wav -ar 16000 -ac 1 -vn  audio.wav
```

There is also a demo that uses an audio file shipped with `whisper.cpp`:

```
>> whisper.demo()
whisper_model_load: loading model
whisper_model_load: n_vocab       = 51864
whisper_model_load: n_audio_ctx   = 1500
whisper_model_load: n_audio_state = 384
whisper_model_load: n_audio_head  = 6
whisper_model_load: n_audio_layer = 4
whisper_model_load: n_text_ctx    = 448
whisper_model_load: n_text_state  = 384
whisper_model_load: n_text_head   = 6
whisper_model_load: n_text_layer  = 4
whisper_model_load: n_mels        = 80
whisper_model_load: ftype         = 1
whisper_model_load: qntvr         = 0
whisper_model_load: type          = 1
whisper_model_load: adding 1607 extra tokens
whisper_model_load: model ctx     =   73.62 MB
whisper_model_load: model size    =   73.54 MB
whisper_init_state: kv self size  =    2.62 MB
whisper_init_state: kv cross size =    8.79 MB
whisper_init_state: compute buffer (conv)   =   11.17 MB
whisper_init_state: compute buffer (encode) =   61.76 MB
whisper_init_state: compute buffer (cross)  =    3.67 MB
whisper_init_state: compute buffer (decode) =   18.82 MB
```
<font color="#FF8700"> And</font><font color="#87FF00"> so</font><font color="#FF5F00"> my</font><font color="#5FFF00"> fellow</font><font color="#D7FF00"> Americans</font><font color="#FF0000"> ask</font><font color="#FFFF00"> not</font><font color="#FFAF00"> what</font><font color="#87FF00"> your</font><font color="#5FFF00"> country</font><font color="#87FF00"> can</font><font color="#5FFF00"> do</font><font color="#AFFF00"> for</font><font color="#87FF00"> you</font><font color="#FFFF00"> ask</font><font color="#5FFF00"> what you can do for your country</font>
