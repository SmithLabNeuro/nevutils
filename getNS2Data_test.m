function dat = getNS2Data_test(dat,fn2all,varargin)
p = inputParser;
p.addOptional('nsEpoch',[0 0],@isnumeric);
p.addOptional('getLFP',false,@islogical);
p.addOptional('getJoystick',false,@islogical);
p.addOptional('dsJoystick',10,@isnumeric);
p.addOptional('fnStartTimes', 0, @isnumeric);
p.addOptional('allowpause', false, @islogical);
p.parse(varargin{:});
nsEpoch = p.Results.nsEpoch;
getLFP = p.Results.getLFP;
getJoystick = p.Results.getJoystick;
downsamplejoystick = p.Results.dsJoystick;
fnStartTimes = p.Results.fnStartTimes;
allowpause = p.Results.allowpause;

LFP_CHAN = []; % assigned later
JOYSTICK_CHAN = [10250, 10251]; % x,y

if ~iscell(fn2all)
    fn2all = {fn2all};
end

% start with first file
fnInd = 1;
fn2 = fn2all{fnInd};
datTimeShift = fnStartTimes(fnInd);

if ischar(fn2)
    ns2readflag = false;
    hdr2 = read_nsx(fn2,'readdata',false);
else
    ns2readflag = true;
    hdr2.hdr = fn2.hdr;
end

ns2Samp = double(hdr2.hdr.Fs);
ns2Chans = str2double(hdr2.hdr.label);
fprintf('Found %d channels of NS2 data.\n',hdr2.hdr.nChans);
tind = 1;
switchFiles = false;
appendDat = false;
extractNsxData = true;

while tind <= length(dat)
    epochStartTime = dat(tind).time(1) - nsEpoch(1) - datTimeShift;
    epochEndTime = dat(tind).time(2) + nsEpoch(2) - datTimeShift;
    nsEndTime = hdr2.hdr.nSamples / hdr2.hdr.Fs;
    LFP_CHAN = dat(tind).channels; % which channels to grab from NEV

    if epochEndTime > nsEndTime && epochStartTime < nsEndTime
        % this takes care of the file switch happening *within* a trial
        epochEndTime = nsEndTime;
        switchFiles = true;
        extractNsxData = true;
    elseif epochEndTime > nsEndTime && epochStartTime > nsEndTime
        % this handles the file switch happening *between* trials
        switchFiles = true;
        extractNsxData = false;
    else
        extractNsxData = true;
    end

    if extractNsxData
        if epochStartTime < 0
            epochStartTime = 0;
        end
        if epochEndTime > nsEndTime
            epochEndTime = nsEndTime;
        end
        msec = dat(tind).trialcodes(:,3);
        codes = dat(tind).trialcodes(:,2);
        codesamples = round(msec*ns2Samp);

        % LFP data
        if getLFP
            lfpChanIdx = find(ismember(ns2Chans,LFP_CHAN));
            if ns2readflag
                lfp.data = fn2.data(:,round(epochStartTime*ns2Samp):round(epochEndTime*ns2Samp));
            else
                lfp = read_nsx(fn2,'chanindx',lfpChanIdx,'begsample',round(epochStartTime*ns2Samp),'endsample',round(epochEndTime*ns2Samp),'allowpause', allowpause);
            end
            lfpdata.codesamples = [codes codesamples];
            lfpdata.trial = lfp.data;
            lfpdata.startsample = codesamples(1);
            lfpdata.dataFs = ns2Samp;
            lfpdata.chan = LFP_CHAN;
        end

        % joystick data
        if getJoystick
            joystickChanIdx = find(ismember(ns2Chans,JOYSTICK_CHAN));
            if ns2readflag
                % channels may be off
                joystick.data = fn2.data(:,round(epochStartTime*ns2Samp):round(epochEndTime*ns2Samp));
            else
                joystick = read_nsx(fn2,'chanindx',joystickChanIdx,'begsample',round(epochStartTime*ns2Samp),'endsample',round(epochEndTime*ns2Samp),'allowpause', allowpause);
            end
            dsJoydata = downsample(joystick.data',downsamplejoystick)'; % downsample to frame rate of screen (factor of 10)
            joydata.chan = JOYSTICK_CHAN;
            joydata.trial = dsJoydata;
            joydata.dataFs = ns2Samp/downsamplejoystick;
            joydata.startsample = floor(codesamples(1)/downsamplejoystick);
            joydata.codesamples = [codes codesamples];
	    joydata.codesamples(:,2) = floor(joydata.codesamples(:,2)/downsamplejoystick);
        end
        
        ns2NumSamples = round(epochEndTime*ns2Samp) - round(epochStartTime*ns2Samp);
        if ~appendDat
            if getLFP
                dat(tind).lfp = lfpdata;
            end
            if getJoystick
                dat(tind).joystick = joydata;
            end
            dat(tind).nsTime = (0:1:ns2NumSamples-1)./ns2Samp - nsEpoch(1);
        else
            % the trial at a file switch needs its data appended
            if getLFP
                dat(tind).lfp.trial = [dat(tind).lfp.trial lfpdata.trial];
            end
            if getJoystick
                dat(tind).joystick.trial = [dat(tind).joystick.trial joydata.trial];
            end
            dat(tind).nsTime = [dat(tind).nsTime (dat(tind).nsTime(end) + (1:1:ns2NumSamples)./ns2Samp - nsEpoch(1))];
            appendDat = false;
        end
    end

    if switchFiles
        fnInd = fnInd + 1;
        fn2 = fn2all{fnInd};
        datTimeShift = fnStartTimes(fnInd);
        epochStartTime = epochStartTime - datTimeShift;
        epochEndTime = epochEndTime - datTimeShift;
        if ischar(fn2)
            ns2readflag = false;
            hdr2 = read_nsx(fn2,'readdata',false);
        else
            ns2readflag = true;
            hdr2.hdr = fn2.hdr;
        end
        ns2Samp = double(hdr2.hdr.Fs);
        ns2Chans = str2double(hdr2.hdr.label);
        fprintf('Found %d channels of NS2 data.\n',hdr2.hdr.nChans);
        switchFiles = false;
        if extractNsxData
            appendDat = true;
        end
        disp('first epoch start')
        disp(dat(tind).time(1) - nsEpoch(1) - datTimeShift)
        disp('first epoch end')
        disp(dat(tind).time(2) - nsEpoch(2) - datTimeShift)
    else
        tind = tind+1;
    end

end
end