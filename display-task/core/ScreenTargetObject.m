classdef ScreenTargetObject < handle
  
  properties(SetAccess = protected, GetAccess = public)
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
  
  properties(Abstract, Dependent, SetAccess = protected)
    x1o % left border
    y1o % bottom border
    x2o % right border
    y2o % up border
  end
  
  properties
    successColor = [1 1 1]; % white;
  end
  
  properties(Dependent, SetAccess = protected, Hidden)
    defaultContourColor
    defaultFillColor
    
    acquiredContourColor
    acquiredFillColor
    
    successContourColor
    successFillColor
  end
  
  methods
    function set.successColor(obj, color)
      if isvector(color) && numel(color) == 3
        if isempty(obj.successColor) || any(obj.successColor ~= color)
          obj.successColor = color;
        end
      else
        error('==> Invalid color specification. Expected RGB triplet with the intensities in the range [0 1].');
      end
    end
    
    function color = get.defaultContourColor(obj)
      if isprop(obj, 'color')
        color = obj.color;
      else
        error(['==> color not a property of class ', class(obj)]);
      end
    end
    
    function color = get.defaultFillColor(obj)
      if isprop(obj, 'fillColor')
        color = obj.fillColor;
      else
        error(['==> fillColor not a property of class ', class(obj)]);
      end
    end
    
    function color = get.acquiredContourColor(obj)
      color = obj.successColor;
    end
    
    function color = get.acquiredFillColor(obj)
      color = obj.defaultFillColor;
    end
    
    function color = get.successContourColor(obj)
      color = obj.successColor;
    end
    
    function color = get.successFillColor(obj)
      color = obj.successColor;
    end
    
    function setOffset(obj, offset)
      if nargin >= 2
        obj.xOffset = offset(1);
        obj.yOffset = offset(2);
      end
    end
    
    function resetOffset(obj)
      obj.xOffset = 0;
      obj.yOffset = 0;
    end
    
    function vibrate(obj, sigma)
      if nargin >= 2
        obj.vibrateSigma = sigma;
      end
      obj.vibrating = true;
    end
    
    function stopVibrating(obj)
      obj.vibrating = false;
    end
    
    function acquire(obj)
      obj.acquired = true;
    end
    
    function unacquire(obj)
      obj.acquired = false;
    end
    
    function success(obj)
      obj.successful = true;
    end
    
    function failure(obj)
      obj.successful = false;
    end
    
    function flyAway(obj, fromX, fromY, velocity)
      obj.stopVibrating();
      obj.flyingAway = true;
      if nargin >= 3
        obj.flyFromX = fromX;
        obj.flyFromY = fromY;
      elseif any(isnan([obj.flyFromX, obj.flyFromY]))
        obj.flyFromX  = randi([-10000, 10000]);
        obj.flyFromY  = randi([-10000, 10000]);
      end
      if nargin == 4
        obj.flyVelocityMMS = velocity;
      end
    end
    
    function stopFlyingAway(obj)
      obj.flyingAway = false;
    end
    
    function normal(obj)
      if isprop(obj, 'fill')
        obj.fill     = true; %#ok<MCNPR>
      end
      
      obj.acquired   = false;
      obj.successful = false;
      obj.vibrating  = false;
      obj.flyingAway = false;
      
      obj.xOffset    = 0;
      obj.yOffset    = 0;
    end
  end
    
  methods(Access = protected)
    function tf = getIsOffScreen(obj, sd)
      tf = false;
      tf = tf || max([obj.x1o obj.x2o]) < sd.xMin;
      tf = tf || min([obj.x1o obj.x2o]) > sd.xMax;
      tf = tf || max([obj.y1o obj.y1o]) < sd.yMin;
      tf = tf || min([obj.y1o obj.y2o]) > sd.yMax;
    end
    
    function setDrawingColors(obj, sd)
      if obj.acquired
        sd.penColor  = obj.acquiredContourColor;
        sd.fillColor = obj.acquiredFillColor;
      elseif obj.successful
        sd.penColor  = obj.successContourColor;
        sd.fillColor = obj.successFillColor;
      else
        sd.penColor  = obj.defaultContourColor;
        sd.fillColor = obj.defaultFillColor;
      end
    end
  end
    
  methods(Sealed)
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw object
    % can be used to add or remove objects from the manager as well
    function update(obj, mgr, sd) %#ok<INUSL>
      if obj.vibrating
        obj.xOffset = obj.vibrateSigma * randn(1);
        obj.yOffset = obj.vibrateSigma * randn(1);
      else
        if obj.flyingAway
          flyVelocity = obj.flyVelocityMMS / sd.si.frameRate; % mm per frame
          
          deltaX = obj.xc + obj.xOffset - obj.flyFromX;
          deltaY = obj.yc + obj.yOffset - obj.flyFromY;
          deltaVec = [deltaX deltaY] / norm([deltaX deltaY]) * flyVelocity;
          
          obj.xOffset = obj.xOffset + deltaVec(1);
          obj.yOffset = obj.yOffset + deltaVec(2);
          
          if obj.getIsOffScreen(sd)
            obj.hide();
          end
        else
          obj.xOffset = 0;
          obj.yOffset = 0;
        end
      end
    end
    
    %  Draw Rectangle target onto the screen
    function draw(obj, sd)
      state = sd.saveState(); % cell
      obj.setDrawingColors(sd);
      sd.penWidth = obj.borderWidth; % default is 1
      drawTarget(obj, sd);
      sd.restoreState(state);
    end
  end
  
  methods(Abstract)
    % use the ScreenDraw object to draw this target object onto the screen
    drawTarget(obj, sd);
  end
  
end