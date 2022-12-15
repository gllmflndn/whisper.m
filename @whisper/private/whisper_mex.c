/*
 * Copyright (C) 2022 Guillaume Flandin
 */

#include "whisper.cpp/whisper.h"
#include "mex.h"

#include <string.h>

static struct whisper_context *get_whisper_context (const mxArray *c) {
    if (!mxIsUint64 (c) || mxGetNumberOfElements (c) != 1)
        mexErrMsgIdAndTxt ("whisper:context", "Context handle is not valid.");
    return (struct whisper_context*)(((uint64_t*)mxGetData (c))[0]);
}

static mxArray *get_tokens (struct whisper_context *ctx, int n_new) {
    const int n_segments = whisper_full_n_segments (ctx);
    if (n_new < 0) {
        n_new = n_segments;
    };
    const int s0 = n_segments - n_new;
    int n_tokens = 0;
    for (int i = s0; i < n_segments; ++i) {
        n_tokens += whisper_full_n_tokens (ctx, i);
    }
    const char *fields[] = {"text", "p", "t0", "t1", "segment"};
    mxArray *mx = mxCreateStructMatrix (1, n_tokens, 5, fields);
    int k = 0;
    for (int i = s0; i < n_segments; ++i) {
        for (int j = 0; j < whisper_full_n_tokens (ctx, i); ++j) {
            if (true) { // (wparams.print_special == false) {
                const whisper_token id = whisper_full_get_token_id (ctx, i, j);
                if (id >= whisper_token_eot (ctx)) {
                    continue;
                }
            }

            const char * text = whisper_full_get_token_text (ctx, i, j);
            const whisper_token_data data = whisper_full_get_token_data (ctx, i, j);
            mxSetFieldByNumber (mx, k, 0, mxCreateString (text));
            mxSetFieldByNumber (mx, k, 1, mxCreateDoubleScalar (data.p));
            // requires option ('token_timestamps',true) otherwise t0,t1 set to -1
            mxSetFieldByNumber (mx, k, 2, mxCreateDoubleScalar (data.t0));
            mxSetFieldByNumber (mx, k, 3, mxCreateDoubleScalar (data.t1));
            mxSetFieldByNumber (mx, k, 4, mxCreateDoubleScalar (i + 1));
            k++;
        }
    }
    return mx;
}

static mxArray *get_segments (struct whisper_context *ctx, int n_new) {
    const int n_segments = whisper_full_n_segments (ctx);
    if (n_new < 0) {
        n_new = n_segments;
    };
    const int s0 = n_segments - n_new;
    const char *fields[] = {"text", "t0", "t1"};
    mxArray *mx = mxCreateStructMatrix (1, n_segments, 3, fields);
    for (int i = s0; i < n_segments; ++i) {
        const int64_t t0 = whisper_full_get_segment_t0 (ctx, i);
        const int64_t t1 = whisper_full_get_segment_t1 (ctx, i);
        const char * text = whisper_full_get_segment_text (ctx, i);
        mxSetFieldByNumber (mx, i, 0, mxCreateString (text));
        mxSetFieldByNumber (mx, i, 1, mxCreateDoubleScalar (t0));
        mxSetFieldByNumber (mx, i, 2, mxCreateDoubleScalar (t1));
    }
    return mx;
}

static void new_segment_callback (struct whisper_context *ctx, int n_new, void *user_data) {
   //mexPrintf("new_segment_callback\n");
   mxArray *mi[2];
   mi[0] = ((mxArray**)user_data)[0];
   mi[1] = get_tokens (ctx, n_new);
   int sts = mexCallMATLAB (0, NULL, 2, mi, "feval");
   if (sts != 0) {
       mexErrMsgIdAndTxt ("whisper:new_segment", "New_segment callback failed");
   }
}

