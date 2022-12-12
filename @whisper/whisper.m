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
        function [segments,tokens] = run(this,wav,opts)
            if nargin < 3
                opts = {};
            else
                opts = { opts };
            end
            if ~isnumeric(wav)
                [wav,Fs] = audioread(wav);
                if Fs ~= 16000
                    error('Sampling rate has to be 16kHz.');
                end
            end
            [segments,tokens] = whisper_mex('run',this.Context,single(wav),opts{:});
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
        function demo
            wav  = get_sound('FEP-Friston.wav');
            h    = whisper('tiny.en');
            [seg,tok] = h.run(wav);
            display_tokens(tok)
            delete(h);
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
    pth   = fileparts(fullfile(mfilename('fullpath')));
    pth   = fullfile(pth,'..','sounds');
    sound = fullfile(pth,sound);
end

function display_tokens(tokens,use_colour)
    if nargin < 2, use_colour = true; end
    cols = arrayfun(@(x)sprintf('\033[38;5;%dm',x),...
        [196,202,208,214,220,226,190,154,118,82],'UniformOutput',false);
    if iscell(tokens)
        disp([tokens{:}]);
    else
        if ~use_colour
            disp([tokens.text]);
        else
            for i=1:numel(tokens)
                col = max(1,round(tokens(i).p^3 * numel(cols)));
                fprintf('%s%s\033[0m',cols{col},tokens(i).text);
            end
        end
    end
end
