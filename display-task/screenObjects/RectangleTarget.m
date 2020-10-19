classdef RectangleTarget < Rectangle
  % Inherits class Rectangle with some basic properties.
  % Rectangle itself inherits from ScreenObject.
  
  properties(SetAccess = private, GetAccess = public)
    acquired   = false;
    successful = false;
    
    vibrating  = false;
    
    xOffset    = 0;
    yOffset    = 0;
    
    flyingAway = false;
  end
  
  properties
    vibrateSigma = 2;
    % used for flying away
    flyFromX = NaN;
    flyFromY = NaN;
    flyVelocityMMS = 600; % 5 mm/frame on 120 Hz
  end
  
  properties(Dependent, SetAccess = private)
    x1o
    y1o
    x2o
    y2o
  end
  
  properties
    successColor = [1, 1, 1]; % black;
  end
  
  properties(Dependent, SetAccess = private, Hidden)
    acquiredContourColor
    acquiredFillColor
    successContourColor
    successFillColor
  end
  
  methods
    function obj = RectangleTarget(xc, yc, width, height)
      obj = obj@Rectangle(xc, yc, width, height);
    end
    
    % a one-line string used to concisely describe this object
    function str = describe(r)
      if r.fill
        fillStr = 'filled';
      else
        fillStr = 'unfilled';
      end
      
      if r.vibrating
        vibrateStr = 'vibrating';
      else
        vibrateStr = 'stationary';
      end
      
      if r.flyingAway
        flyStr = sprintf('flying from (%d, %d)', r.flyFromX, r.flyFromY);
      else
        flyStr = 'not flying';
      end
      
      str = sprintf('RectangleTarget: (%g, %g) size %g x %g, %s, %s, %s.', ...
        r.xc, r.yc, r.width, r.height, fillStr, vibrateStr, flyStr);
    end
    
    function x1 = get.x1o(r)
      x1 = r.xc + r.xOffset - r.width/2;
    end
    
    function y1 = get.y1o(r)
      y1 = r.yc + r.yOffset - r.height/2;
    end
    
    function x2 = get.x2o(r)
      x2 = r.xc + r.xOffset + r.width/2;
    end
    
    function y2 = get.y2o(r)
      y2 = r.yc + r.yOffset + r.height/2;
    end
    
    function set.successColor(r, color)
      if isvector(color) && numel(color) == 3
        if isempty(r.successColor) || any(r.successColor ~= color)
          r.successColor = color;
        end
      else
        error('==> Invalid color input.');
      end
    end
    
    function color = get.acquiredContourColor(r)
      color = r.successColor;
    end
    
    function color = get.acquiredFillColor(r)
      color = r.fillColor;
    end
    
    function color = get.successContourColor(r)
      color = r.successColor;
    end
    
    function color = get.successFillColor(r)
      color = r.successColor;
    end
    
    function setOffset(r, offset)
      if nargin >= 2
        r.xOffset = offset(1);
        r.yOffset = offset(2);
      end
    end
    
    function resetOffset(r)
      r.xOffset = 0;
      r.yOffset = 0;
    end
    
    function contour(r)
      r.fill = false;
    end
    
    function fillIn(r)
      r.fill = true;
    end
    
    function vibrate(r, sigma)
      if nargin >= 2
        r.vibrateSigma = sigma;
      end
      r.vibrating = true;
    end
    
    function stopVibrating(r)
      r.vibrating = false;
    end
    
    function acquire(r)
      r.acquired = true;
    end
    
    function unacquire(r)
      r.acquired = false;
    end
    
    function success(r)
      r.successful = true;
    end
    
    function failure(r)
      r.successful = false;
    end
    
    function flyAway(r, fromX, fromY, velocity)
      r.stopVibrating();
      r.flyingAway = true;
      if nargin >= 3
        r.flyFromX = fromX;
        r.flyFromY = fromY;
      else any(isnan([r.flyFromX, r.flyFromY]))
        r.flyFromX  = randi([-10000, 10000]);
        r.flyFromX  = randi([-10000, 10000]);
      end
      if nargin == 4
        r.flyVelocityMMS = velocity;
      end
    end
    
    function stopFlyingAway(r)
      r.flyingAway = false;
    end
    
    function normal(r)
      r.fill       = true;
      r.acquired   = false;
      r.successful = false;
      r.vibrating  = false;
      r.flyingAway = false;
      
      r.xOffset    = 0;
      r.yOffset    = 0;
    end
  end
    
  methods(Access = private)
    function tf = getIsOffScreen(r, sd)
      tf = false;
      tf = tf || max([r.x1o r.x2o]) < sd.xMin;
      tf = tf || min([r.x1o r.x2o]) > sd.xMax;
      tf = tf || max([r.y1o r.y1o]) < sd.yMin;
      tf = tf || min([r.y1o r.y2o]) > sd.yMax;
    end
  end
    
  methods
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw object
    % can be used to add or remove objects from the manager as well
    function update(r, mgr, sd) %#ok<INUSL>
      if r.vibrating
        r.xOffset = r.vibrateSigma * randn(1);
        r.yOffset = r.vibrateSigma * randn(1);
      else
        if r.flyingAway
          flyVelocity = r.flyVelocityMMS / sd.si.frameRate; % mm per frame
          
          deltaX = r.xc + r.xOffset - r.flyFromX;
          deltaY = r.yc + r.yOffset - r.flyFromY;
          deltaVec = [deltaX deltaY] / norm([deltaX deltaY]) * flyVelocity;
          
          r.xOffset = r.xOffset + deltaVec(1);
          r.yOffset = r.yOffset + deltaVec(2);
          
          if r.getIsOffScreen(sd)
            r.hide();
          end
        else
          r.xOffset = 0;
          r.yOffset = 0;
        end
      end
    end
    
    %  Draw Rectangle target onto the screen
    function draw(r, sd)
      state = sd.saveState(); % cell
      if r.acquired
        sd.penColor  = r.acquiredContourColor;
        sd.fillColor = r.acquiredFillColor;
      elseif r.successful
        sd.penColor  = r.successContourColor;
        sd.fillColor = r.successFillColor;
      else
        sd.penColor  = r.color;
        sd.fillColor = r.fillColor;
      end
      
      sd.penWidth = r.borderWidth; % default is 1
      sd.drawRect(r.x1o, r.y1o, r.x2o, r.y2o, r.fill);
      sd.restoreState(state);
    end
  end
  
end