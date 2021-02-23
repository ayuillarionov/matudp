classdef Cross < ScreenObject
  
  properties
    xc
    yc
    width
    height
    
    color
    
    lineWidth = 1;
  end
  
  methods
    function obj = Cross(xc, yc, width, height)
      obj.xc = xc;
      obj.yc = yc;
      obj.width = width;
      obj.height = height;
    end
    
    function str = describe(obj)
      str = sprintf('%s: (%g, %g) size %g x %g', ...
        class(obj), obj.xc, obj.yc, obj.width, obj.height);
    end
    
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw object
    function update(obj, mgr, sd) %#ok<INUSD>
      % nothing here
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(obj, sd)
      state = sd.saveState();
      if isempty(obj.color)
        obj.color = sd.white;
      end
      sd.penColor = obj.color;
      sd.penWidth = obj.lineWidth;
      sd.drawCross(obj.xc, obj.yc, obj.width, obj.height);
      sd.restoreState(state);
    end
  end
  
end