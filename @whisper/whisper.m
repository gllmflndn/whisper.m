classdef whisper < handle

    %======================================================================
    %                         P R O P E R T I E S
    %======================================================================
    properties (GetAccess = public, SetAccess = private)
        Model = '';
    end
    
    properties (Access = private, Hidden = true)
        ctx = [];
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
                pth  = fileparts(fullfile(mfilename('fullpath')));
                model = fullfile(pth,'..','whisper.cpp','models/ggml-base.en.bin');
            end
            this.Model = model;
            this.ctx = whisper_mex('init',this.Model);
        end
        
        %------------------------------------------------------------------
        %-Inference
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
            [segments,tokens] = whisper_mex('run',this.ctx,single(wav),opts{:});
        end
        
        %------------------------------------------------------------------
        %-Destructor
        %------------------------------------------------------------------
        function delete(this)
            whisper_mex('free',this.ctx);
            this.ctx = [];
        end
    end

    %======================================================================
    %                     S T A T I C    M E T H O D S
    %======================================================================
    methods (Static)
        function demo
            pth  = fileparts(fullfile(mfilename('fullpath')));
            pth  = fullfile(pth,'..');
            wav  = fullfile(pth,'sounds','FEP-Friston.wav');
            h    = whisper;
            text = h.run(wav,struct('new_segment_callback',@()disp('hello')));
            disp([text{:}]);
            delete(h);
        end
    end

end
