classdef edf2mat < handle
  % EDF2MAT is a converter to convert Eyetracker data files
  % to MATLAB file and perform some tasks on the data
  %
  % Syntax: edf2mat(filename);
  %         edf2mat(filename, verbose);
  %
  % Inputs:
  %   filename:           must be of type *.edf
  %   verbose:            logical, can be true or false, default is true.
  %                       If you want to suppress output to console,
  %                       verbose has to be false
  %
  % Outputs:
  %	The edf2mat Object
  %
  % Other m-files required:
  %   everything in the @folder & private folder is required,
  %   private/edf2asc.exe and private/processEvents.m, the mex files and
  %   the dll's/frameworks. On Mac the edfapi.framework must be copied to
  %   /Library/Framworks/ !!!Not the personal Library but to the root
  %   Library
  %
  % Other Classes required:
  %   no
  %
  % See also: edf2mat.plot(), edf2mat.save(), edf2mat.heatmap()
  %           edf2mat.Events, edf2mat.Samples, edf2mat.Header
  %           edf2mat.about(), edf2mat.version()
  %
  % <a href="matlab:edf2mat.about()">Copyright & Info</a>
  
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
    VERSION = 1.00;              % Number of the latest Version
    VERSIONDATE = '2019/Dec/08'; % Date of the latest Version
    
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

  properties(SetAccess = private, GetAccess = private)
    % Here come the properties, which only can be read and written from
    % the class itself AND aren't visible from the outside
    
    verbose = false;
    log;
    cases   = struct('samples', 'Samples', 'events', 'Events');
    imhandle;
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
      'posX',      [], ...
      'posY',      [], ...
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
    
    controlStatus = struct(...
      'desktopTime',     [], ...
      'dataStore',       [], ...
      'subject',         [], ...
      'protocol',        [], ...
      'protocolVersion', []
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
        'EDFConverter:filename', 'filename must be given and be of type .edf!');
      
      assert(logical(exist(filename, 'file')), ...
        'EDFConverter:filenotfound', ['file ' filename ' not found!']);
      
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
          
          edf.plot()
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
      importer = @(varargin)edfimporter(varargin{:});
      obj.RawEDF      = importer(obj.filename);
      obj.Header.raw  = obj.RawEDF.HEADER;
      obj.Samples     = obj.RawEDF.FSAMPLE;
      
      obj.convertSamples();
      obj.createHeader();
      obj.convertEvents();
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
      %{
      if obj.oldProcedure
        obj.convertFile(obj.cases.samples);
      end
      %}
      obj.processSamples();
    end
    
    function convertEvents(obj)
      %{
      if obj.oldProcedure
        obj.convertFile(obj.cases.events);
      end
      %}
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
      
      %{
      if ispc
        command = ['"' path '\private\edf2asc.exe" -miss nan -y '];
      else
        command = ['wine', ' ', path, '/private/edf2asc.exe', ' ', '-miss nan -y '];
      end
      %}
      
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
      cs = textscan(header{end}, '%s', 'delimiter', ',');
      
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
      if obj.oldProcedure
        fID = fopen(obj.samplesFilename, 'r');
        % Read ASCII-Samples File
        samples = textscan(fID, '%f %f %f %f %*s', 'delimiter', '\t', ...
          'EmptyValue', nan);
        obj.Samples =  cell2struct(samples', fieldnames(obj.Samples));
        % Close ASCII-Samples File
        fclose(fID);
      else % create old header elements for backward compatibility
        names = fieldnames(obj.Samples);
        % make values double for easier computation
        for i = 1 : size(names, 1)
          samples = double(obj.Samples.(names{i})).';
          samples(samples == obj.EMPTY_VALUE) = nan;
          obj.Samples.(names{i}) = samples;
        end
        
        recNr = nan(size(obj.Samples.time, 1), 1);
        endRecordings = obj.RawEDF.RECORDINGS([obj.RawEDF.RECORDINGS.state].' == obj.RECORDING_STATES.END);
        if isempty(endRecordings)
          warning('Edf2Mat:processSamples:noend', 'Recording was not ended properly! Assuming recorded eye stayed the same for this trial!');
          startRec = obj.RawEDF.RECORDINGS([obj.RawEDF.RECORDINGS.state].' == obj.RECORDING_STATES.START);
          eye_used = zeros(size(obj.Samples.time, 1), 1) + double(startRec(1).eye);
        else
          for i = 1 : numel(endRecordings)
            recNr(obj.Samples.time < endRecordings(i).time) = i;
          end
          eye_used = double([obj.RawEDF.RECORDINGS(recNr).eye]).';
        end
        
        if any(eye_used == obj.EYES.BINOCULAR)
          obj.Samples.posX        = obj.Samples.gx;
          obj.Samples.posY        = obj.Samples.gy;
          obj.Samples.pupilSize   = obj.Samples.pa;
        else
          % add old fields
          obj.Samples.posX        = obj.Samples.gx(sub2ind(size(obj.Samples.gx), 1:numel(eye_used), eye_used(:)')).'; % select column depending on the eye used!
          obj.Samples.posY        = obj.Samples.gy(sub2ind(size(obj.Samples.gy), 1:numel(eye_used), eye_used(:)')).';
          obj.Samples.pupilSize   = obj.Samples.pa(sub2ind(size(obj.Samples.pa), 1:numel(eye_used), eye_used(:)')).';
        end
        
      end
    end
    
    % function proccessEvents is in private/processEvents
  end

  methods(Static)
    function ver = version()
      % edf2mat.version returns the version of the class
      %
      % Syntax: edf2mat.version()
      %
      % Inputs:
      %   No Inputs
      %
      % Outputs:
      %   version
      %
      % Example: edf2mat.version();
      %
      % See also: edf2mat.plot(), edf2mat.save()
      %           edf2mat.Events, edf2mat.Samples, edf2mat.Header
      %           edf2mat.about(), edf2mat.version()
      
      ver = eval([class(eval(mfilename)) '.VERSION']);
    end
    
    function about()
      % edf2mat.about() prints everything about the class
      %
      % Syntax: edf2mat.about()
      %
      % Inputs:
      %   No Inputs
      %
      % Outputs:
      %	  No Outputs
      %
      % Example: edf2mat.about();
      %
      % See also: edf2mat.plot(), edf2mat.save()
      %           edf2mat.Events, edf2mat.Samples, edf2mat.Header
      %           edf2mat.about(), edf2mat.version()
      
      className = mfilename;
      fprintf('\n\n\t About the <a href="matlab:help %s">%s</a>:\n\n', className, className);
      
      fprintf('\t\tVersion: \t%1.1f - %s\n', eval([className '.VERSION']), eval([className '.VERSIONDATE']));
      fprintf('\n');
    end
  end
  
  methods(Static, Access = private)
    gauss = createGauss2D(size, sigma);
  end
  
end