classdef RectangleTarget < Rectangle & ScreenTargetObject
  % Inherits class Rectangle with some basic properties.
  % Rectangle itself inherits from ScreenObject.
  
  properties(Dependent, SetAccess = protected)
    x1o % left border
    y1o % bottom border
    x2o % right border
    y2o % up border
  end
  
  methods
    function obj = RectangleTarget(xc, yc, width, height)
      obj = obj@Rectangle(xc, yc, width, height);
    end
    
    % a one-line string used to concisely describe this object
    function str = describe(obj)
      if obj.fill
        fillStr = 'filled';
      else
        fillStr = 'unfilled';
      end
      
      if obj.vibrating
        vibrateStr = 'vibrating';
      else
        vibrateStr = 'stationary';
      end
      
      if obj.flyingAway
        flyStr = sprintf('flying from (%d, %d)', obj.flyFromX, obj.flyFromY);
      else
        flyStr = 'not flying';
      end
      
      str = sprintf('%s: (%g, %g) size %g x %g, %s, %s, %s.', ...
        class(obj), obj.xc, obj.yc, obj.width, obj.height, fillStr, vibrateStr, flyStr);
    end
    
    function x1 = get.x1o(obj)
      x1 = obj.xc + obj.xOffset - obj.width/2;
    end
    
    function y1 = get.y1o(obj)
      y1 = obj.yc + obj.yOffset - obj.height/2;
    end
    
    function x2 = get.x2o(obj)
      x2 = obj.xc + obj.xOffset + obj.width/2;
    end
    
    function y2 = get.y2o(obj)
      y2 = obj.yc + obj.yOffset + obj.height/2;
    end
  end
    
  methods
    %  Draw Rectangle target onto the screen
    function drawTarget(obj, sd)
      sd.drawRect(obj.x1o, obj.y1o, obj.x2o, obj.y2o, obj.fill);
    end
  end
  
end