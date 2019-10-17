classdef ShiftScaleCoordSystem < CoordSystem
  
  properties
    screenIdx = NaN;     % screen this was built for originally
    unitName = 'pixels'; % default units
    uxPerPx = 1;         % x pixel pitch - size of one x pixel (default units is pixels)
    uyPerPy = 1;         % y pixel pitch - size of one y pixel (default units is pixels)
    px0 = 1;             % position of x = 0 in pixels
    py0 = 1;             % position of y = 0 in pixels
    invX = false; % x units run in opposite direction as x pixels (which puts 0 at left of screen)
    invY = true;  % y units run in opposite direction as y pixels (which puts 0 at top of screen)
  end
  
  methods(Static)
    function cs = buildCenteredForScreenSize(displayNumber, varargin)
      p = inputParser();
      
      % the 2D physical size of 1 screen pixel (default in mm)
      paramName = 'pixelPitch';
      default = [];
      errorMsg = 'Value must be a scalar array of no more as 2-dim.'; 
      validationFcn = @(x) ...
        assert(isempty(x) || isscalar(x) || numel(x) == 2, errorMsg);
      p.addParameter(paramName, default, validationFcn); % pixel pitch in mm
      
      paramName = 'units';
      default = 'mm';
      p.addParameter(paramName, default, @ischar);
      
      p.parse(varargin{:});
      
      if nargin < 1
        displayNumber = max(Screen('Screens'));
      end
      
      % Return the width and height of a window or screen in units of pixels.
      [pixW, pixH] = Screen('WindowSize', displayNumber);
      
      cs = ShiftScaleCoordSystem();
      cs.invY = true; % 0 at the top of screen
      cs.unitName = p.Results.units;
      % [x=0,y=0] is in the center of screen
      cs.px0 = floor(pixW/2);
      cs.py0 = floor(pixH/2);
      
      if ~isempty(p.Results.pixelPitch)
        pixelPitch = p.Results.pixelPitch;
        if isscalar(pixelPitch)
          pixelPitch(2) = pixelPitch; % y pixel pitch = x pixel pitch
        end
        cs.uxPerPx = pixelPitch(1); % physical size of one x pixel (default in mm)
        cs.uyPerPy = pixelPitch(2); % physical size of one y pixel (default in mm)
      else
        % ask OS for physical display size (in units of millimeters)
        [mmW, mmH] = Screen('DisplaySize', displayNumber);
        cs.uxPerPx = mmW / pixW; % physical size of one x pixel [mm]
        cs.uyPerPy = mmH / pixH; % physical size of one y pixel [mm]
      end
      
      cs.screenIdx = displayNumber;
    end
  end
  
  methods(Access=protected) % access from class or subclasses
    function cs = ShiftScaleCoordSystem()
    end
  end
  
  methods
    % return xMin, yMin, xMax, yMax in user coordinates
    function lims = getLimitsRect(cs, si)
      [pixW, pixH] = Screen('WindowSize', si.screenIdx);
      limX = cs.toUx(si, [0 pixW-1]);
      limY = cs.toUy(si, [0 pixH-1]);
      lims = [min(limX) min(limY) max(limX) max(limY)];
    end
    
    % convert x coordinate into pixel location in x
    function px = toPx(cs, si, ux) %#ok<*INUSL>
      if cs.invX
        ux = -ux;
      end
      px = ux / cs.uxPerPx + cs.px0;
    end
    
    % convert y coordinate into pixel location in y
    function py = toPy(cs, si, uy)
      if cs.invY
        uy = -uy;
      end
      py = uy / cs.uyPerPy + cs.py0;
    end
    
    % convert pixel location in x into x coordinate
    function ux = toUx(cs, si, px)
      ux = (px - cs.px0) * cs.uxPerPx;
      if cs.invX
        ux = -ux;
      end
    end
    
    % convert pixel location in y into y coordinate
    function uy = toUy(cs, si, py)
      uy = (py - cs.py0) * cs.uyPerPy;
      if cs.invY
        uy = -uy;
      end
    end
    
    % apply the transformation to the current gl context
    function glTransformLevel = applyTransform(cs, si)
      % Make a backup copy of the current transformation matrix for later use/restoration of default state.
      %Screen('glPushMatrix', si.windowPtr);
      
      % Define a translation by (tx, ty) in space, relative to the enclosing reference frame
      Screen('glTranslate', si.windowPtr, cs.px0, cs.py0);
      % Define a scale transform by (sx, sy) in space, relative to the enclosing reference frame.
      Screen('glScale', si.windowPtr, 1/cs.uxPerPx, -1/cs.uyPerPy);
      
      glTransformLevel = 1;
    end
  end
  
end