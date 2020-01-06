classdef edf2mat < handle
% EDF2MAT is a converter to convert Eyetracker data files to MATLAB file and perform some tasks on the data
%
% Syntax: edf2mat(filename, [verbose]);
%
% Inputs:
%   filename:           must be of type *.edf
%   verbose:            logical, can be true or false, default is true.
%                       If you want to suppress output to console,
%                       verbose has to be false
%
% Outputs:
%	  The edf2mat Object
%
% Event structure from SR-Research:
%     float  px[2], py[2];    /* pupil xy */
% 	  float  hx[2], hy[2];    /* headref xy */
% 	  float  pa[2]; 		      /* pupil size or area */
%
% 	  float gx[2], gy[2];     /* screen gaze xy */
%     float rx, ry;           /* screen pixels per degree */
%     UINT32 time;            /* effective time of event */
%     INT16 type;             /* event type */
%     UINT16 read;            /* flags which items were included */
%     INT16 eye;              /* eye: 0=left, 1=right */
%     UINT32 sttime;          /* start time of the event */
%     UINT32 entime;          /* end time of the event */
%     float hstx, hsty;       /* headref starting points */
%     float gstx, gsty;       /* gaze starting points */
%     float sta;              // Undocumented by SR-research, assumption: start area of pupil
%     float henx, heny;       /* headref ending points */
%     float genx, geny;       /* gaze ending points */
%     float ena;              // Undocumented by SR-research, assumption: end area of pupil
%     float havx, havy;       /* headref averages */
%     float gavx, gavy;       /* gaze averages */
%     float ava;              // Undocumented by sr-research, assumption: average area of pupil
%     float avel;             /* accumulated average velocity */
%     float pvel;             /* accumulated peak velocity */
%     float svel, evel;       /* start, end velocity */
%     float supd_x, eupd_x;   /* start, end units-per-degree */
%     float supd_y, eupd_y;   /* start, end units-per-degree */
%     UINT16 status;          /* error, warning flags */
%     UINT16 flags;           /* error, warning flags */
%     UINT16 input;
%     UINT16 buttons;
%     UINT16 parsedby;        /* 7 bits of flags: PARSEDBY codes */
%     LSTRING *message;       /* any message string */

  properties(Constant, Hidden)
    HEADERSTART = 316; % start header position in the converted ASC file
  end

  properties(Constant)
    VERSION = 1.00;              % Number of the latest version
    VERSIONDATE = '2019/Dec/20'; % Date of the latest version
    
    EVENT_TYPES = struct(...
      'STARTPARSE',      1,  ... % /* these only have time and eye data */
      'ENDPARSE',        2,  ...
      'BREAKPARSE',      10, ...
      ...
      ... % 			/* EYE DATA: contents determined by evt_data */
      'STARTBLINK',      3,  ...    % /* and by "read" data item */
      'ENDBLINK',        4,  ...    % /* all use IEVENT format */
      'STARTSACC',       5,  ...
      'ENDSACC',         6,  ...
      'STARTFIX',        7,  ...
      'ENDFIX',          8,  ...
      'FIXUPDATE',       9,  ...
      ... %
      ... %   /* buffer = (none, directly affects state), btype = CONTROL_BUFFER */
      ... %
      ... % 			 /* control events: all put data into */
      ... % 			 /* the EDF_FILE or ILINKDATA status  */
      'STARTSAMPLES',    15, ...  % /* start of samples in block */
      'ENDSAMPLES',      16, ...  % /* end of samples in block */
      'STARTEVENTS',     17, ...  % /* start of events in block */
      'ENDEVENTS',       18, ...  % /* end of events in block */
      ... %
      ... %  	/* buffer = IMESSAGE, btype = IMESSAGE_BUFFER */
      'MESSAGEEVENT',    24, ...  % /* user-definable text or data */
      ... %
      ... % 	/* buffer = IOEVENT, btype = IOEVENT_BUFFER */
      'BUTTONEVENT',     25, ...  % /* button state change */
      'INPUTEVENT',      28, ...  % /* change of input port */
      ...
      'LOST_DATA_EVENT', hex2dec('3F'));   %/* NEW: Event flags gap in data stream */
    
    RECORDING_STATES    = struct('START', 1, 'END', 0);
    EYES                = struct('LEFT', 1, 'RIGHT', 2, 'BINOCULAR', 3);
    PUPIL               = struct('AREA', 0, 'DIAMETER', 1);
    MISSING_DATA_VALUE  = -32768;
  end

  % Here come the properties, which only can be read and written from
  % the class itself AND aren't visible from the outside
  properties(SetAccess = private, GetAccess = private)
    verbose = false;
    log;
    cases   = struct('samples', 'Samples', 'events', 'Events');
    imhandle;
  end
  
  % screen properties for user coordinate convertion (VIEWPixx/3D screen, 120Hz)
  properties(Constant, Hidden)
    % [screenWidthPixel, screenHeightPixel] = Screen('WindowSize', displayNumber);
    screenWidthPixel  = 1920; % width  of a window or screen in units of pixels
    screenHeightPixel = 1080; % height of a window or screen in units of pixels
    % [screenWidthMM, screenHeightMM] = Screen('DisplaySize', displayNumber);
    %screenWidthMM     = 523.9680; % width  of a screen in mm
    screenWidthMM     = 521.28; % width  of a screen in mm
    %screenHeightMM    = 292.0320; % height of a screen in mm
    screenHeightMM    = 293.22; % height of a screen in mm
  end

  properties(SetAccess = private, GetAccess = public)
    % private writable variables
    
    filename; % The name of the EDF File converted
    
    % The Header of the eyeTrackerData, information about the eyeTrackerData
    Header = struct(...
      'date',          [], ...
      'type',          [], ...
      'version',       [], ...
      'source',        [], ...
      'system',        [], ...
      'camera',        [], ...
      'serial_number', [], ...
      'camera_config', []  ...
      );
    
    % The samples of the eyeTrackerData
    Samples = struct(...
      'time',      [], ...
      'posX',    [], ...
      'posY',    [], ...
      'posXMM',    [], ...
      'posYMM',    [], ...
      'pupilSize', []  ...
      );
    
    % The events of the eyeTrackerData
    Events = struct(...
      'Messages',   [], ...
      'Start',      [], ...
      'Input',      [], ...
      'Buttons',    [], ...
      'prescaler',  [], ...
      'vprescaler', [], ...
      'pupilInfo',  [], ...
      'Sfix',       [], ...
      'Efix',       [], ...
      'Ssacc',      [], ...
      'Esacc',      [], ...
      'Sblink',     [], ...
      'Eblink',     [], ...
      'End',        []  ...
      );
    
    % The control status bus parsed from matudp
    controlStatus = struct(...
      'desktopTime',     [], ...
      'dataStore',       [], ...
      'subject',         [], ...
      'protocol',        [], ...
      'protocolVersion', []  ...
      );
    
    % The converted EDF structure generated by the edfmex routine
    RawEDF = struct();
  end
  
  properties(Dependent)
    samplesFilename;    % The file name of ASCII files which stores all samples
    eventsFilename;     % The file name of ASCII files which stores all events
    
    matFilename;        % The file name of MAT file which stores all Header, Samples and Events
    
    fails;              % If preparing a folder, it stores all files, which couldn't be converted
    
    timeline;
    normalizedTimeline;
  end
  
  methods
    function obj = edf2mat(filename, verbose)
      assert(exist('filename', 'var') ...
        && ischar(filename) ...
        || isfolder(filename) ...
        && size(filename, 2) >= 4 ...
        && strcmp(filename(end - 3:end), '.edf'), ...
        'edf2mat:filename', 'filename must be given and be of type .edf!');
      
      assert(logical(exist(filename, 'file')), ...
        'edf2mat:filenotfound', ['file ' filename ' not found!']);
      
      obj.filename = filename;
      
      if exist('verbose', 'var')
        try
          obj.verbose = logical(verbose);
        catch e
          e = e.addCause(MException('edf2mat:verbose', 'bad Argument: 2rd argument has to be of type logical!'));
          rethrow(e);
        end
      end
      
      if isfolder(obj.filename)
        obj.processFolder();
      else
        obj.processFile();
      end
    end
    
    function processFolder(obj)
      % working directiory (.edf data folder)
      workFolder = obj.filename;
      
      % variables
      filenames = dir([workFolder, filesep, '*.edf']);
      allNames = {filenames.name}';
      folder = [filenames(1).folder];
      nFiles = numel(allNames);
      
      isFail = false(nFiles, 1);
      
      for currentFile = 1:nFiles
        file = [folder, filesep(), allNames{currentFile}];
        try
          edf = edf2mat(file);
          
          edf.edf_plot();
          fig = gcf();
          fig.PaperOrientation = 'landscape';
          print([workFolder, filesep(), allNames{currentFile}(1:end-4)], '-dpdf', '-fillpage');
          close(fig);
          
          isFail(currentFile) = false;
          fprintf('Convertion status: %d out of %d done\n', currentFile, nFiles);
        catch me
          isFail(currentFile) = true;
          fprintf('Convertion status: %s convertion failed\n', allNames{currentFile});
        end
      end
      
      if any(isFail == 1)
        obj.fails = allNames(isFail);
      end
      fprintf('Convertion status: FINISHED\n');
    end
    
    function processFile(obj)
      importer = @(varargin)edfmex(varargin{:});
      obj.RawEDF      = importer(obj.filename);
      obj.Header.raw  = obj.RawEDF.HEADER;
      obj.Samples     = obj.RawEDF.FSAMPLE;
      
      obj.convertSamples();
      obj.createHeader();
      obj.convertEvents();
      
      %obj.edf_plot();
      
      if obj.verbose
        disp('EDF succesfully converted, processed.!');
      end
    end
    
    function samplesFilename = get.samplesFilename(obj)
        samplesFilename = strrep(obj.filename, '.edf', ['_' lower(obj.cases.samples) '.asc']);
    end
    
    function eventsFilename = get.eventsFilename(obj)
        eventsFilename = strrep(obj.filename, '.edf', ['_' lower(obj.cases.events) '.asc']);
    end
    
    function matFilename = get.matFilename(obj)
      matFilename = strrep(obj.filename, '.edf', '.mat');
    end
    
    function timeline = get.timeline(obj)
      timeline = obj.getTimeline();
    end
    
    function timeline = get.normalizedTimeline(obj)
      timeline = obj.getNormalizedTimeline();
    end
    
    function convertSamples(obj)
      %obj.convertFile(obj.cases.samples);
      obj.processSamples();
    end
    
    function convertEvents(obj)
      %obj.convertFile(obj.cases.events);
      obj.processEvents();
    end
    
    function save(obj)
      % some how we need to make new copies to store them in a file ...
      header  = obj.Header;
      samples = obj.Samples;
      events  = obj.Events;
      raw     = obj.RawEDF;
      thisobj = obj;
      
      vname   = @(x) inputname(1);
      builtin('save', obj.matFilename, vname(header), vname(samples), vname(events), vname(raw), vname(thisobj));
    end
    
    function [timeline, offset] = getTimeline(obj)
      timeline = (obj.Events.Start.time:obj.Events.End.time).';
      offset   = timeline(1);
    end
    
    function [timeline, offset] = getNormalizedTimeline(obj)
      [timeline, offset] = obj.getTimeline();
      timeline           = timeline - offset;
    end
    
    function blinkTimeline = getBlinkTimeline(obj)
      startIndecies = arrayfun(@(x)find(obj.Samples.time == x),  ...
        obj.Events.Eblink.start).';
      endIndecies   = arrayfun(@(x)find(obj.Samples.time == x),  ...
        obj.Events.Eblink.end).';
      
      blinks  = mat2cell([startIndecies, endIndecies], ones(numel(startIndecies), 1));
      blinkTimeline = zeros(numel(obj.timeline), 1);
      blinkTimeline(cell2mat(cellfun(@(x)colon(x(1), x(2)).', ...
        blinks, 'UniformOutput', false))) = 1;
    end
    
    function messageTimeline = getMessageTimeline(obj)
      messageTimes        = unique(obj.Events.Messages.time);
      extendedTimeline    = unique([obj.timeline(:); messageTimes(:)]).';
      messageTimeline     = nan(numel(extendedTimeline), 1);
      messageTimeline(ismember(extendedTimeline, messageTimes)) = 1;
    end
  end

  methods(Access = private)
    function convertFile(obj, kind)
      if obj.verbose
        disp(['Processing ' kind '. Please wait ...']);
      end
      
      [path, ~, ~] = fileparts(which(mfilename));
      
      % -miss <value>   replaces missing (x,y) in samples with <value>
      % -y              overwrite asc file if exists
      switch computer
        case 'PCWIN64'
          command = ['"', path, '\private\edf2asc.exe" -miss NaN -y '];
        case 'MACI64'
        case 'GLNXA64'
          command = 'edf2asc -miss NaN -y ';
        otherwise
          warning('Unknown computer type. No file converted.');
          return;
      end
      
      switch kind
        case obj.cases.samples
          % -s or -ne   outputs sample data only
          command = [command, '-s '];
        case obj.cases.events
          % -e or -ns   outputs event data only
          % -t          use only tabs as delimiters
          command = [command, '-e -t '];
        otherwise
          return;
      end
      
      [~, obj.log] = system([command, obj.filename]);
      
      if isempty(strfind(obj.log, 'Converted successfully:'))
        throw(MException('edf2mat:edf2asc',['Something went wrong, check log:\n' obj.log]));
      end
      
      if obj.verbose
        disp([kind ' successfully converted']);
      end
      
      obj.movefile(kind);
    end
    
    function createHeader(obj)
      names = fieldnames(obj.Header);
      names = names(1:end - 1);  % we skip the raw entry
      
      if ~isempty(obj.log)
        lineNrs = strfind(obj.log, 'Processed');
        header = obj.log(1:lineNrs(1) - 1);
        header = header(obj.HEADERSTART:end);
      else % create old header elements for backward compatibility
        header = obj.Header.raw;
      end
      
      header = textscan(header, '%s', 'delimiter', newline);
      header{1} = strrep(header{1}, '**', '');
      header{1} = strrep(header{1}, '|', '');
      header{1} = strrep(header{1}, '=', '');
      
      for i = 1:size(names, 1)
        line = i;
        if line > size(header{1}, 1), break; end
        obj.Header.(names{i}) = strtrim(strrep(header{1}{line}, [upper(names{i}) ': '], ''));
      end
      obj.Header.raw = header{:}(~cellfun(@isempty, header{:}));
      
      % sometimes we don't have all fields, especially when tracker records in dummy mode
      if ~isempty(obj.Header.serial_number)
        obj.Header.serial_number = strrep(obj.Header.serial_number, 'SERIAL NUMBER: ', '');
      end
      
      % parse control status if any
      cs = textscan(header{1}{end}, '%s', 'delimiter', ',');
      
      names = fieldnames(obj.controlStatus);
      for i = 1:size(fieldnames(obj.controlStatus), 1)
        line = i;
        if line > size(cs{1}, 1), break; end
        obj.controlStatus.(names{i}) = extractAfter(cs{1}{line}, ': ');
      end
    end
    
    function movefile(obj, kind)
      asciiname = strrep(obj.filename, '.edf', '.asc');
      switch kind
        case obj.cases.samples
          newfilename = obj.samplesFilename;
        case obj.cases.events
          newfilename = obj.eventsFilename;
        otherwise
          return;
      end
      movefile(asciiname, newfilename, 'f');
    end
    
    function processSamples(obj)
      %{
      % Open ASCII-Samples File
      fID = fopen(obj.samplesFilename, 'r');
      % Read it
      samples = textscan(fID, '%f %f %f %f %*s', 'delimiter', '\t', 'EmptyValue', nan);
      obj.Samples =  cell2struct(samples', fieldnames(obj.Samples));
      % Close
      fclose(fID);
      %}
      
      names = fieldnames(obj.Samples);
      
      % make values double for easier computation
      for i = 1:size(names, 1)
        samples = double(obj.Samples.(names{i})).';
        samples(samples == obj.MISSING_DATA_VALUE) = nan;
        obj.Samples.(names{i}) = samples;
      end
      
      endRecordings = obj.RawEDF.RECORDINGS([obj.RawEDF.RECORDINGS.state].' == obj.RECORDING_STATES.END);
      if isempty(endRecordings)
        warning('Edf2Mat:processSamples:noend', ...
          'Recording was not ended properly! Assuming recorded eye stayed the same for this trial!');
        startRec = obj.RawEDF.RECORDINGS([obj.RawEDF.RECORDINGS.state].' == obj.RECORDING_STATES.START);
        eye_used = zeros(size(obj.Samples.time, 1), 1) + double(startRec(1).eye);
      else
        recNr = nan(size(obj.Samples.time, 1), 1); % number of recording start/end
        for i = 1 : numel(endRecordings)
          recNr(obj.Samples.time < endRecordings(i).time) = i;
        end
        eye_used = double([obj.RawEDF.RECORDINGS(recNr).eye]).';
      end
      
      % TODO: Convert to the screen center coordinate system (in MM)
      if any(eye_used == obj.EYES.BINOCULAR)
        obj.Samples.posX      = obj.Samples.gx;
        obj.Samples.posY      = obj.Samples.gy;
        obj.Samples.pupilSize   = obj.Samples.pa;
      else
        % add old fields  % select column depending on the eye used!
        obj.Samples.posX = ...
          obj.Samples.gx(sub2ind(size(obj.Samples.gx), 1:numel(eye_used), eye_used(:)')).';
        obj.Samples.posY = ...
          obj.Samples.gy(sub2ind(size(obj.Samples.gy), 1:numel(eye_used), eye_used(:)')).';
        obj.Samples.pupilSize = ...
          obj.Samples.pa(sub2ind(size(obj.Samples.pa), 1:numel(eye_used), eye_used(:)')).';
      end
      obj.Samples.posXMM = obj.toUx(obj.Samples.posX);
      obj.Samples.posYMM = obj.toUy(obj.Samples.posY);
    end
    
    function processEvents(obj)
      eyeNames                = fieldnames(obj.EYES);
      
      % Messages
      Messages                = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.MESSAGEEVENT);
      Msg.time                = double([Messages.sttime]);
      Msg.info                = {Messages.message};
      
      % Start of recording
      startRecordings         = obj.RawEDF.RECORDINGS([obj.RawEDF.RECORDINGS.state].' == obj.RECORDING_STATES.START);
      Start.time              = double([startRecordings.time]);
      eyes                    = [startRecordings.eye]; % here not plus one as SR_RESEARCH can't follow it's own convention and start in recording with 1 whereas in events with 0!!!!
      
      Start.eye               =  eyeNames(eyes).';
      Start.info              =  eyeNames(eyes).';
      
      buttons                 = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.BUTTONEVENT);
      Button.time             = double([buttons.sttime]);
      Button.value1           = 0; % no idea where it should come from
      Button.value2           = 0; % no idea where it should come from
      Button.value3           = double([buttons.input]);
      
      inputs                  = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.INPUTEVENT);
      Input.time              = double([inputs.sttime]);
      Input.value             = double([inputs.input]);
      
      % prescaler
      prescaler               = 1; % Undocummented but from C-Code its always 1! print("PRESCALER\t1\n");
      
      % vprescaler
      vprescaler              = 1; % Undocummented but from C-Code its always 1! print("PRESCALER\t1\n");
      
      % Pupil Info
      pupilTypeNames          = fieldnames(obj.PUPIL);
      pupilInfo               = pupilTypeNames(double(cat(1, startRecordings.pupil_type) + 1));
      
      % Fixations
      startfix                = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.STARTFIX);
      Sfix.eye                = eyeNames(double([startfix.eye]) + 1).'; % + 1 because in c indexing start with 0 whereas in matlab with 1
      Sfix.time               = double([startfix.sttime]);
      %
      endfix                  = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.ENDFIX);
      Efix.eye                = eyeNames(double([endfix.eye]) + 1).'; % + 1 because in c indexing start with 0 whereas in matlab with 1
      Efix.start              = double([endfix.sttime]);
      Efix.end                = double([endfix.entime]);
      Efix.duration           = Efix.end - Efix.start;
      Efix.posX               = double([endfix.gavx]);
      Efix.posY               = double([endfix.gavy]);
      Efix.posXMM             = obj.toUx(Efix.posX);
      Efix.posYMM             = obj.toUy(Efix.posY);
      Efix.pupilSize          = double([endfix.ava]);
      
      % Saccades
      startSaccade            = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.STARTSACC);
      Ssacc.eye               = eyeNames(double([startSaccade.eye]) + 1).'; % + 1 because in c indexing start with 0 whereas in matlab with 1
      Ssacc.time              = double([startSaccade.sttime]);
      %
      endSaccade              = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.ENDSACC);
      Esacc.eye               = eyeNames(double([endSaccade.eye]) + 1).'; % + 1 because in c indexing start with 0 whereas in matlab with 1
      Esacc.start             = double([endSaccade.sttime]); % == double([startSaccade.sttime])!!!!!!
      Esacc.end               = double([endSaccade.entime]); % != double([startSaccade.entime]) => 0 !!!
      Esacc.duration          = Esacc.end - Esacc.start;
      Esacc.posX              = double([endSaccade.gstx]);
      Esacc.posY              = double([endSaccade.gsty]);
      Esacc.posXMM            = obj.toUx(Esacc.posX);
      Esacc.posYMM            = obj.toUy(Esacc.posY);
      Esacc.posXend           = double([endSaccade.genx]);
      Esacc.posYend           = double([endSaccade.geny]);
      Esacc.posXendMM         = obj.toUx(Esacc.posXend);
      Esacc.posYendMM         = obj.toUy(Esacc.posYend);
      
      Esacc.hypot             = hypot((double([endSaccade.gstx]) - double([endSaccade.genx])) ...
        ./((double([endSaccade.supd_x]) + double([endSaccade.eupd_x]))/2.0), ...
        (double([endSaccade.gsty]) - double([endSaccade.geny])) ...
        ./((double([endSaccade.supd_y]) + double([endSaccade.eupd_y]))/2.0)); % Hypotenouse of something ... ????
      
      Esacc.pvel              = double([endSaccade.pvel]);
      % Keep old namings after figuring out where they come from
      Esacc.value1            = Esacc.hypot;
      Esacc.value2            = Esacc.pvel;
          
      % Blinks
      startBlink              = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.STARTBLINK);
      Sblink.eye              = eyeNames(double([startBlink.eye]) + 1).'; % + 1 because in c indexing start with 0 whereas in matlab with 1
      Sblink.time             = double([startBlink.sttime]);
      %
      endBlink                = obj.RawEDF.FEVENT([obj.RawEDF.FEVENT.type].' == obj.EVENT_TYPES.ENDBLINK);
      Eblink.eye              = eyeNames(double([endBlink.eye]) + 1).'; % + 1 because in c indexing start with 0 whereas in matlab with 1
      Eblink.start            = double([endBlink.sttime]); % == double([startSaccade.sttime])!!!!!!
      Eblink.end              = double([endBlink.entime]); % != double([startSaccade.entime]) => 0 !!!
      Eblink.duration         = Eblink.end - Eblink.start;
      
      % End of recording
      endRecordings           = obj.RawEDF.RECORDINGS([obj.RawEDF.RECORDINGS.state].' == obj.RECORDING_STATES.END);
      End.time                = double([endRecordings.time]);
      End.info                = {'EVENTS'};
      End.info2               = {'RES'};
      End.ppd_x_ppd_total     = sum(obj.Samples.rx)/numel(obj.Samples.rx); % What does it significate? Sum of all screen pixels per degree divided by number of samples => What does it tell?
      End.ppd_y_ppd_total     = sum(obj.Samples.ry)/numel(obj.Samples.ry); % What does it significate? Sum of all screen pixels per degree divided by number of samples => What does it tell?
      End.value1              = End.ppd_x_ppd_total;
      End.value2              = End.ppd_x_ppd_total;
      
      % Create the Event structure
      obj.Events.Messages   = Msg;
      obj.Events.Start      = Start;
      obj.Events.Input      = Input;
      obj.Events.Buttons    = Button;
      obj.Events.prescaler  = prescaler;
      obj.Events.vprescaler = vprescaler;
      obj.Events.pupilInfo  = pupilInfo;
      obj.Events.Sfix       = Sfix;
      obj.Events.Ssacc      = Ssacc;
      obj.Events.Esacc      = Esacc;
      obj.Events.Efix       = Efix;
      obj.Events.Sblink     = Sblink;
      obj.Events.Eblink     = Eblink;
      obj.Events.End        = End;
    end
  end

  methods(Access = private)
    % convert pixel location in x into center screen x coordinate in mm
    function ux = toUx(obj, px)
      px0 = floor(obj.screenWidthPixel/2);                  % x pixel of the screen center
      uxPerPx = obj.screenWidthMM / obj.screenWidthPixel;   % physical size of one x pixel [mm]
      ux = (px - px0) * uxPerPx;
    end
     % convert pixel location in y into center screen y coordinate in mm
    function uy = toUy(obj, py)
      py0 = floor(obj.screenHeightPixel/2);                 % y pixel of the screen center
      uyPerPy = obj.screenHeightMM / obj.screenHeightPixel; % physical size of one y pixel [mm]
      uy = -(py - py0) * uyPerPy;
    end
  end
  
  methods(Static, Access = private)
    function gauss = createGauss2D(size, sigma)
      [Xm, Ym] = meshgrid(linspace(-.5, .5, size));
      
      s = sigma / size; % gaussian width as fraction of imageSize
      gauss = exp( -(( (Xm.^2) + (Ym.^2) ) ./ (2*s^2)) ); % formula for 2D gaussian
    end
  end
  
end