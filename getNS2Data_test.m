function dat = getNS2Data_test(dat,fn2all,varargin)
p = inputParser;
p.addOptional('nsEpoch',[0 0],@isnumeric);
p.addOptional('getLFP',false,@islogical);
p.addOptional('getJoystick',false,@islogical);
p.addOptional('fnStartTimes', 0, @isnumeric);
p.addOptional('allowpause', false, @islogical);
p.parse(varargin{:});
nsEpoch = p.Results.nsEpoch;
getLFP = p.Results.getLFP;
getJoystick = p.Results.getJoystick;
fnStartTimes = p.Results.fnStartTimes;
allowpause = p.Results.allowpause;

LFP_CHAN = [];
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
fprintf('Found %d channels of NS2 data.\n',hdr2.hdr.nChans);
tind = 1;
switchFiles = false;
appendDat = false;
extractNsxData = true;

while tind <= length(dat)
    epochStartTime = dat(tind).time(1) - nsEpoch(1) - datTimeShift;
    epochEndTime = dat(tind).time(2) + nsEpoch(2) - datTimeShift;
    nsEndTime = hdr2.hdr.nSamples / hdr2.hdr.Fs;

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
        chans = str2double(hdr2.hdr.label);
        
        if ns2readflag
            lfp.data = fn2.data(:,round(epochStartTime*ns2Samp):round(epochEndTime*ns2Samp));
        else
            lfp = read_nsx(fn2,'begsample',round(epochStartTime*ns2Samp),'endsample',round(epochEndTime*ns2Samp),'allowpause', allowpause);
        end

        % LFP data
        lfpdata.codesamples = [codes codesamples];
        lfpdata.trial = lfp.data;
        lfpdata.startsample = codesamples(1);
        lfpdata.dataFs = ns2Samp;
        lfpdata.chan = chans;

        % joystick data
        if getJoystick
            joyChan = chans(ismember(chans,JOYSTICK_CHAN));
            joydata.chan = joyChan;
            joydata.trial = lfp.data(ismember(chans,JOYSTICK_CHAN),:);
            joydata.dataFs = ns2Samp;
            joydata.startsample = codesamples(1);
            joydata.codesamples = [codes codesamples];
        end

        if ~appendDat
            if getLFP
                dat(tind).lfp = lfpdata;
            end
            if getJoystick
                dat(tind).joystick = joydata;
            end
            dat(tind).nsTime = (0:1:size(lfpdata.trial,2)-1)./ns2Samp - nsEpoch(1);
        else
            % the trial at a file switch needs its data appended
            if getLFP
                dat(tind).lfp.trial = [dat(tind).lfp.trial lfpdata.trial];
            end
            if getJoystick
                dat(tind).joystick.trial = [dat(tind).joystick.trial joydata.trial];
            end
            dat(tind).nsTime = [dat(tind).nsTime (dat(tind).nsTime(end) + (1:1:length(lfpdata.trial))./ns2Samp - nsEpoch(1))];
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