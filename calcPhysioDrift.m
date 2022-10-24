function [physioDrift, t_runavg] = calcPhysioDrift(physioDat, fs, varargin)
% calcPhysioDrift extracts the rate of a physiologic oscillation (ex. cardiac pulses in NIRS,
% respiration in thermal sesnor signal) and creates a binned rate trace over the session that 
% can be compared to slow drift.
%   - physioDat: 1D physiologic data trace
%   - fs: data sampling rate
%   - physioRange: 2 element frequency range in Hz for expected rate of the
%                  physiologic signal (ex. respiration b/w 0.15 and 0.9
%                  Hz). This range will be used to filter the input signal.
%   - extractMethod: method to extract respiration/heart rate from data (spectrogram or peaks)
%   - specWin: length of spectrogram window in seconds (used in spectrogram method)
%   - specOverlap: fraction of overlap between spectrogram time bins (used in spectrogram method)
%   - penalty: penalty for changing frequency in tfridge (used to extract trace from spectrogram)
%   - runAvgFlag: if method is spectrogram and this is false, just outputs
%                 the extracted spectrogram trace without any extra binning
%   - binL: time in seconds to bin slow drift data
%   - shiftL: time in seconds to shift binL when computing slow drift

p = inputParser;
p.addOptional('physioRange', [0.15 0.9], @isnumeric);
p.addOptional('extractMethod',"spectrogram", @isstring);
p.addOptional('specWin',60, @isscalar);
p.addOptional('specOverlap',0.8, @isscalar)
p.addOptional('penalty',0.001,@isscalar);

p.addOptional('runAvgFlag', true, @islogical)
p.addOptional('binL', 30*60, @isscalar);
p.addOptional('shiftL', 6*60, @isscalar);

p.parse(varargin{:});

physioRange = p.Results.physioRange;
extractMethod = p.Results.extractMethod;
specWin = p.Results.specWin;
specOverlap = p.Results.specOverlap;
penalty = p.Results.penalty;
runAvgFlag = p.Results.runAvgFlag;
binL = p.Results.binL;
shiftL = p.Results.shiftL;

%% (1) ********* Extract rate across session ******************
windowSize = specWin*fs; %in samples
% Note: if specWin approaches the size of binL for slow drift there are
% going to be very few samples in each drift bin

[b,a]= butter(2,physioRange/(fs/2),'bandpass'); % narrowband filter the trace
datFilt = filtfilt(b,a,physioDat);

% plot for visualization
figure; spectrogram(datFilt,windowSize,round(windowSize*specOverlap),[],fs,'yaxis');
ylim([physioRange(1)/2 3*physioRange(2)/2]); hold on;

switch extractMethod
    case "spectrogram"
        % compute spectrogram of data trace and extract from trace
        [physio_trace,t] = extractSpecFreq(physioDat,fs,physioRange,windowSize,specOverlap,'penalty',penalty);

    case "peaks"
        % use findpeaks on trace
        [~,pkloc] = findpeaks(datFilt,'MinPeakDistance',fs/physioRange(2));
        t = pkloc./fs; % convert from samples to time
        physio_trace = 1./diff(t); % time difference between adjacent peaks to frequency in Hz
        t = t(1:end-1);

    otherwise
        error('undefined method for extracting rate trace');
end

% plot rate trace over spectrogram of data trace
plot(t/3600,physio_trace,'k');

%% (3) ********* Bin data across the session *****************************

if strcmp("spectrogram",extractMethod) && ~runAvgFlag
    % if spectrogram method and running average flag is false then just use the
    % trace extracted from the spectrogram as the physiological drift output
    t_runavg = t;
    physioDrift = physio_trace;

else
    % otherwise bin the rate trace in the same way as the slow drift data 
    t = t - t(1); % time bins for physiological data should be identifical to slow drfit (starting at 0)
    [ t_runavg, physioDrift, ~] = temporalRunAvg(t,physio_trace,binL,shiftL);
end

end