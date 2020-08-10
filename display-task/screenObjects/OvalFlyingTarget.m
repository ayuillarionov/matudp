classdef OvalFlyingTarget < Oval
  % Inherits class Oval with some basic properties.
  % Oval itself inherits from ScreenObject.
  
  properties(SetAccess = private, GetAccess = public)
    acquired = false;
    successful = false;
    
    vibrating = false;
    
    xOffset = 0;
    yOffset = 0;
    
    flying = false;
  end
  
  properties
    vibrateSigma = 2;
    flyToX = NaN;
    flyToY = NaN;
    flyVelocityMMS = 600; % 5 mm/frame on 120 Hz
  end
  
  properties(Dependent)
    x1o
    x2o
    y1o
    y2o
  end
  
  methods
    function obj = OvalFlyingTarget(xc, yc, width, height)
      obj = obj@Oval(xc, yc, width, height);
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
      
      if r.flying
        if isempty(r.flyToX) || isempty(r.flyToY)
          flyStr = sprintf('flying from (%d, %d)', r.xc, r.yc);
        else
          flyStr = sprintf('flying from (%d, %d) to (%d, %d)', r.xc, r.yc, r.flyToX, r.flyToY);
        end
      else
        flyStr = 'not flying';
      end
      
      str = sprintf('FlyingTarget: (%g, %g) size %g x %g, %s, %s, %s.', ...
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
    
    function success(r)
      r.successful = true;
    end
    
    function fly(r, toX, toY, velocity)
      r.stopVibrating();
      r.flying    = true;
      if nargin >= 3
        r.flyToX  = toX;
        r.flyToY  = toY;
      elseif any(isnan([r.flyToX, r.flyToY]))
        r.flyToX  = randi([-10000, 10000]);
        r.flyToX  = randi([-10000, 10000]);
      end
      if nargin == 4
        r.flyVelocityMMS = velocity;
      end
    end
    
    function stopFlying(r)
      r.flying    = false;
    end
    
    function normal(r)
      r.fill       = true;
      r.acquired   = false;
      r.successful = false;
      r.vibrating  = false;
      r.flying     = false;
      
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
    
    function tf = getIsArrived(r)
      tf = false;
      tf = tf || abs(r.xc + r.xOffset) > abs(r.flyToX);
      tf = tf || abs(r.yc + r.yOffset) > abs(r.flyToY);
    end
  end
    
  methods
    % update the object, mgr is a ScreenObjectManager
    % can be used to add or remove objects from the manager as well
    function update(r, mgr, sd)
      if r.vibrating
        r.xOffset = r.vibrateSigma * randn(1);
        r.yOffset = r.vibrateSigma * randn(1);
      else
        if r.flying && ~any(isnan([r.flyToX, r.flyToY]))
          flyVelocity = r.flyVelocityMMS / sd.si.frameRate; % mm per frame
          
          deltaX = r.flyToX - r.xc - r.xOffset;
          deltaY = r.flyToY - r.yc - r.yOffset;
          deltaVec = [deltaX deltaY] / norm([deltaX deltaY]) * flyVelocity;
          
          r.xOffset = r.xOffset + deltaVec(1);
          r.yOffset = r.yOffset + deltaVec(2);
          
          %disp([deltaVec, r.xOffset, r.yOffset, r.xc+r.xOffset, r.yc+r.yOffset])
          
          if r.getIsArrived()
            r.stopFlying();
            %r.hide();
          end
          
          if r.getIsOffScreen(sd)
            r.hide();
          end
        else
          %r.xOffset = 0;
          %r.yOffset = 0;
        end
      end
    end
    
    %  Draw Oval Flying Target onto the screen
    function draw(r, sd)
      state = sd.saveState(); % cell
      if r.acquired
        sd.fillColor = r.fillColor;
        sd.penColor  = [1 1 1]; % black
      elseif r.successful
        sd.fillColor = [1 1 1];
        sd.penColor  = [1 1 1];
      else
        sd.fillColor = r.fillColor;
        sd.penColor  = r.borderColor;
      end
      
      sd.penWidth = r.borderWidth; % default is 0
      sd.drawOval(r.x1o, r.y1o, r.x2o, r.y2o, r.fill);
      sd.restoreState(state);
    end
  end
  
end