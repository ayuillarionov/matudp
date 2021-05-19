classdef CrossTarget < Cross & ScreenTargetObject
  % Inherits class Rectangle with some basic properties.
  % Rectangle itself inherits from ScreenObject.
  
  properties(Dependent, SetAccess = protected)
    x1o % left border
    y1o % bottom border
    x2o % right border
    y2o % up border
  end
  
  methods
    function obj = CrossTarget(xc, yc, width, height)
      obj = obj@Cross(xc, yc, width, height);
      obj.normal();
    end
    
    function x1 = get.x1o(obj)
      x1 = obj.xc + obj.xOffset - obj.scale*obj.width/2;
    end
    
    function y1 = get.y1o(obj)
      y1 = obj.yc + obj.yOffset - obj.scale*obj.height/2;
    end
    
    function x2 = get.x2o(obj)
      x2 = obj.xc + obj.xOffset + obj.scale*obj.width/2;
    end
    
    function y2 = get.y2o(obj)
      y2 = obj.yc + obj.yOffset + obj.scale*obj.height/2;
    end
  end
    
  methods
    %  Draw Cross target onto the screen
    function drawTarget(obj, sd)
      sd.drawCross(obj.xc + obj.xOffset, obj.yc + obj.yOffset, ...
        obj.scale*obj.width, obj.scale*obj.height);
    end
  end
  
end