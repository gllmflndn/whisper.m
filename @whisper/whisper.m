% Automatic speech recognition using whisper.cpp and OpenAI's Whisper
%
% Copyright (C) 2022 Guillaume Flandin

classdef whisper < handle

    %======================================================================
    %                         P R O P E R T I E S
    %======================================================================
    properties (GetAccess = public, SetAccess = private)
        Model = '';
    end
    
    properties (Access = private, Hidden = true)
        Context = [];
    end
    
    %======================================================================
    %                     P U B L I C    M E T H O D S
    %======================================================================
    methods

        %------------------------------------------------------------------
        %-Constructor
        %------------------------------------------------------------------
        function this = whisper(model)
            if ~nargin
                model = 'base.en';
            end
            model = get_model(model);
            this.Model = model;
            this.Context = whisper_mex('init',this.Model);
        end
        
        %------------------------------------------------------------------
        %-Run forward pass
        %------------------------------------------------------------------
        function [segments,tokens] = run(this,sound,varargin)
            opts = get_options(varargin);
            sound = get_sound(sound);
            [segments,tokens] = whisper_mex('run',this.Context,sound,opts);
        end
        
        %------------------------------------------------------------------
        %-Destructor
        %------------------------------------------------------------------
        function delete(this)
            whisper_mex('free',this.Context);
            this.Context = [];
        end
    end

    %======================================================================
    %                     S T A T I C    M E T H O D S
    %======================================================================
    methods (Static)

        function demo(model,sound,varargin)
            if nargin < 1 || isempty(model), model = 'tiny.en'; end
            if nargin < 2 || isempty(sound), sound = 'jfk'; end
            sound     = get_sound(sound);
            hW        = whisper(model);
            [seg,tok] = hW.run(sound,varargin{:});
            whisper.display_tokens(tok)
        end

        function display_tokens(tokens,use_colour,disp_timestamps)
            if nargin < 2, use_colour = true; end
            if nargin < 3, disp_timestamps = false; end
            try, isdesk = usejava('desktop'); catch, isdesk = false; end
            if isdesk, use_colour = false; end
            if ~isfield(tokens,'p'), use_colour = false; end

            cols = arrayfun(@(x)sprintf('\033[38;5;%dm',x),...
                [196,202,208,214,220,226,190,154,118,82],'UniformOutput',false);
            if ~use_colour
                if ~disp_timestamps
                    disp([tokens.text]);
                else
                    for i=1:numel(tokens)
                        fprintf('%s',tokens(i).text);
                    end
                end
            else
                for i=1:numel(tokens)
                    if isempty(tokens(i).text), continue; end
                    col = max(1,round(tokens(i).p.^3 * numel(cols)));
                    fprintf('%s%s\033[0m',cols{col},tokens(i).text);
                end
            end
            fprintf('\n');
        end

        function save(filename,tokens)
            [pth,nam,ext] = fileparts(filename);
            if ~ismember(ext,{'.vtt','.srt'})
                error('Unknown format.');
            end
            fid = fopen(filename,'wt','native','UTF-8');
            switch lower(ext)
                case '.vtt'
                    save_vtt(fid,tokens);
                case '.srt'
                    save_srt(fid,tokens);
                otherwise
                    fclose(fid);
                    error('Unknown format.');
            end
            fclose(fid);
        end

        function download(varargin)
            if strcmp(varargin,{'all'})
                varargin = {...
                    'tiny.en',   'tiny',...
                    'base.en',   'base',...
                    'small.en',  'small',...
                    'medium.en', 'medium',...
                    'large-v1',  'large'};
            end
            for i=1:numel(varargin)
                try
                    get_model(varargin{i});
                catch
                    warning('Download of model "%s" failed.',varargin{i});
                end
            end
        end

        function Y = speak(text,lang)
            % eSpeak NG: https://github.com/espeak-ng/espeak-ng/
            if isnumeric(text), sound(text,16000); return; end
            if nargin < 2 || isempty(lang), lang = 'en'; end
            if nargout, wav = ['-w ' tempname '.wav']; else wav = ''; end
            cmd = 'espeak'; % or 'espeak-ng'
            if isstruct(text)
                text = [text.text];
            end
            text = strrep(text,'"','\"');
            sts = system(sprintf('%s -v %s %s "%s"',cmd,lang,wav,text));
            if sts
                % Use Web Speeh API instead
                web_speech(text);
            end
            if nargout
                Y = get_sound(wav(4:end));
                delete(wav(4:end));
            end
        end

        function web_speech(text)
            % Web Speech API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API
            % e.g. https://github.com/mdn/dom-examples/tree/main/web-speech-api/speak-easy-synthesis
            pth  = fileparts(fullfile(mfilename('fullpath')));
            html = fullfile(pth,'..','extra','index.html');
            html = fileread(html);
            if isstruct(text), text = [text.text]; end
            html = strrep(html,'{WHISPER}',text);
            tmp  = [tempname '.html'];
            fid  = fopen(tmp,'wt');
            fprintf(fid,'%s',html);
            fclose(fid);
            web(tmp,'-browser');
        end

    end

