classdef ScreenTargetObject < handle
  
  properties(SetAccess = protected, GetAccess = public)
    acquired   = false;
    successful = false;
    
    vibrating  = false;
    
    xOffset    = 0;
    yOffset    = 0;
    
    flying     = false;
    flyingAway = false;
  end
  
  properties
    vibrateSigma = 2;
    % used for flying away/to
    flyRefX = NaN;
    flyRefY = NaN;
    % velocity
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
      elseif isprop(obj, 'borderColor')
        color = obj.borderColor;
      else
        error(['==> color(or borderColor) is not a property of class ', class(obj)]);
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
      obj.flyingAway = true;
      if nargin == 4
        obj.fly(fromX, fromY, velocity);
      elseif nargin == 3
        obj.fly(fromX, fromY);
      else
        obj.fly();
      end
    end
    
    function fly(obj, X, Y, velocity)
      obj.stopVibrating();
      obj.flying = true;
      if nargin >= 3
        obj.flyRefX = X;
        obj.flyRefY = Y;
      elseif any(isnan([obj.flyRefX, obj.flyRefY]))
        obj.flyRefX = randi([-10000, 10000]);
        obj.flyRefY = randi([-10000, 10000]);
      end
      if nargin == 4
        obj.flyVelocityMMS = velocity;
      end
    end
    
    function stopFlyingAway(obj)
      obj.stopFlying();
    end
    
    function stopFlying(obj)
      obj.flyingAway = false;
      obj.flying   = false;
    end
    
    function normal(obj)
      obj.fillIn();
      obj.unacquire();
      obj.failure();
      obj.stopVibrating();
      obj.stopFlying();
      obj.resetOffset();
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
    
    function tf = getIsArrived(obj)
      tf = false;
      tf = tf || abs(obj.xOffset) > abs(obj.flyRefX - obj.xc);
      tf = tf || abs(obj.yOffset) > abs(obj.flyRefY - obj.yc);
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
        if isempty(r.flyRefX) || isempty(r.flyRefY)
          flyStr = sprintf('flying from (%d, %d)', r.xc, r.yc);
        else
          flyStr = sprintf('flying from (%d, %d) to (%d, %d)', r.xc, r.yc, r.flyRefX, r.flyRefY);
        end
      else
        flyStr = 'not flying';
      end
      
      str = sprintf('%s: (%g, %g) size %g x %g, %s, %s, %s.', ...
        class(r), r.xc, r.yc, r.width, r.height, fillStr, vibrateStr, flyStr);
    end
    
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw object
    % can be used to add or remove objects from the manager as well
    function update(obj, mgr, sd) %#ok<INUSL>
      if obj.vibrating
        obj.xOffset = obj.vibrateSigma * randn(1);
        obj.yOffset = obj.vibrateSigma * randn(1);
      else
        if obj.flying && ~any(isnan([obj.flyRefX, obj.flyRefY]))
          flyVelocity = obj.flyVelocityMMS / sd.si.frameRate; % mm per frame
          
          deltaX = obj.flyRefX - obj.xc - obj.xOffset;
          deltaY = obj.flyRefY - obj.yc - obj.yOffset;
          if obj.flyingAway % flying away the reference point
            deltaX = -deltaX;
            deltaY = -deltaY;
          end
          deltaVec = [deltaX deltaY] / norm([deltaX deltaY]) * flyVelocity;
          
          obj.xOffset = obj.xOffset + deltaVec(1);
          obj.yOffset = obj.yOffset + deltaVec(2);
          
          if obj.getIsArrived() % set the target to the destination point
            obj.xOffset = obj.flyRefX - obj.xc;
            obj.yOffset = obj.flyRefY - obj.yc;
            
            obj.stopFlying();
          end
          
          if obj.getIsOffScreen(sd)
            obj.hide();
          end
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