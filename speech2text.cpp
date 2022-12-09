
#include <cmath>
#include <fstream>
#include <cstdio>
#include <string>
#include <thread>
#include <vector>

#include "whisper.cpp/whisper.h"
#include "mex.h"

// Terminal color map. 10 colors grouped in ranges [0.0, 0.1, ..., 0.9]
// Lowest is red, middle is yellow, highest is green.
const std::vector<std::string> k_colors = {
    "\033[38;5;196m", "\033[38;5;202m", "\033[38;5;208m", "\033[38;5;214m", "\033[38;5;220m",
    "\033[38;5;226m", "\033[38;5;190m", "\033[38;5;154m", "\033[38;5;118m", "\033[38;5;82m",
};

//  500 -> 00:05.000
// 6000 -> 01:00.000
std::string to_timestamp(int64_t t, bool comma = false) {
    int64_t msec = t * 10;
    int64_t hr = msec / (1000 * 60 * 60);
    msec = msec - hr * (1000 * 60 * 60);
    int64_t min = msec / (1000 * 60);
    msec = msec - min * (1000 * 60);
    int64_t sec = msec / 1000;
    msec = msec - sec * 1000;

    char buf[32];
    snprintf(buf, sizeof(buf), "%02d:%02d:%02d%s%03d", (int) hr, (int) min, (int) sec, comma ? "," : ".", (int) msec);

    return std::string(buf);
}


int timestamp_to_sample(int64_t t, int n_samples) {
    return std::max(0, std::min((int) n_samples - 1, (int) ((t*WHISPER_SAMPLE_RATE)/100)));
}

struct whisper_params {
    int32_t n_threads    = std::min(4, (int32_t) std::thread::hardware_concurrency());
    int32_t n_processors = 1;
    int32_t offset_t_ms  = 0;
    int32_t offset_n     = 0;
    int32_t duration_ms  = 0;
    int32_t max_context  = -1;
    int32_t max_len      = 0;

    float word_thold = 0.01f;

    bool speed_up      = false;
    bool translate     = false;
    bool diarize       = false;
    bool output_txt    = false;
    bool output_vtt    = false;
    bool output_srt    = false;
    bool output_wts    = false;
    bool print_special = false;
    bool print_colors  = true;
    bool no_timestamps = false;

    std::string language  = "en";
    std::string model     = "whisper.cpp/models/ggml-base.en.bin";

    std::vector<std::string> fname_inp = {};
};

struct whisper_print_user_data {
    const whisper_params * params;

    //const std::vector<std::vector<float>> * pcmf32s;
};

