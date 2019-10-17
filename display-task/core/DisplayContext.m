classdef DisplayContext < handle
  
  properties(SetAccess = protected) % access from class or subclasses only
    name    % name to be used by get/setDisplayContext()
    cs      % CoordSystem
    screenIdx = 0; % screen to use for psychtoolbox
    
    screenRect = []; % empty means full screen, else supply xMin, yMin, xMax, yMax
    
    networkReceiveIP
    networkReceivePort
    networkTargetIP
    networkTargetPort
    
    photoboxPositions % struct with fields xc, yc, and radius
    
    debugLevel = DisplayContext.DebugLevelDefault;
  end
  
  properties(Constant) % once initialized this values cannot be changed.
    % used for specifying an objects debug level
    DebugLevelDefault = 10;
    DebugLevelNone = 0;
    DebugLevelAll = Inf;
  end
  
  properties(Dependent) % values depend on the values of other properties
    useFullScreen % true for full screen, false otherwise
  end
  
  methods
    function cxt = DisplayContext()
      % install defaults
      cxt.screenIdx = max(Screen('Screens'));
      cxt.cs = ShiftScaleCoordSystem.buildCenteredForScreenSize(cxt.screenIdx);
    end
    
    function tf = get.useFullScreen(cxt)
      tf = isempty(cxt.screenRect);
    end
    
    function debugMsg(cxt, level, varargin)
      if level <= cxt.debugLevel
        if numel(varargin) == 1
          str = varargin{1};
        else
          str = sprintf(varargin{:});
        end
        fprintf('%s', str);
      end
    end
    
    function makeDebugScaledContext(cxt)
      if isa(cxt.cs, 'MouseOnlyGUIScaledCoordSystem')
        warning('DisplayContext already using scaled coordinate system');
        return;
      end
      
      % transform the current coordinate system into a scaled windowed version
      cxt.cs = MouseOnlyGUIScaledCoordSystem(cxt.cs);
      cxt.debugLevel = DisplayContext.DebugLevelAll;
      cxt.name = sprintf('%s_debug', cxt.name);
      
      % take up the upper left third of the primary screen, but set
      % height to maintain aspect ratio
      cxt.screenIdx = min(Screen('Screens'));
      [pw, ph] = Screen('WindowSize', cxt.screenIdx);
      [pwOrig, phOrig] = Screen('WindowSize', cxt.cs.csFull.screenIdx);
      
      width = pw/3;
      height = width * phOrig / pwOrig;
      
      cxt.screenRect = [0 0 width height];
    end
  end
  
  methods(Sealed) % the method cannot be redefined in a subclass
    function info = getInfo(cxt)
      if isempty(cxt.name)
        error('No .name specified for this DisplayContext child class.');
      end
      
      % return a struct containing all public fields and values
      fields = fieldnames(cxt);
      
      for i = 1:length(fields)
        info.(fields{i}) = cxt.(fields{i});
      end
      
      info = orderfields(info); % order fields in ASCII dictionary order
    end
  end
  
end
