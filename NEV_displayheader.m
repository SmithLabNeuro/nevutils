function hdr = NEV_displayheader(nevfile,varargin)
%
% NEV_displayheader prints out the header information from the NEV file
%
p = inputParser;
p.addOptional('verbose',true,@islogical);
p.parse(varargin{:});
VERBOSE = p.Results.verbose;

hdr = struct();

%Header Basic Information
fid = fopen(nevfile,'r','l');
hdr.identifier = fscanf(fid,'%8s',1); %File Type Indentifier = 'NEURALEV'
if VERBOSE, display(['File Type Identifier: ',hdr.identifier]); end
hdr.fileSpec = fread(fid,2,'uchar'); %File specification major and minor 
hdr.version = sprintf('%d.%d',hdr.fileSpec(1),hdr.fileSpec(2)); %revision number
if VERBOSE, display(['Version: ',hdr.version]); end
hdr.fileFormat = fread(fid,2,'uchar'); %File format additional flags
if VERBOSE, display(['File Format: ',num2str(hdr.fileFormat(1)),' ',num2str(hdr.fileFormat(2))]); end
hdr.headerSize = fread(fid,1,'uint32'); 
if VERBOSE, display(['Header Size: ',num2str(hdr.headerSize)]); end
%Number of bytes in header (standard  and extended)--index for data
hdr.dataPacketSize = fread(fid,1,'uint32'); 
if VERBOSE, display(['Data Packet Size: ',num2str(hdr.dataPacketSize)]); end
%Number of bytes per data packet (-8bytes for samples per waveform)
hdr.samplesPerWaveform = (hdr.dataPacketSize-8)/2;
if VERBOSE, display(['Samples Per Waveform: ',num2str(hdr.samplesPerWaveform)]); end
hdr.stampFreq = fread(fid,1,'uint32'); %Frequency of the global clock
if VERBOSE, display(['Clock Frequency: ',num2str(hdr.stampFreq)]); end
hdr.sampleFreq = fread(fid,1,'uint32'); %Sampling Frequency
if VERBOSE, display(['Sampling Frequency: ',num2str(hdr.sampleFreq)]); end

%Windows SYSTEMTIME
hdr.time = fread(fid,8,'uint16');
hdr.year = hdr.time(1);
hdr.month = hdr.time(2);
hdr.dayweek = hdr.time(3);
if hdr.dayweek == 0 
    hdr.dw = 'Sunday';
elseif hdr.dayweek == 1 
    hdr.dw = 'Monday';
elseif hdr.dayweek == 2 
    hdr.dw = 'Tuesday';
elseif hdr.dayweek == 3 
    hdr.dw = 'Wednesday';
elseif hdr.dayweek == 4 
    hdr.dw = 'Thursday';
elseif hdr.dayweek == 5 
    hdr.dw = 'Friday';
elseif hdr.dayweek == 6 
    hdr.dw = 'Saturday';
end
hdr.day = hdr.time(4);
hdr.date = sprintf('%s, %d/%d/%d',hdr.dw,hdr.month,hdr.day,hdr.year);
if VERBOSE, disp(hdr.date); end
hdr.hour = hdr.time(5);
hdr.minute = hdr.time(6);
hdr.second = hdr.time(7);
hdr.millisec = hdr.time(8);
hdr.time2 = sprintf('%d:%d:%d.%d',hdr.hour,hdr.minute,hdr.second,hdr.millisec);
if VERBOSE, disp(hdr.time2); end

%Data Acquisition System and Version
hdr.application = char(fread(fid,32,'uchar')');
if VERBOSE, display(['Data Acquisition System and Version: ',hdr.application]); end

%Additional Information (and Extended Header Information)
if ~isempty(strfind(hdr.application,'Trellis'))
    hdr.comments = char(fread(fid,252,'uchar')');
    hdr.nevclockstart = fread(fid,1,'uint32');
    if VERBOSE
        display(['Comments: ',hdr.comments]);
        display(['NEV Start Clock Time: ',num2str(hdr.nevclockstart)]);
    end
else
    hdr.comments = char(fread(fid,256,'uchar')');
    if VERBOSE, display(['Comments: ',hdr.comments]); end
end

hdr.nExtHeaders = fread(fid,1,'uint32');
if VERBOSE, display(['Number of Extended Headers: ',num2str(hdr.nExtHeaders)]); end

hdr.ExtHeader = struct();
% Read the Extended Headers
for I=1:hdr.nExtHeaders
    hdr.ExtHeader(I).Identifier=char(fread(fid,8,'char'))';
    %modify this later
    switch hdr.ExtHeader(I).Identifier
        case 'NEUEVWAV'
            hdr.ExtHeader(I).ElecID=fread(fid,1,'uint16');
            hdr.ExtHeader(I).PhysConnect=fread(fid,1,'uchar');
            hdr.ExtHeader(I).PhysConnectPin=fread(fid,1,'uchar');
            hdr.ExtHeader(I).nVperBit=fread(fid,1,'uint16');
            hdr.ExtHeader(I).EnergyThresh=fread(fid,1,'uint16');
            hdr.ExtHeader(I).HighThresh=fread(fid,1,'int16');
            hdr.ExtHeader(I).LowThresh=fread(fid,1,'int16');
            hdr.ExtHeader(I).SortedUnits=fread(fid,1,'uchar');
            hdr.ExtHeader(I).BytesPerSample=((fread(fid,1,'uchar'))>1)+1;
            temp=fread(fid,10,'uchar');
        otherwise, % added26/7/05 after identifying bug in reading extended headers
            temp=fread(fid,24,'uchar');
    end
end

%Determine number of packets in file after the header
fseek(fid,0,'eof');
hdr.nBytesInFile = ftell(fid);
hdr.nPacketsInFile = (hdr.nBytesInFile-hdr.headerSize)/hdr.dataPacketSize;

fclose(fid);
