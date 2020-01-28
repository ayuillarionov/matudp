classdef ScreenInfo < handle
  
  properties(SetAccess = protected)
    screenIdx % ScreenNumber
    windowPtr % windowPointer
    
    isOpen = false; % indicates whether the screen is open
    
    isFullScreen % false if screenRect specified. Otherwise true.
    
    screenRectCached % typically specified for partial debug screen windows only
    
    % color scale
    cMax % pixel value for white
    cMin % pixel value for black
    
    oldPrefVisualDebugLevel % restore level of visual debugging, with levels 4 through 1
    oldPrefSkipSyncTests    % restore level of internal calibrations and display tests
    oldPrefMaxStdDevVBL     % restore level of tolerable noisyness threshold
  end
  
  properties
    multisample = 16; % Enable automatic hardware anti-aliasing of the display with 16 way multisampling.
    initBlack = true; % Note, it sets the level 1 of visual debugging - errors only
    skipSyncTests = false; % dont skip any sync tests
    % The amount of tolerable noisyness, i.e. the standard deviation of
    % measured timing samples from the computed mean. Default to 0.001, i.e., 1 msec.
    maxStdDevVBL = 1.8; % ??? very noisy timing! 
  end
  
  properties
    cs % CoordSystem
    glTransformLevel = 0; % openGL transformation level. if =1, then 'glPushMatrix' was called.
  end
  
  properties(Dependent)
    window
    screenRect % screen pixel coordinates of window, adjusts dynamically when not in full screen
    frameRate  % in Hz
  end
  
  properties(SetAccess = protected)
    pxWidth  % width of a window or screen in units of pixels
    pxHeight % height of a window or screen in units of pixels
    
    uxMin % min x value in units of coordSystem
    uxMax % max x value in units of coordSystem
    uxSignRight % delta for rightward moving x coordinates (-1 or 1)
    uyMin % min y value in units of coordSystem
    uyMax % max y value in units of coordSystem
    uySignDown % delta for downward moving y coordinates (-1 or 1)
  end
  
  methods
    function si = ScreenInfo(screenIdx, cs, screenRect)
      if nargin < 2 || ~isa(screenIdx, 'double') || ~isa(cs, 'CoordSystem')
        error('Usage: ScreenInfo(uint screenIdx, CoordSystem cs)');
      end
      
      assert((screenIdx>=0)&(mod(screenIdx,1)==0), 'screenIdx is not positive integer.')
      si.screenIdx = screenIdx;
      
      assert(isa(cs, 'CoordSystem'), 'cs must be of class CoordSystem().');
      si.cs = cs;
      
      if exist('screenRect', 'var') && ~isempty(screenRect)
        % typically specified for partial debug screen windows only
        si.screenRectCached = screenRect;
        si.isFullScreen = false;
      else
        si.isFullScreen = true;
      end
      
      si.update();
    end
    
    function update(si)
      if si.isFullScreen
        si.screenRectCached = Screen('Rect', si.screenIdx); % Get local rect of screen.
      end
      
      si.cMin = 0; % BlackIndex(si.screenIdx); % pixel value for black
      si.cMax = 1; % WhiteIndex(si.screenIdx); % pixel value for white
    end
    
    function delete(si)
      si.close();
    end
    
    function open(si)
      % AssertOpenGL; KbName('UnifyKeyNames').
      %PsychDefaultSetup(1);
      
      si.setPrefs();
      
      if si.initBlack
        initColor = [si.cMin si.cMin si.cMin];
        textColor = [si.cMax si.cMax si.cMax];
      else
        initColor = [si.cMax si.cMax si.cMax];
        textColor = [si.cMin si.cMin si.cMin];
      end
      
      if si.isFullScreen
        % Open an onsreen window. Poke initColor into each pixel.
        % Enable automatic hardware anti-aliasing of the display with multisampling.
        si.windowPtr = Screen(si.screenIdx, 'OpenWindow', initColor, ...
          [], [], [], [], si.multisample);
      else
        % according to http://tech.groups.yahoo.com/group/psychtoolbox/message/13817
        % setting specialFlags = 32 makes the call to GlobalRect query the window
        % manager so that when you move the GUI window around or resize it, the rect
        % returned remains accurate
        specialFlags = 32;
        si.windowPtr = Screen(si.screenIdx, 'OpenWindow', initColor, ...
          si.screenRect, [], [], [], si.multisample, [], specialFlags );
      end
      
      % AYuI: set default text color opposite to background color
      Screen(si.windowPtr, 'TextColor', textColor);
      
      % enable PTB to pass color values in OpenGL's native floating point color range of 0.0 to 1.0
      Screen(si.windowPtr, 'ColorRange', 1.0);
      % Set the current alpha-blending mode and the color buffer writemask:
      % anti-aliasing (smoothing) by Screen('DrawLines'), Screen('DrawDots') and for
      % drawing masked stimuli with the Screen('DrawTexture') command.
      Screen(si.windowPtr, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      
      lims = si.cs.getLimitsRect(si);
      si.uxMin = lims(1); % min x value in units of coordSystem
      si.uxMax = lims(3); % max x value in units of coordSystem
      si.uyMin = lims(2); % min y value in units of coordSystem
      si.uyMax = lims(4); % max y value in units of coordSystem
      si.uxSignRight = sign(diff(si.cs.toUx(si, [0 1]))); % delta for rightward moving x coordinates (-1 or 1)
      si.uySignDown = sign(diff(si.cs.toUy(si, [0 1])));  % delta for downward moving y coordinates (-1 or 1)
      
      % apply scaling and translation to align openGL coordinates with coordinate system
      si.glTransformLevel = si.cs.applyTransform(si);
      
      si.isOpen = true;
    end
    
    function close(si)
      % Close all open onscreen and offscreen windows and textures, movies and video sources.
      Screen('CloseAll')
      si.restorePrefs();
      si.isOpen = false;
    end
    
    function setPrefs(si)
      if si.initBlack
        % level 1 of visual debugging - errors only
        si.oldPrefVisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 1);
      end
      if si.skipSyncTests
        % completely skip all tests and calibrations
        si.oldPrefSkipSyncTests = Screen('Preference', 'SkipSyncTests', 2 );
      else
        % perform all tests and calibrations
        si.oldPrefSkipSyncTests = Screen('Preference', 'SkipSyncTests', 0 );
      end
      if ~isempty(si.maxStdDevVBL)
        % adjust the threshold settings used for sync tests
        si.oldPrefMaxStdDevVBL = Screen('Preference','SyncTestSettings', si.maxStdDevVBL);
      end
    end
    
    function restorePrefs(si)
      if ~isempty(si.oldPrefVisualDebugLevel)
        % restore level of visual debugging
        Screen('Preference', 'VisualDebugLevel', si.oldPrefVisualDebugLevel);
      end
      if ~isempty(si.oldPrefSkipSyncTests)
        % restore level of internal calibrations and display tests
        Screen('Preference', 'SkipSyncTests', si.oldPrefSkipSyncTests );
      end
      if ~isempty(si.oldPrefMaxStdDevVBL)
        % restore level of tolerable noisyness threshold
        Screen('Preference','SyncTestSettings', si.oldPrefMaxStdDevVBL);
      end
    end
    
  end
  
  methods
    function window = get.window(si)
      assert(~isempty(si.windowPtr), 'Call .open() first!');
      window = si.windowPtr;
    end
    
    function rect = get.screenRect(si)
      % get the global pixel coordinates of the window's boundaries
      % for full screen windows this is the [0 0 pixelsInX pixelsInY] size of the monitor
      % for partial screen windows this is the coordinates occupied on screen,
      % which may change if the window is moved or resized while running
      
      if si.isFullScreen || ~si.isOpen
        % in full screen mode, this doesn't change, so used the rect cached during .update()
        % also, if the screen hasn't been opened yet, then it must be its initial size
        rect = si.screenRectCached;
      else
        % if not in full screen mode, the window may be resized, so query the rect directly
        rect = Screen('GlobalRect', si.windowPtr);
      end
    end
    
    function frameRate = get.frameRate(si)
      assert(~isempty(si.windowPtr), 'Call .open() first!');
      
      % nominal video frame rate in Hz, as reported by computer's video driver
      %frameRate = Screen('NominalFrameRate', si.windowPtr);
      
      % estimate of the monitor flip interval in seconds with sub-millisecond accuracy
      [flipInterval, ~, ~] = Screen('GetFlipInterval', si.windowPtr);
      frameRate = 1/flipInterval; % in Hz
    end
    
    function set.cs(si, cs)
      assert(isa(cs, 'CoordSystem'), 'Must be of class CoordSystem.');
      si.cs = cs;
    end
  end
  
end