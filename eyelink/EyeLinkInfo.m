 classdef EyeLinkInfo < handle
  
  properties(SetAccess = protected) % access from class or subclass only
    el                  % struct with control codes
 
    edfFile = 'matUDP'; % EDF file name (8 characters or less)
    preambleText  = [];

    si                  % ScreenInfo instance
    
    version;            % tracker version (3 = Eyelink 1000)
    versionString;      % tracker software version

    trackerMode = 3;    % (1=remote, 3=desktop)
    
    isOpen = false;     % indicates whether the EyeLink is open
    isFileOpen = false; % indicates whether the file on Host PC is open
    isFullScreen;       % false if screenRect specified. Otherwise true
    
    oldPrefsList;       % list of old (default) tracker preferences
    
    firstRun = true;    % true until first setup command
  end
  
  properties
    dummymode = 0;      % 0 to attempt real initialization; 1 - dummy mode; 2 - broadcast mode
    verbosityLevel = 4; % level of verbosity for error/warning/status messages (default = 4)
  end
  
  methods
    function eli = EyeLinkInfo(si, fileName, preambleText)
      if nargin < 1 || ~isa(si, 'ScreenInfo')
        error('Usage: EyeLinkInfo(ScreenInfo si [, fileName, preambleText])');
      end
      
      eli.si = si; % ScreenInfo instance
      eli.isFullScreen = si.isFullScreen;
      
      eli.oldPrefsList = [];
      
      if ( exist('fileName', 'var') && ~isempty(fileName) )
        if numel(fileName) > 8
          warning('Thje EDF file name is limited to at most eight characters. Excess characters will be ignored.');
          eli.edfFile = fileName(1:8);
        else
          eli.edfFile = fileName;
        end
      end
      
      if ( exist('preambleText', 'var') && ~isempty(preambleText) )
        eli.preambleText = preambleText;
      end

      if si.isOpen
        eli.open(eli.preambleText)
      else
        % an initial structure that contains useful defaults and control codes
        % (e.g. tracker state bit and Eyelink key values).
        eli.el = EyelinkInitDefaults();
      end
      
    end
    
    % Initialization of the connection with the Eyelink GazeTracker.
    function open(eli, preambleText)
      assert(eli.si.isOpen, 'Open screen first!\n');
      if exist('preambleText', 'var')
        assert(ischar(preambleText) || isstring(preambleText), ...
          'Usage: open(EyeLinkInfo() [, preambleText])');
        eli.preambleText = preambleText;
      end
      
      % If set windowPtr, pixel coordinates are send to eyetracker and fill it with some sensible values.
      eli.el = EyelinkInitDefaults(eli.si.window);
      
      % Initialize Eyelink system and connection (at this point Eyelink should be connected)
      enableCallbacks = 'PsychEyelinkDispatchCallback';
       %[status, eli.dummymode] = EyelinkInit(eli.dummymode);
      
      if (Eyelink('Initialize', enableCallbacks) ~= 0 ) || eli.dummymode
        fprintf(' ==> Eyelink Init aborted (dummy mode not supported).\n');
        eli.close()
        return;
      end

      % retrieve tracker version (3 = Eyelink 1000) and tracker software version
      [eli.version, eli.versionString] = Eyelink('GetTrackerVersion');
      %vsn = regexp(eli.versionString, '\d', 'match');
      
      Eyelink('Verbosity', eli.verbosityLevel); % default is 4
      
      eli.trackerMode = Eyelink('TrackerMode'); % (1=remote, 3=desktop)
      
      % open file to record data to
      if ( ~exist('preambleText', 'var') || isempty(preambleText) )
        if ~isempty(eli.preambleText)
          eli.openFile('preamble_text', eli.preambleText);
        else
          eli.openFile();
        end
      else
        eli.openFile('preamble_text', preambleText);
      end
      
      % set preferences
      eli.setPrefs();
      
      % perform first setup
      eli.setup();
        
      % make sure we're still connected.
      assert( ~( ~(eli.dummymode==1) && ~(Eyelink('IsConnected')>0) ), 'EyeLink is disconnected');
      
      eli.isOpen = true;
    end

    function delete(eli)
      eli.close();
    end
    
    function close(eli)
      % Reset so tracker uses defaults calibration for other experiments
      if (Eyelink('IsConnected') > 0)
        EyeLinkInfo.sendCommand('generate_default_targets = YES');
      
        % Close all open onscreen and offscreen windows and textures, movies and video sources.
        if eli.isFileOpen
          eli.closeFile();
        end
        
        eli.restorePrefs();
      end
      
      Eyelink('Shutdown'); % Shutdown Eyelink
      
      eli.isFileOpen = false;
      eli.isOpen = false;
    end

    function openFile(eli, varargin)
      assert(~eli.isFileOpen, 'EDF file is already open.')
      
      p = inputParser();
      % First note on the file history after open EDF file.
      p.addParameter('preamble_text', '', @(x) ischar(x) || isstring(x));
      p.parse(varargin{:});
      
      error_code = Eyelink('Openfile', eli.edfFile);
      EyeLinkInfo.sendCommand('set_idle_mode');
      if ( error_code ~= 0 )
        fprintf('Cannot create EDF file ''%s'', error_code is %i ', eli.edfFile, error_code);
      else
        % Add the first note on the file history after open EDF file.
        if ~ismember('preamble_text', p.UsingDefaults)
          preambleText = sprintf('add_file_preamble_text ''Recorded by %s[%s]''', eli.versionString, p.Results.preamble_text);
          EyeLinkInfo.sendCommand(preambleText);
        elseif eli.firstRun
          preambleText = sprintf('add_file_preamble_text ''Recorded by %s''', eli.versionString);
          EyeLinkInfo.sendCommand(preambleText);
        end
        
        eli.isFileOpen = true;
      end
    end
    
    function closeFile(eli)
      assert(eli.isFileOpen, 'EDF file is already closed.')

      EyeLinkInfo.sendCommand('set_idle_mode');
      
      % Closes EDF file on tracker hard disk. Returns 0 if success, else error code.
      error_code = Eyelink('CloseFile');
      if error_code ~= 0
        fprintf('Cannot close EDF file ''%s'', error_code is %i ', eli.edfFile, error_code);
      else
        eli.isFileOpen = false;
      end
    end
    
    function setPrefs(eli)
      assert(eli.si.isOpen, 'Open screen first!\n');
      
      eli.el.window = eli.si.window;
      
      % We are changing calibration to a black background with white targets, no sound and smaller targets
      eli.el.backgroundcolour = BlackIndex(eli.si.window);
      eli.el.msgfontcolour  = WhiteIndex(eli.si.window);
      eli.el.imgtitlecolour = WhiteIndex(eli.si.window);
      eli.el.targetbeep = 0;
      eli.el.calibrationtargetcolour = WhiteIndex(eli.si.window);
      
      % for lower resolutions you might have to play around with these value a little.
      % If you would like to draw larger targets on lower res settings please edit PsychEyelinkDispatchCallback.m
      % and see comments in the EyelinkDrawCalibrationTarget function
      eli.el.calibrationtargetsize = 1;    % size of calibration target as percentage of screen
      eli.el.calibrationtargetwidth = 0.5; % width of calibration target's border as percentage of screen
      
      eli.el.displayCalResults = 1; % 1 to draw on the screen the calibration results 
      
      % messages/instructions
      %eli.el.eyeimgsize = 50; % percentage of screen
      
      % call this function for changes to the calibration structure to take affect
      eli.update();
    end
    
    function restorePrefs(eli)
      for i = 1:size(eli.oldPrefsList,1)
        EyeLinkInfo.sendCommand(eli.oldPrefsList(i));
      end
    end
    
    function update(eli)
      % call this function for changes to the calibration structure to take affect
      EyelinkUpdateDefaults(eli.el);
    end
    
    % SETUP tracker configuration
    function setup(eli, varargin)
      p = inputParser();
      
      p.addParameter('sample_rate', 1000, ...
        @(x) isscalar(x) && ismember(x, [0, 250, 500, 1000, 2000]));

      % physical screen sizes
      p.addParameter('screen_phys_coords', [eli.si.uxMin, eli.si.uyMax, eli.si.uxMax, eli.si.uyMin], ...
        @(x) validateattributes(x, {'numeric'}, {'raw', 'numel', 4}));
      
      % distance from eye to the top/bottom of the viewable portion of the monitor (in mm)
      % NOTE:  Variable read not supported
      p.addParameter('screen_distance', [690, 720], ...
      @(x) validateattributes(x, {'numeric'}, {'raw', 'numel', 2}));
      
      % SUPPORTED ONLY IN REMOTE MODE!
      % remote_camera_position <rh> <rv> <dx> <dy> <dz> , where
      % <rh> is the rotation of camera from screen (clockwise from top), i.e. how much the right edge
      %      of the camera is closer than left edge of camera (+10 assumes right edge is closer than
      %      left edge);
      % <rv> is the tilt of camera from screen (top toward screen);
      % <dx>, <dy> & <dz> specify the bottom-center of display in camera coords, where
      %      <dz> is something like the camera-to-screen distance (depth),
      %      i.e. distance between the lens (at the point where the lens connects to the camera) and
      %      monitor (in mm).
      p.addParameter('remote_camera_position', [-10, 17, 80, 60, -280], ...
      @(x) validateattributes(x, {'numeric'}, {'raw', 'numel', 5}));
      
      % set tracker mode
      cell_array_of_mount_configuration = { ...
        'MTABLER', ...   % Desktop, Stabilized Head, Monocular
        'BTABLER', ...   % Desktop, Stabilized Head, Binocular/Monocular (default)
        'RTABLER', ...   % Desktop (Remote mode), Target Sticker, Monocular
        'RBTABLER', ...  % Desktop (Remote mode), Target Sticker, Binocular/Monocular
        'AMTABLER', ...  % Arm Mount, Stabilized Head, Monocular
        'ARTABLER', ...  % Arm Mount (Remote mode), Target Sticker, Monocular
        'BTOWER', ...    % Binocular Tower Mount, Stabilized Head, Binocular/Monocular
        'TOWER', ...     % Tower Mount, Stabilized Head, Monocular
        'MPRIM', ...     % Primate Mount, Stabilized Head, Monocular
        'BPRIM', ...     % Primate Mount, Stabilized Head, Binocular/Monocular
        'MLRR', ...      % Long-Range Mount, Stabilized Head, Monocular, Camera Level
        'BLRR', ...      % Long-Range Mount, Stabilized Head, Binocular/Monocular, Camera Angled
        };
      p.addParameter('elcl_select_configuration', 'BTABLER', ...
        @(x) ischar(x) && any(validatestring(x, cell_array_of_mount_configuration)));
      % lens for remote mode tracking 16/25 mm
      p.addParameter('camera_lens_focal_length', 35, ...
        @(x) isscalar(x) && ismember(x, [16, 25, 35]));
      % set illumination power in camera setup screen (1 = 100%, 2 = 75%, 3 = 50%)
      % NOTE:  Variable read not supported
      p.addParameter('elcl_tt_power', 2, ...
        @(x) isscalar(x) && ismember(x, [1, 2, 3]));
      
      % --- Calibration and Validation.
      p.addParameter('calibration_type', 'HV9', ...
        @(x) ischar(x) && any(validatestring(x, {'H3', 'HV3', 'HV5', 'HV9', 'HV13'})));
      p.addParameter('randomize_calibration_order', 'YES', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      p.addParameter('randomize_validation_order', 'YES', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      % "YES" enables auto-calibration sequencing, "NO" forces manual calibration sequencing.
      p.addParameter('enable_automatic_calibration', 'YES', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      % Slows automatic calibration pacing. 1000 is a good value for most subject (default),
      % 1500 for slow subjects and when interocular data is require. 0 is OFF.
      p.addParameter('automatic_calibration_pacing', 1000, ...
        @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative', '<=', 1500}));
      % One must set this parameter with value NO for custom calibration.
      % One must also reset it to YES for subsequent experiments.
      % NOTE:  Variable read not supported
      p.addParameter('generate_default_targets', 'YES', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      
      % --- Tracker configuration.
      % Controls whether in monocular or binocular tracking mode
      p.addParameter('binocular_enabled', 'YES', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      % Controls which eye is recorded from in monocular mode
      % NOTE:  Variable not supported in binocular mode
      p.addParameter('active_eye', 'RIGHT', ...
        @(x) ischar(x) && any(validatestring(x, {'LEFT', 'RIGHT'})));
      % pupil tracking: Centroid (NO) or Ellipse (YES)
      p.addParameter('use_ellipse_fitter', 'YES', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      % Can be used to disable monitor marker LEDS, or to control antireflection option.
      % 0 for normal operation, 4 for antireflection on, -1 to turn off markers.
      % NOTE:  Variable read not supported
      p.addParameter('head_subsample_rate', 0, ...
        @(x) isscalar(x) && ismember(x, [-1, 0, 4]));
      % The level of filtering on the link/analog output (first argument), and on file data (second argument).
      % An additional delay of 1 sample is added to link/analog data for each filter level.
      % The file filter level is not changed unless two arguments are supplied.
      p.addParameter('heuristic_filter', [1 2], ...
        @(x) validateattributes(x, {'numeric'}, {'integer', 'nonnegative', '<=', 2}));
      % YES to convert pupil area to diameter, NO to output pupil area data
      p.addParameter('pupil_size_diameter', 'NO', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      
      % --- Mouse Simulation
      p.addParameter('aux_mouse_simulation', 'NO', ...
        @(x) ischar(x) && any(validatestring(x, {'YES', 'NO'})));
      
      % --- Setup parser (conservative saccade thresholds)
      % Parser data type: raw pupil position, head-referenced angle, and gaze position.
      % Sets how velocity information for saccade detection is to be computed. Almost always left to GAZE.
      p.addParameter('recording_parse_type', 'GAZE', ...
        @(x) ischar(x) && any(validatestring(x, {'GAZE', 'HREF', 'PUPIL'})));
      % Spatial threshold to shorten saccades. (in degrees)
      % Usually 0.15 for cognitive research, 0 for pursuit and neurological work.
      p.addParameter('saccade_motion_threshold', 0, ...
        @(x) isscalar(x) && isa(x, 'double') && (abs(x) <= 180));
      % Velocity threshold of saccade detector. (in degrees/sec)
      % Usually 30 for cognitive research, 22 for pursuit and neurological work.
      p.addParameter('saccade_velocity_threshold', 22, ...
        @(x) isscalar(x) && isa(x, 'double'));
      % Acceleration threshold of saccade detector. (in degrees/sec^2)
      % Usually 9500 for cognitive research, 5000 for pursuit and neurological work.
      p.addParameter('saccade_acceleration_threshold', 3800, ...
        @(x) isscalar(x) && isa(x, 'double'));
      % The maximum pursuit (or nystagmus) velocity accommodation by the saccade detector. (in degrees/sec)
      % Usually 60.
      p.addParameter('saccade_pursuit_fixup', 60, ...
        @(x) isscalar(x) && isa(x, 'double'));
      % Normally set to 0 to disable fixation update events. (in msec)
      % Set to 50 or 100 msec. to produce updates for gaze-controlled interface applications.
      p.addParameter('fixation_update_interval', 50, ...
        @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative'}));
      p.addParameter('fixation_update_accumulate', 50, ...
        @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative'}));
      
      % --- EDF file/link contents (remote mode possible add HTARGET)
      % These control what is included in the file or transfered over the link (see /elcl/exe/DATA.INI)
      cell_array_of_sample_data_types = {...
        'LEFT', 'RIGHT' , ... % data for one or both eyes (active_eye limits this for monoscopic)
        'GAZE', ...           % screen xy (gaze) position
        'GAZERES', ...        % units-per-degree screen resolution at point of gaze
        'HREF', ...           % head-referenced gaze (angular gaze coordinates)
        'PUPIL', ...          % raw eye camera pupil coordinates
        'AREA', ...           % pupil size data (diameter or aria)
        'STATUS', ...         % warning and error flags
        'BUTTON', ...         % button 1..8 state and change flags
        'INPUT', ...          % input port data lines
        'HTARGET', ...        % head position data (for EyeLink Remote only)
        %'HMARKER', ...        % infrared head tracking markers
        };
      p.addParameter('file_sample_data', cell_array_of_sample_data_types, ...
        @(x) all(ismember(upper(x), cell_array_of_sample_data_types)));
      p.addParameter('link_sample_data', cell_array_of_sample_data_types, ...
        @(x) all(ismember(upper(x), cell_array_of_sample_data_types)));
      cell_array_of_event_data_types = {...
        'GAZE', ...      % screen xy (gaze) position (pupil pos'n for calibration)
        'GAZERES', ...   % units-per-degree screen resolution (for start, end of event)
        'HREF', ...      % head-referenced gaze position
        'AREA', ...      % pupil area or diameter
        'VELOCITY', ...  % velocity of parsed position-type (avg, peak, start and end)
        'STATUS', ...    % warning and error flags, aggregated across event (not yet supported???)
        'FIXAVG', ...    % include ONLY averages in fixation and events, to reduce file size
        'NOSTART', ...   % start events have no date, just time stamp
        };
      p.addParameter('file_event_data', {'GAZE', 'GAZERES', 'HREF', 'AREA', 'VELOCITY'}, ...
        @(x) all(ismember(upper(x), cell_array_of_event_data_types)));
      p.addParameter('link_event_data', {'GAZE', 'GAZERES', 'HREF', 'AREA', 'VELOCITY'}, ...
        @(x) all(ismember(upper(x), cell_array_of_event_data_types)));
      cell_array_of_event_filters = {...
        'LEFT', 'RIGHT', ... % events for one or both eyes (active_eye limits this for monoscopic)
        'FIXATION', ...      % fixation start and end events
        'FIXUPDATE', ...     % fixation (pursuit) state update events
        'SACCADE', ...       % saccade start and end events
        'BLINK', ...         % blink start and end events
        'BUTTON', ...        % button 1..8 press or release events
        'MESSAGE', ...       % messages (user notes in file, ALWAYS use)
        'INPUT', ...         % changing in input port lines
        };
      p.addParameter('file_event_filter', cell_array_of_event_filters, ...
        @(x) all(ismember(upper(x), cell_array_of_event_filters)));
      p.addParameter('link_event_filter', cell_array_of_event_filters(1:7), ...
        @(x) all(ismember(upper(x), cell_array_of_event_filters(1:7))));
      
      % --- Maximum interval (in msec) to send something to host. Any packet (data, image, etc) will do,
      % but empty status packets will be sent if required. This is crutial for syncing the tracker
      % time estimate. 0 is off, else msec interval to send.
      % NOTE:  Variable read not supported
      p.addParameter('link_update_interval', 0, ...
        @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative'}));
 
      % specify the address of the listener PC
      % NOTE:  Variable read not supported
      p.addParameter('alt_dest_address', '100.1.1.3', ...
        @(x) ischar(x));
        
      p.parse(varargin{:});
      
      % --- Select first the configuration
      if eli.firstRun || ~any(strcmp('elcl_select_configuration', p.UsingDefaults))
        eli.storeOldPref('elcl_select_configuration');
        EyeLinkInfo.sendCommand('elcl_select_configuration', p.Results.elcl_select_configuration);
        WaitSecs(0.5);
        eli.trackerMode = Eyelink('TrackerMode'); % update tracker mode info (1=remote, 3=desktop)
      end
      
      % --- Parse focal length of the lens
      if eli.firstRun || ~any(strcmp('camera_lens_focal_length', p.UsingDefaults))
        eli.changeLens(p.Results.camera_lens_focal_length)
      end
      
      % --- Parse function inputs
      flds = fieldnames(p.Results);
      
      flds(cellfun(@(s) isequal(s, 'elcl_select_configuration'), flds), :) = []; % 'elcl_select_configuration' parsed already above
      flds(cellfun(@(s) isequal(s, 'camera_lens_focal_length'), flds), :) = []; % 'camera_lens_focal_length' parsed already above
      
      for i=1:numel(flds)
        if eli.firstRun || ~ismember(flds{i}, p.UsingDefaults)
          % store default tracker preferences
          eli.storeOldPref(flds{i});
          % set new preference values
          EyeLinkInfo.sendCommand(flds{i}, p.Results.(flds{i}));
        end
      end
      
      % --- Display setup
      if eli.firstRun
        % This command is crucial to map the gaze positions from the tracker to the screen pixel positions to determine fixation.
        eli.storeOldPref('screen_pixel_coords');
        EyeLinkInfo.sendCommand('screen_pixel_coords', ...
          [eli.si.screenRect(1), eli.si.screenRect(2), eli.si.screenRect(3)-1, eli.si.screenRect(4)-1]);
        EyeLinkInfo.sendMessage('DISPLAY_COORDS', ...
          [eli.si.screenRect(1), eli.si.screenRect(2), eli.si.screenRect(3)-1, eli.si.screenRect(4)-1]);
      end
      
      if eli.firstRun
        eli.storeOldPref('inputword_is_window');
        EyeLinkInfo.sendCommand('inputword_is_window = ON');
      end
      
      eli.firstRun = false;

    end
    
    % store default tracker preferences
    function status = storeOldPref(eli, com)
      assert(ischar(com) || isstring(com), ...
        'Usage: [status, reply] = storeOldPref(char/string)');
      
      [status, reply] = EyeLinkInfo.readFromTracker(com); % read the current status
      
      if status == 0 && ~strcmp(reply, 'Variable read not supported')
        idx = strfind(eli.oldPrefsList, com);
        if iscell(idx)
          eli.oldPrefsList(~cellfun('isempty', strfind(eli.oldPrefsList, com))) = []; % remove previous entrance if present
        end
        if reply == '0'
          eli.oldPrefsList = [ eli.oldPrefsList; ...
            strcat(com, " = OFF") ];
        elseif reply == '1'
          eli.oldPrefsList = [ eli.oldPrefsList; ...
            strcat(com, " = ON") ];
        else
          eli.oldPrefsList = [ eli.oldPrefsList; ...
            strcat(com, " = ", strjoin(upper(string(reply)))) ];
        end
      else
        status = -1;
      end
    end
    
    % query tracker for mount type using elcl_select_configuration variable
    function [status, reply] = queryMountType(eli)
      if (Eyelink('IsConnected') > 0)
        [status, reply] = Eyelink('ReadFromTracker', 'elcl_select_configuration');
      else
        status = -1;
        reply = [];
      end
    end
    
    % Eyetracker camera setup mode, calibration and validation
    function [result, messageString] = doTrackerSetup(eli, sendkey)
      % USAGE: [result, messageString] = doTrackerSetup(EyeLinkInfo() [, sendkey])
      %
      %		sendkey: set to go directly into a particular mode
      % 				'v', start validation
      % 				'c', start calibration
      % 				'd', start driftcorrection
      % 				13, or el.ENTER_KEY, show 'eye' setup image
      
      if nargin < 1
        error( 'USAGE: result = doTrackerSetup([sendkey])' );
      end
      
      if nargin == 2 && sendkey ~= eli.el.ENTER_KEY
        validatestring(sendkey, {'v', 'c', 'd'}, 'doTrackerSetup', 'sendkey');
      end
      
      if ~eli.dummymode
        % hide the mouse cursor and setup the eye calibration window
        Screen('HideCursorHelper', eli.si.window);
      end
      
      if eli.si.glTransformLevel > 0
        % reset an OpenGL matrix to its default identity setting
        Screen('glLoadIdentity', eli.si.window);
        % do Tracker Setup
        result = EyelinkDoTrackerSetup(eli.el);
        % re-apply scaling and translation to align openGL coordinates with coordinate system.
        eli.si.cs.applyTransform(eli.si);
      else
        result = EyelinkDoTrackerSetup(eli.el);
      end
      
      % get the last result of last calibration, validation, or drift correction as a messageString:
      % validation [left average error in degrees of visual angle]  [left x offset in pixels]  [left y offset in pixels]
      %            [right average error in degrees of visual angle] [right x offset in pixels] [right y offset in pixels]
      [~, messageString] = Eyelink('CalMessage');
    end
    
    % do drift correction
    function success = doDriftCorrection(eli, x, y, draw, apply, allowsetup)
      % USAGE: success = doDriftCorrection(EyeLinkInfo() [, x, y, draw, apply, allowsetup])
      %
      %   x,y:        position of DriftCorrection target in ScreenDraw units
      %   draw:       set to 1 to draw DriftCorrection target (0 - left to draw to usercode)
      %   apply:      set to 1 to apply the drift correction (0 - do only drift check)
      %   allowsetup: set to 1 to allow to go into trackersetup if ESCape key is pressed
      
      % if no x and y are supplied, set x,y to center coordinates
      if ~exist('x', 'var') || isempty(x) || ~exist('y', 'var') || isempty(y)
        px = eli.toPx(0);
        py = eli.toPy(0);
      else % convert into pixels coordinates
        if x < eli.si.uxMin
          warning('EyeLinkInfo.doDriftCorrection: x = %d coordinate is off screen (ymin = %d units)', x, eli.si.uxMin);
          x = eli.si.uxMin;
        elseif x > eli.si.uxMax
          warning('EyeLinkInfo.doDriftCorrection: x = %d coordinate is off screen (xmax = %d units)', x, eli.si.uxMax);
          x = eli.si.uxMax;
        end
        px = eli.toPx(x); % units (default mm) -> pixels

        if y < eli.si.uyMin
          warning('EyeLinkInfo.doDriftCorrection: y = %d coordinate is off screen (ymin = %d units)', y, eli.si.uyMin);
          y = eli.si.uyMin;
        elseif y > eli.si.uyMax
          warning('EyeLinkInfo.doDriftCorrection: y = %d coordinate is off screen (ymax = %d units)', y, eli.si.uyMax);
          y = eli.si.uyMax;
        end
        py = eli.toPy(y); % units (default mm) -> pixels
      end
      
      if ~exist('draw', 'var') || isempty(draw)
        draw = 1; % would be 0 to NOT draw a target
      end
      
      if ~exist('apply', 'var') || isempty(apply)
        apply = 0; % perfom only a drift check
      end
      
      if ~exist('allowsetup', 'var') || isempty(allowsetup)
        allowsetup = 1;
      end
      
      try
        % Make a backup copy of the current transformation matrix for later use/restoration of default state.
        Screen('glPushMatrix', eli.si.window);

        % undo the scalings and transformations
        Screen('glScale', eli.si.window, eli.si.cs.uxPerPx, -eli.si.cs.uyPerPy);
        Screen('glTranslate', eli.si.window, -eli.si.cs.px0, -eli.si.cs.py0);

        if apply % perform the drift correction
          EyeLinkInfo.sendCommand("driftcorrect_cr_disable = OFF");
        end
        
        success = EyelinkDoDriftCorrection(eli.el, round(px), round(py), draw, allowsetup);

        % Restore an OpenGL matrix by fetching it from the matrix stack.
        Screen('glPopMatrix', eli.si.window);
      catch ME
        success = 0;
        rethrow(ME);
      end
    end
    
    % Slowly copy an image from a window or texture to Matlab/Octave, by default returning a uint8 array.
    % The returned imageArray by default has three layers, i.e. it is an RGB image.
    function imageArray = getFullScreenImage(eli)
      imageArray = Screen('GetImage', eli.si.window, eli.si.screenRect);
    end
    
  end
  
  methods
    % convert user defined x coordinate into pixel location in x
    function px = toPx(eli, ux)
      px = eli.si.cs.toPx(eli.si, ux);
    end
    
    % convert user defined y coordinate into pixel location in y
    function py = toPy(eli, uy)
      py = eli.si.cs.toPy(eli.si, uy);
    end
    
    % convert pixel location in x into user defined x coordinate
    function ux = toUx(eli, px)
      ux = eli.si.cs.toUx(eli.si, px);
    end
    
    % convert pixel location in y into user defined y coordinate
    function uy = toUy(eli, py)
      uy = eli.si.cs.toUy(eli.si, py);
    end
  end
  
  methods(Static)
    function status = sendCommand(com, arg)
      if nargin < 1 || nargin > 2
        narginchk(1, 2); % throws an error if nargin is less than LOW or greater than HIGH.
      end
      
      assert(ischar(com) || isstring(com), ...
        'Usage: EyeLinkInfo.sendCommand(char/string, char/string/cell/numeric array)');
      
      if ~exist('arg', 'var') || isempty(arg)
        command = com;
      elseif isnumeric(arg)
        command = strcat(com, " = ", strjoin(upper(string(arg))));
      else
        command = strcat(com, " = ", strjoin(upper(string(arg)), ', '));
      end
      
      status = Eyelink('Command', char(command));
      
      if strcmp(char(command), 'set_idle_mode')
        WaitSecs(0.1);
      end
    end
    
    function status = sendMessage(msg, arg)
      if nargin < 1 || nargin > 2
        narginchk(1, 2); % throws an error if nargin is less than LOW or greater than HIGH.
      end
      
      assert(ischar(msg) || isstring(msg), ...
        'Usage: EyeLinkInfo.sendMessage(char/string, char/string/cell/numeric array)');
      
      if ~exist('arg', 'var') || isempty(arg)
        message = msg;
      elseif isnumeric(arg)
        message = strcat(upper(msg), " ", strjoin(upper(string(arg))));
      else
        message = strcat(upper(msg), " ", strjoin(upper(string(arg)), ', '));
      end
      
      status = Eyelink('Message', char(message));
    end
    
    % Query host to see the status of variable 'com' as reply.
    % Variables querable are listed in the .ini files in the host directories. Note that not all variables are querable.
    function [status, reply] = readFromTracker(com)
      
      assert(ischar(com) || isstring(com), ...
        'Usage: [status, reply] = EyeLinkInfo.readFromTracker(char/string)');
      
      if (Eyelink('IsConnected')>0)
        [status, reply] = Eyelink('ReadFromTracker', char(com));
      else
        status = -1;
        reply = '';
      end
    end
     
    % set the focal length of camera lens
    function changeLens(focalLength)
      
      if ~exist('focalLength', 'var') || isempty(focalLength) || ~ismember(focalLength, [16, 25, 35]) 
        error('Usage: EyeLinkInfo.changeLens(uint focalLenght), where folcalLength can be 16, 25 or 35.');
      end
      
      % Correct focal length of the lens
      % (empirical testing: https://www.sr-support.com/forum/eyelink/programming/49018-set-remote-mode-as-default-eyelink-toolbox)
      if focalLength == 16
        lensCommand = 'camera_lens_focal_length 17';
      elseif focalLength == 25
        lensCommand = 'camera_lens_focal_length 27';
      elseif focalLength == 35
        lensCommand = 'camera_lens_focal_length 38';
      else
        fprintf('Lenses with focal length %i do NOT exist.', focalLength);
      end
      
      % then send it to tracker
      EyeLinkInfo.sendCommand(lensCommand);
    end
  end
  
end