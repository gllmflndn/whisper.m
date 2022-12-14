# whisper.m

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Automatic speech recognition in MATLAB/Octave based on the excellent [whisper.cpp](https://github.com/ggerganov/whisper.cpp) from [Georgi Gerganov](https://github.com/ggerganov) and models from [OpenAI's Whisper](https://github.com/openai/whisper).

## Demo

```
>> whisper.demo()
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
whisper_model_load: f16           = 1
whisper_model_load: type          = 1
whisper_model_load: adding 1607 extra tokens
whisper_model_load: mem_required  =  390.00 MB
whisper_model_load: ggml ctx size =   73.58 MB
whisper_model_load: memory size   =   11.41 MB
whisper_model_load: model size    =   73.54 MB
```
<font color="#FF8700"> And</font><font color="#87FF00"> so</font><font color="#FF5F00"> my</font><font color="#5FFF00"> fellow</font><font color="#D7FF00"> Americans</font><font color="#FF0000"> ask</font><font color="#FFFF00"> not</font><font color="#FFAF00"> what</font><font color="#87FF00"> your</font><font color="#5FFF00"> country</font><font color="#87FF00"> can</font><font color="#5FFF00"> do</font><font color="#AFFF00"> for</font><font color="#87FF00"> you</font><font color="#FFFF00"> ask</font><font color="#5FFF00"> what you can do for your country</font>

## Usage

```matlab
hW = whisper('small');
[segments,tokens] = hW.run('speech.wav',...
                        'print_realtime',true,'print_progress',false);
whisper.display_tokens(tokens);
```