void whisper_print_segment_callback(struct whisper_context * ctx, int n_new, void * user_data) {
    const auto & params  = *((whisper_print_user_data *) user_data)->params;
    //const auto & pcmf32s = *((whisper_print_user_data *) user_data)->pcmf32s;

    const int n_segments = whisper_full_n_segments(ctx);

    // print the last n_new segments
    const int s0 = n_segments - n_new;
    //if (s0 == 0) {
    //    printf("\n");
    //}

    for (int i = s0; i < n_segments; i++) {
        if (params.no_timestamps) {
            if (params.print_colors) {
                for (int j = 0; j < whisper_full_n_tokens(ctx, i); ++j) {
                    if (params.print_special == false) {
                        const whisper_token id = whisper_full_get_token_id(ctx, i, j);
                        if (id >= whisper_token_eot(ctx)) {
                            continue;
                        }
                    }

                    const char * text = whisper_full_get_token_text(ctx, i, j);
                    const float  p    = whisper_full_get_token_p   (ctx, i, j);

                    const int col = std::max(0, std::min((int) k_colors.size(), (int) (std::pow(p, 3)*float(k_colors.size()))));

                    printf("%s%s%s", k_colors[col].c_str(), text, "\033[0m");
                }
            } else {
                const char * text = whisper_full_get_segment_text(ctx, i);
                printf("%s", text);
            }
            fflush(stdout);
        } else {
            const int64_t t0 = whisper_full_get_segment_t0(ctx, i);
            const int64_t t1 = whisper_full_get_segment_t1(ctx, i);

            std::string speaker = "";

            //if (params.diarize && pcmf32s.size() == 2) {
            //    const int64_t n_samples = pcmf32s[0].size();
//
            //    const int64_t is0 = timestamp_to_sample(t0, n_samples);
            //    const int64_t is1 = timestamp_to_sample(t1, n_samples);
//
            //    double energy0 = 0.0f;
            //    double energy1 = 0.0f;

            //    for (int64_t j = is0; j < is1; j++) {
            //        energy0 += fabs(pcmf32s[0][j]);
            //        energy1 += fabs(pcmf32s[1][j]);
            //    }

            //    if (energy0 > 1.1*energy1) {
            //        speaker = "(speaker 0)";
            //    } else if (energy1 > 1.1*energy0) {
            //        speaker = "(speaker 1)";
            //    } else {
            //        speaker = "(speaker ?)";
            //    }

                //printf("is0 = %lld, is1 = %lld, energy0 = %f, energy1 = %f, %s\n", is0, is1, energy0, energy1, speaker.c_str());
            //}

            if (params.print_colors) {
                printf("[%s --> %s]  ", to_timestamp(t0).c_str(), to_timestamp(t1).c_str());
                for (int j = 0; j < whisper_full_n_tokens(ctx, i); ++j) {
                    if (params.print_special == false) {
                        const whisper_token id = whisper_full_get_token_id(ctx, i, j);
                        if (id >= whisper_token_eot(ctx)) {
                            continue;
                        }
                    }

                    const char * text = whisper_full_get_token_text(ctx, i, j);
                    const float  p    = whisper_full_get_token_p   (ctx, i, j);

                    const int col = std::max(0, std::min((int) k_colors.size(), (int) (std::pow(p, 3)*float(k_colors.size()))));

                    printf("%s%s%s%s", speaker.c_str(), k_colors[col].c_str(), text, "\033[0m");
                }
                printf("\n");
            } else {
                const char * text = whisper_full_get_segment_text(ctx, i);

                printf("[%s --> %s]  %s%s\n", to_timestamp(t0).c_str(), to_timestamp(t1).c_str(), speaker.c_str(), text);
            }
        }
    }
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    whisper_params params;
    
    //FILE *FID = freopen("/dev/null", "w", stderr); // silence whisper_model_load in whisper_init
    
    struct whisper_context * ctx = whisper_init(params.model.c_str());

    //fclose(FID);

    if (nrhs < 1) {
        mexErrMsgTxt("Sound input missing");
    }
    if (!mxIsSingle(prhs[0])) {
        mexErrMsgTxt("Input has to be single-precision, floating-point numbers");
    }
    size_t n = mxGetNumberOfElements(prhs[0]);
    float *data = (float*)mxGetData(prhs[0]);

    if (ctx == nullptr) {
        mexErrMsgTxt("Failed to initialize whisper context");
    }
    
    std::vector<float> pcmf32; // mono-channel F32 PCM
    //std::vector<std::vector<float>> pcmf32s; // stereo-channel F32 PCM

    pcmf32.resize(n);
    for (int i = 0; i < n; i++) {
        pcmf32[i] = data[i];
    }

    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    wparams.print_realtime   = false;
    wparams.print_progress   = false;
    wparams.print_timestamps = !params.no_timestamps;
    wparams.print_special    = params.print_special;
    wparams.translate        = params.translate;
    wparams.language         = params.language.c_str();
    wparams.n_threads        = params.n_threads;
    wparams.n_max_text_ctx   = params.max_context >= 0 ? params.max_context : wparams.n_max_text_ctx;
    wparams.offset_ms        = params.offset_t_ms;
    wparams.duration_ms      = params.duration_ms;

    wparams.token_timestamps = params.output_wts || params.max_len > 0;
    wparams.thold_pt         = params.word_thold;
    wparams.max_len          = params.output_wts && params.max_len == 0 ? 60 : params.max_len;

    wparams.speed_up         = params.speed_up;

    whisper_print_user_data user_data = { &params }; //, &pcmf32s };

    if (!wparams.print_realtime) {
        wparams.new_segment_callback           = whisper_print_segment_callback;
        wparams.new_segment_callback_user_data = &user_data;
    }

    if (whisper_full_parallel(ctx, wparams, pcmf32.data(), pcmf32.size(), params.n_processors) != 0) {
        mexErrMsgTxt("failed to process audio");
    }

    whisper_free(ctx);
    
}