end

%==========================================================================
%                       H E L P E R    F U N C T I O N S
%==========================================================================
function model = get_model(model)
    if ismember(model,{'tiny.en','tiny','base.en','base','small.en','small','medium.en','medium','large-v1','large'})
        pth  = fileparts(fullfile(mfilename('fullpath')));
        pth  = fullfile(pth,'..','models');
        name = sprintf('ggml-%s.bin',model);
        filename = fullfile(pth,name);
        if ~exist(filename,'file')
            if ~exist(pth,'dir')
                mkdir(pth);
            end
            url  = 'https://huggingface.co/datasets/ggerganov/whisper.cpp/resolve/main/';
            fprintf('Download %s...',model);
            websave(filename,[url name]);
            fprintf('done\n');
        end
        model = filename;
    end
    if ~exist(model,'file')
        error('Pre-trained model cannot be found.');
    end
end

function sound = get_sound(sound)
    if ~isnumeric(sound)
        pth = fileparts(fullfile(mfilename('fullpath')));
        pth = fullfile(pth,'..','samples');
        if ismember(sound,{'jfk'})
            pth = fullfile(pth,'..','whisper.cpp','samples');
        end
        [p,n,e] = fileparts(sound);
        if isempty(p) && isempty(e), p = pth; end
        if isempty(e), e = '.wav'; end
        sound = fullfile(p,[n e]);
        if ~exist(sound,'file')
            error('Sound file cannot be found.');
        end
        [sound,Fs] = audioread(sound);
        if Fs ~= 16000
            warning('Sampling rate has to be 16kHz. Resampling.');
            sound = resample(sound(:)', 16000/Fs);
        end
    end
    sound = single(sound);
end

function opts = get_options(options)
    opts = struct;
    if numel(options) == 1 && isstruct(options)
        opts = options;
    elseif mod(numel(options),2) == 0 && iscell(options)
        for i=1:2:numel(options)
            opts.(options{i}) = options{i+1};
        end
    else
        error('Invalid options');
    end
end

function str = t2str(t,sep)
    if nargin < 2, sep = '.'; end
    ms = 10 * t;
    hr = floor(ms / (1000 * 60 * 60));
    ms = ms - hr * (1000 * 60 * 60);
    mn = floor(ms / (1000 * 60));
    ms = ms - mn * (1000 * 60);
    s  = floor(ms / 1000);
    ms = ms - s * 1000;
    str = sprintf('%02d:%02d:%02d%c%03d',hr,mn,s,sep,ms);
end

function save_vtt(fid,tok)
% WebVTT (Web Video Text Tracks): https://en.wikipedia.org/wiki/WebVTT
    fprintf(fid,'WEBVTT\n\n');
    for i=1:numel(tok)
        if isempty(tok(i).text), continue; end
        fprintf(fid,'%s --> %s\n%s\n\n',...
            t2str(tok(i).t0), t2str(tok(i).t1), strtrim(tok(i).text));
    end
end

function save_srt(fid,tok)
% SubRip Text: https://en.wikipedia.org/wiki/SubRip
    for i=1:numel(tok)
        if isempty(tok(i).text), continue; end
        fprintf(fid,'%d\n%s --> %s\n%s\n\n',...
            i, t2str(tok(i).t0,','), t2str(tok(i).t1,','), strtrim(tok(i).text));
    end
end

function d = edit_distance(s,t)
% Levenshtein distance: https://en.wikipedia.org/wiki/Levenshtein_distance
% Cleve Moler: https://blogs.mathworks.com/cleve/2017/08/14/levenshtein-edit-distance-between-strings/
    m = length(s);
    n = length(t);
    x = 0:n;
    y = zeros(1,n+1);
    for i = 1:m
        y(1) = i;
        for j = 1:n
            c = (s(i) ~= t(j)); % c = 0 if chars match, 1 if not.
            y(j+1) = min([y(j) + 1, x(j+1) + 1, x(j) + c]);
        end
        % swap
        [x,y] = deal(y,x);
    end
    d = x(n+1);
end

function Y = resample(X,alpha)
% Resample data to a new rate: https://www.mathworks.com/help/signal/ref/resample.html
% Jean Daunizeau: https://github.com/spm/spm
    N0     = size(X,2);
    N      = floor(N0*alpha);
    alpha  = N/N0;
    Y      = fftshift(fft(X,[],2),2);
    sy     = size(Y,2);
    middle = floor(sy./2)+1;
    if alpha > 1
        N2 = floor((N-N0)./2);
        if N0/2 == floor(N0/2)
            Y(:,1) = [];
        end
        Y  = [zeros(size(Y,1),N2),Y,zeros(size(Y,1),N2)];
    else
        N2 = floor(N./2);
        Y  = Y(:,middle-N2:middle+N2);
    end
    Y      = alpha*ifft(ifftshift(Y,2),[],2);
end