static bool encoder_begin_callback (struct whisper_context *ctx, void *user_data) {
    //mexPrintf("encoder_begin_callback\n");
    bool is_aborted = false;
    mxArray *mi[2];
    mxArray *mo[1];
    mi[0] = ((mxArray**)user_data)[0];
    mi[1] = get_tokens (ctx, -1); // perhaps only the last N ones?
    int sts = mexCallMATLAB (1, mo, 2, mi, "feval");
    if (sts != 0) {
        mexErrMsgIdAndTxt ("whisper:encoder_begin", "Encoder_begin callback failed");
    }
    is_aborted = mxIsLogicalScalarTrue (mo[0]);
    return !is_aborted;
}

static void mex_whisper_init (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    char *path_model;
    uint64_t *c;
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");
        
    if (!mxIsChar (prhs[0])) mexErrMsgIdAndTxt ("whisper:model", "Path of model must be a string.");
    path_model = mxArrayToString (prhs[0]);
    
    ctx = whisper_init (path_model);
    if (ctx == NULL) {
        mexErrMsgIdAndTxt ("whisper:model", "Failed to load model.");
    }
    
    plhs[0] = mxCreateNumericMatrix (1, 1, mxUINT64_CLASS, mxREAL);
    c = (uint64_t*)mxGetData (plhs[0]);
    c[0] = (uint64_t)ctx;
}

static void mex_whisper_run (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    int i;
    int n_processors = 1;
    
    if (nrhs < 2) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 3) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    ctx = get_whisper_context (prhs[0]);
    
    if (!mxIsSingle (prhs[1])) {
        mexErrMsgIdAndTxt("whisper:sound", "Input has to be single-precision, floating-point numbers");
    }
    const size_t n = mxGetNumberOfElements(prhs[1]);
    float *pcmf32 = (float*)mxGetData(prhs[1]);
    
    if (nrhs > 2) {
        if (!mxIsStruct (prhs[2]) || !mxIsScalar (prhs[2])) {
            mexErrMsgIdAndTxt("whisper:params", "Parameters have to be provided as a struct");
        }
        int nf = mxGetNumberOfFields (prhs[2]);
        for (i=0; i < nf; ++i) {
            const char *fieldname = mxGetFieldNameByNumber(prhs[2], i);
            mxArray *mx = mxGetFieldByNumber(prhs[2], 0, i);
            if (!strcmp (fieldname, "n_threads")) {
                wparams.n_threads = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "n_max_text_ctx")) {
                wparams.n_max_text_ctx = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "offset_ms")) {
                wparams.offset_ms = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "duration_ms")) {
                wparams.duration_ms = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "translate")) {
                wparams.translate = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "no_context")) {
                wparams.no_context = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "single_segment")) {
                wparams.single_segment = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "print_special")) {
                wparams.print_special = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "print_progress")) {
                wparams.print_progress = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "print_realtime")) {
                wparams.print_realtime = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "print_timestamps")) {
                wparams.print_timestamps = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "token_timestamps")) {
                wparams.token_timestamps = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "thold_pt")) {
                wparams.thold_pt = (float)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "thold_ptsum")) {
                wparams.thold_ptsum = (float)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "max_len")) {
                wparams.max_len = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "max_tokens")) {
                wparams.max_tokens = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "speed_up")) {
                wparams.speed_up = mxIsLogicalScalarTrue (mx);
            }
            else if (!strcmp (fieldname, "audio_ctx")) {
                wparams.audio_ctx = (int)mxGetScalar (mx);
            }
            else if (!strcmp (fieldname, "prompt_tokens")) {
                if (wparams.prompt_n_tokens != 0) {
                    mxFree ((void *)wparams.prompt_tokens);
                }
                whisper_token *id = (whisper_token *)mxGetData (mx);
                whisper_token *prompt_tokens = (whisper_token *)mxMalloc (wparams.prompt_n_tokens * sizeof (whisper_token));
                for (int j = 0; j < wparams.prompt_n_tokens; ++j) {
                    prompt_tokens[j] = id[j];
                }
                wparams.prompt_tokens = prompt_tokens;
                wparams.prompt_n_tokens = (int)mxGetNumberOfElements (mx);
            }
            else if (!strcmp (fieldname, "language")) {
                wparams.language = mxArrayToString (mx);
                if (whisper_lang_id (wparams.language) == -1) {
                    mexErrMsgIdAndTxt ("whisper:params", "Unknown language");
                }
            }
            else if (!strcmp (fieldname, "new_segment_callback")) {
                wparams.new_segment_callback = new_segment_callback;
                wparams.new_segment_callback_user_data = &mx;
            }
            else if (!strcmp (fieldname, "encoder_begin_callback")) {
                wparams.encoder_begin_callback = encoder_begin_callback;
                wparams.encoder_begin_callback_user_data = &mx;
            }
            else if (!strcmp (fieldname, "n_processors")) {
                n_processors = (int)mxGetScalar (mx);
            }
            else {
                mexErrMsgIdAndTxt ("whisper:params", "Unknown parameter");
            }
        }
    }
    
    if (!whisper_is_multilingual (ctx)) {
        if (strcmp (wparams.language, "en") != 0 || wparams.translate) {
            wparams.language = "en";
            wparams.translate = false;
            mexWarnMsgIdAndTxt ("whisper:multilingual","Model is not multilingual, ignoring language and translation options.", __func__);
        }
    }
    
    if (whisper_full_parallel (ctx, wparams, pcmf32, n, n_processors) != 0) {
        mexErrMsgIdAndTxt ("whisper:run", "Failed to process audio");
    }
    
    plhs[0] = get_segments (ctx, -1);
    plhs[1] = get_tokens (ctx, -1);
}

