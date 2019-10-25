classdef EyeLinkController < handle
  
  properties(SetAccess = protected) % access from class or subclass only
    eli                        % EyeLinkInfo instance
    eye_used = -1;             % 0 (LEFT_EYE), 1 (RIGHT_EYE), 2 (BINOCULAR), -1 (ERROR)
    
    evt                        % FSAMPLE, most recent float sample
    raw                        % raw sample data from GetFloatDataRaw or GetNewestFloatDataRaw
  end
  
  properties
    edfDir  = pwd;
    edfFile = [];
  end
  
  properties
    doDriftCorrection = false; % DO PRE-TRIAL DRIFT CORRECTION (optional for EyeLink 1000 eye trackers)
    
    trialIndex = 0;            % trial counter
    trialSuccess = 0;          % 1 (succesful), 0 (recycled)
  end
  
  methods
    function elc = EyeLinkController(eli, fileName, dirName)
      if nargin < 1 || ~isa(eli, 'EyeLinkInfo')
        error('Usage: EyeLinkController(EyeLinkInfo eli)');
      end
      elc.eli = eli;
      elc.evt = struct();
      elc.raw = struct();
      
      if exist('fileName', 'var') && ~isempty(fileName) &&  isempty(regexp(fileName, '[/\*:?"<>|]', 'once'))
        elc.edfFile = fileName;
      end
      if exist('dirName', 'var') && (exist(dirName, 'dir') == 7)
        elc.edfDir = dirName;
      end
    end
    
    function delete(elc)
      elc.eli.close();
    end
    
    function startTrial(elc, trialID, numTrials)
      if nargin < 2
        error('Usage: startTrial(trialID [,numTrials])');
      end
      
      % Sending a 'TRIALID' message to mark the start of a trial in Data Viewer.
      % This is different than the start of recording message START that is logged when the trial recording begins.
      % The viewer will not parse any messages, events, or samples, that exist in the data file prior to this message.
      Eyelink('Message', 'TRIALID %d', trialID);
      
      % This supplies the title at the bottom of the eyetracker display
      if ~exist('numTrials','var') || isempty(numTrials)
        Eyelink('Command', 'record_status_message "TRIAL %d"', trialID);
      else
        Eyelink('Command', 'record_status_message "TRIAL %d/%d"', trialID, numTrials);
      end
      
      Eyelink('Command', 'set_idle_mode');
      % clear tracker display
      Eyelink('Command', 'clear_screen %d', 0);
      
      if elc.doDriftCorrection
        % Do a drift correction at the beginning of each trial at the center of creen
        % NOTE: Performing drift correction (checking) is optional for EyeLink 1000 eye trackers.
        elc.eli.doDriftCorrection();
      end
    end
    
    function endTrial(elc)
      elc.trialIndex = elc.trialIndex + 1;
      
      % Send messages to report trial condition information.
      % Each message may be a pair of trial condition variable and its corresponding value following the '!V TRIAL_VAR' token message.
      % See "Protocol for EyeLink Data to Viewer Integration-> Trial Message Commands" section of the EyeLink Data Viewer User Manual.
      WaitSecs(0.001);
      Eyelink('Message', '!V TRIAL_VAR index %d', elc.trialIndex);
      %Eyelink('Message', '!V TRIAL_VAR imgfile %s', 'imgfile.jpg');
      if elc.trialSuccess
        Eyelink('Message', '!V TRIAL_VAR trialOutcome %s', 'succesful');
      else
        Eyelink('Message', '!V TRIAL_VAR trialOutcome %s', 'recycled');
      end

      % Sending a 'TRIAL_RESULT' message to mark the end of a trial in Data Viewer.
      % This is different than the end of recording message END that is logged when the trial recording ends.
      % The viewer will not parse any messages, events, or samples that exist in the data file after this message.
      Eyelink('Message', 'TRIAL_RESULT 0');
    end
    
    function synctime(elc)
      
    end
    
    % Start recording with data types requested
    function startrecording_error = startRecording(elc, file_samples, file_events, link_samples, link_events)
      if nargin > 5
        error('USAGE: startrecording_error = StartRecording( [file_samples, file_events, link_samples, link_events] )');
      end
      
      if ~exist('file_samples', 'var')
        file_samples = 1;
      end
      if ~exist('file_events', 'var')
        file_events = 1;
      end
      if ~exist('link_samples', 'var')
        link_samples = 1;
      end
      if ~exist('link_events', 'var')
        link_events = 1;
      end
      
      startrecording_error = Eyelink('StartRecording', file_samples, file_events, link_samples, link_events);
      
      elc.eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
      % returns 0 (LEFT_EYE), 1 (RIGHT_EYE) or 2 (BINOCULAR) depending on what data is
      if elc.eye_used == elc.eli.el.BINOCULAR
        elc.eye_used = elc.eli.el.LEFT_EYE; % use the left_eye data
      end
      
      fprintf(' ==> Eyelink : Start recording\n');
    end
    
    function stopRecording(elc)
      % Add 100 msec of data to catch final events and blank display
      WaitSecs(0.1);
      Eyelink('Stoprecording');
      fprintf(' ==> Eyelink : Stop recording\n');
    end
    
    function status = getNewestFloatSample(elc)
      status = -1;
      
      if ~elc.eli.dummymode && (Eyelink('IsConnected') > 0)
        error = Eyelink('CheckRecording');
        if error == 0
          status = Eyelink('NewFloatSampleAvailable');
        end
        if ( error == 0 && status > 0 )
          % get the copy of the most recent float sample in the form of an event structure
          elc.evt = Eyelink('NewestFloatSample');
        end
      else
        elc.eli.close();
      end
    end
    
    %{
    Raw structure fields:
	   raw_pupil           raw x, y sensor position of the pupil
	   raw_cr              raw x, y sensor position of the corneal reflection
	   pupil_area          raw pupil area
	   cr_area             raw cornela reflection area
	   pupil_dimension     width, height of raw pupil
	   cr_dimension        width, height of raw cr
	   window_position     x, y position of tracking window on sensor
	   pupil_cr            calculated pupil-cr from the raw_pupil and raw_cr fields
	   cr_area2            raw area of 2nd corneal reflection candidate
	   raw_cr2             raw x, y sensor position of 2nd corneal reflection candidate
    %}
    function status = getFloatSampleRaw(elc)
      status = -1;
      
      if ~elc.eli.dummymode && (Eyelink('IsConnected') > 0)
        error = Eyelink('CheckRecording');
        if error == 0
          status = Eyelink('GetNextDataType'); % item type of next queue
        end
        if ( error == 0 && status == elc.eli.el.SAMPLE_TYPE) % SAMPLE_TYPE = 200
          % get the copy of the most recent raw float sample in the form of an event structure
          [elc.evt, elc.raw] = Eyelink('GetFloatDataRaw', status, elc.eye_used);
        end
      else
        elc.eli.close();
      end
    end
    
    function status = getNewestFloatSampleRaw(elc)
      status = -1;
      
      if ~elc.eli.dummymode && (Eyelink('IsConnected') > 0)
        error = Eyelink('CheckRecording');
        if error == 0
          status = Eyelink('NewFloatSampleAvailable');
        end
        if ( error == 0 && status > 0 )
          % get the copy of the most recent float sample in the form of an event structure
          [elc.evt, elc.raw] = Eyelink('NewestFloatSampleRaw', elc.eye_used);
        end
      else
        elc.eli.close();
      end
    end
    
    function [time, gazeX, gazeY, status] = getGazePosition(elc)
      time = NaN('single'); gazeX = NaN(1,2,'double'); gazeY = NaN(1,2,'double');
      
      % update the copy of most resent gaze position
      % returns -1 if none or error, 0 if old, 1 if new
      status = elc.getNewestFloatSample();
      
      if ~isempty(fieldnames(elc.evt))
        if (elc.eye_used ~= -1) % do we know which eye to use yet?
          % if we do, get current gaze position from sample
          time = elc.evt.time;
          x = elc.evt.gx;
          y = elc.evt.gy;
          for i = 1:2
            % do we have valid data and is the pupil visible?
            if ( (x(i) ~= elc.eli.el.MISSING_DATA) && (y(i) ~= elc.eli.el.MISSING_DATA) && (elc.evt.pa(i) > 0) )
              gazeX(i) = elc.eli.toUx( x(i) ); % convert screen pixels into CoordSystem units
              gazeY(i) = elc.eli.toUy( y(i) );
            end
          end
        end
      end
    end
    
    function downloadFile(elc, fileName, dirName)
      if ~Eyelink('IsConnected')
        return;
      end
      
      if elc.eli.isFileOpen
        elc.eli.closeFile();
      end
      
      % zerod trial counter
      elc.trialIndex = 0;
      
      if exist('fileName', 'var') && ~isempty(fileName) && isempty(regexp(fileName, '[/\*:?"<>|]', 'once'))
        [~, ~, ext] = fileparts(fileName);
        if ~strcmp(ext,'.edf')
          fileName = [fileName, '.edf'];
        end
      else
        fileName = [elc.edfFile, elc.eli.edfFile, '.edf'];
      end
      
      if ~exist('dirName', 'var') || ~(7 == exist(dirName, 'dir'))
        dirName = elc.edfDir;
      end
      
      try
        fprintf('Receiving data file ''%s''\n', fileName);
        % returns: file size if OK, 0 if file transfer was cancelled, negative =  error code
        status = Eyelink('ReceiveFile', elc.eli.edfFile, fullfile(dirName, fileName));
        
        if (status > 0)
          fprintf('ReceiveFile status (file size = ) %d bytes\n', status);
        end
        
        if (exist(fullfile(dirName, fileName), 'file') == 2)
          fprintf('Data file ''%s'' can be found in ''%s''\n', fileName, dirName);
        end
      catch
        fprintf('Problem receiving data file ''%s''\n', fullfile(dirName, fileName));
      end
    end
    
  end
  
  properties (Access = private, Hidden)
    cmd = 'http://100.1.1.1/cmd.cgi?'; % command shell
    exeDir = '/elcl/exe/';             % Eyelink config files
    calDir = '/elcl/exe/cal/';         % stored calibration files
  end
  
  methods (Hidden)
    % get the list of sytem calibration files, sorted by modification time, newest first
    function [fileList, status] = listSystemCalibrationFiles(elc)
      [fileList, status] = elc.listCalibrationFiles();
    end
    
    % get the list of subject specific calibration files, sorted by modification time, newest first
    function [fileList, status] = listStoredCalibrationFiles(elc, subject)
      if ~exist('subject', 'var') || ~(ischar(subject) || isstring(subject))
        subject = [];
      end
      [fileList, status] = elc.listCalibrationFiles(elc.calDir, subject);
    end
    
    function [fileList, status] = listCalibrationFiles(elc, dir, subject)
      if ~exist('dir', 'var') || isempty(dir)
        dir = elc.exeDir;
      end
      if ~exist('subject', 'var') || ~(ischar(subject) || isstring(subject))
        subject = [];
      end
      
      [S, status] = urlread([elc.cmd, ...
        'ls%20-ltu%20', dir, [subject, '*.cal']]);
      
      if status
        fileList = parseList(S(1:end-1));
      else
        fileList = {};
      end
      
      function fC = parseList(S)
        C = strsplit(S, '\n');
        fC = cell(size(C, 2), 1); 
        for i = 1:size(C, 2)
         s = strsplit(C{i});
         [~, name, ext] = fileparts(s{end});
         fC{i} = [name, ext];
        end
      end
    end
    
    function status = saveLastCalibrationFiles(elc, subject)
      if ~exist('subject', 'var') || ~(ischar(subject) || isstring(subject))
        subject = 'subject';
      end
      
      % get the list of sytem calibration files,
      % sorted by modification time, newest first
      C = elc.listSystemCalibrationFiles();
      
      for i=1:2
        status = elc.saveCalibrationFile(C{i}, subject);
      end
    end
    
    function status = saveCalibrationFile(elc, cFile, subject)
      status = 0;
      if ~exist('cFile', 'var') || ~(ischar(cFile) || isstring(cFile))
        fprintf('Usage: EyeLinkController.saveCalibrationFile(<fileName>.cal[, subject])\n');
        return;
      end
      if ~exist('subject', 'var') || ~(ischar(subject) || isstring(subject))
        subject = [];
      end
      
      time = datetime('now', 'TimeZone', 'Europe/Zurich', 'Format', 'yMMdd.HHmmss.SSS');
      time = ['_time', char(time), '_'];
      
      [S, status] = urlread([elc.cmd, ...
        'cp%20-fv%20', elc.exeDir, cFile, '%20', elc.calDir, [subject, time, cFile]]);
      if status
          fprintf('%s\n', S(1:end-1));
      end
    end
    
    function status = loadLastStoredCalibrationFiles(elc, subject)
      if ~exist('subject', 'var') || ~(ischar(subject) || isstring(subject))
        subject = [];
      end

      % get the list of subject specific calibration files,
      % sorted by modification time, newest first
      C = elc.listStoredCalibrationFiles(subject);
      
      if size(C,1) < 3
        fprintf('==> Error: Unable to load the stored calibration files for %s.\n', subject);
        status = 0;
      else
        for i=1:2
          status = elc.loadStoredCalibrationFile(C{i});
        end
      end
    end
    
    function status = loadStoredCalibrationFile(elc, cFile)
      C = strsplit(cFile,'_');
      
      [S, status] = urlread([elc.cmd, ...
        'cp%20-fv%20', elc.calDir, cFile, '%20', elc.exeDir, C{end}]);
      if status
          fprintf('%s\n', S(1:end-1));
      end
    end
    
    % delete all stored calibration files from elc.calDir (for the subject only, if specified)
    function status = deleteStoredCalibrationFiles(elc, subject)
      if ~exist('subject', 'var') || ~(ischar(subject) || isstring(subject))
        subject = [];
      end
      
      [~, status] = urlread([elc.cmd, ...
        'rm%20', elc.calDir, [subject, '*.cal']]);
    end
  end
end