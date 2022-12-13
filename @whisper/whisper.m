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
                opts = struct;
            end
            if ~isnumeric(wav)
                [wav,Fs] = audioread(wav);
                if Fs ~= 16000
                    error('Sampling rate has to be 16kHz.');
                end
            end
            [segments,tokens] = whisper_mex('run',this.Context,single(wav),opts);
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
            if nargin < 1, model = 'tiny.en'; end
            if nargin < 2, sound = 'jfk'; end
            if nargin < 3
                opts  = struct;
            else
                opts = varargin{1}; % varargin->struct
            end
            sound     = get_sound(sound);
            hW        = whisper(model);
            [seg,tok] = hW.run(sound,opts);
            whisper.display_tokens(tok)
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
                        if isempty(tokens(i).text), continue; end
                        col = max(1,round(tokens(i).p.^3 * numel(cols)));
                        fprintf('%s%s\033[0m',cols{col},tokens(i).text);
                    end
                end
            end
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
    if isnumeric(sound), return; end
    pth   = fileparts(fullfile(mfilename('fullpath')));
    pth   = fullfile(pth,'..','sounds');
    if ismember(sound,{'jfk'})
        sound = fullfile(pth,'..','whisper.cpp','samples',sound);
    else
        sound = fullfile(pth,sound);
    end
    if ~exist(sound,'file')
        sound = [sound '.wav'];
        if ~exist(sound,'file')
            error('Sound file cannot be found.');
        end
    end
end