static void mex_whisper_free (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    ctx = get_whisper_context (prhs[0]);

    whisper_free (ctx);
}

static void mex_whisper_lang_id (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    plhs[0] = mxCreateDoubleScalar ((double)whisper_lang_id (mxArrayToString (prhs[0])));
}

static void mex_whisper_n_len (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    ctx = get_whisper_context (prhs[0]);
    
    plhs[0] = mxCreateDoubleScalar ((double)whisper_n_len (ctx));
}

static void mex_whisper_n_vocab (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    ctx = get_whisper_context (prhs[0]);
    
    plhs[0] = mxCreateDoubleScalar ((double)whisper_n_vocab (ctx));
}

static void mex_whisper_n_text_ctx (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    ctx = get_whisper_context (prhs[0]);
    
    plhs[0] = mxCreateDoubleScalar ((double)whisper_n_text_ctx (ctx));
}

static void mex_whisper_is_multilingual (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    struct whisper_context *ctx;
    
    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (nrhs > 1) mexErrMsgIdAndTxt ("whisper:maxrhs", "Too many input arguments.");

    ctx = get_whisper_context (prhs[0]);
    
    plhs[0] = mxCreateDoubleScalar ((double)whisper_is_multilingual (ctx));
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    char *action = NULL;

    if (nrhs < 1) mexErrMsgIdAndTxt ("whisper:minrhs", "Not enough input arguments.");
    if (!mxIsChar (prhs[0])) mexErrMsgIdAndTxt ("whisper:action", "First argument must be an action string.");

    action = mxArrayToString (prhs[0]);

    if (!strcmp (action, "init")) {
        mex_whisper_init (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "run")) {
        mex_whisper_run (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "free")) {
        mex_whisper_free (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "lang_id")) {
        mex_whisper_lang_id (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "n_len")) {
        mex_whisper_n_len (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "n_vocab")) {
        mex_whisper_n_vocab (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "n_text_ctx")) {
        mex_whisper_n_text_ctx (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else if (!strcmp (action, "is_multilingual")) {
        mex_whisper_is_multilingual (nlhs, plhs, nrhs-1, &prhs[1]);
    }
    else {
        mexErrMsgTxt ("Unknown action.");
    }

    mxFree (action);
}
