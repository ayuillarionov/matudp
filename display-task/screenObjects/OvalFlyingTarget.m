classdef OvalFlyingTarget < Oval & ScreenTargetObject
  % Inherits class Oval with some basic properties.
  % Oval itself inherits from ScreenObject.
  
  properties(Dependent, SetAccess = protected)
    x1o % left border
    y1o % bottom border
    x2o % right border
    y2o % up border
  end
  
  methods
    function r = OvalFlyingTarget(xc, yc, width, height)
      r = r@Oval(xc, yc, width, height);
    end
    
    function x1 = get.x1o(r)
      x1 = r.xc + r.xOffset - r.scale*r.width/2;
    end
    
    function y1 = get.y1o(r)
      y1 = r.yc + r.yOffset - r.scale*r.height/2;
    end
    
    function x2 = get.x2o(r)
      x2 = r.xc + r.xOffset + r.scale*r.width/2;
    end
    
    function y2 = get.y2o(r)
      y2 = r.yc + r.yOffset + r.scale*r.height/2;
    end
  end
    
  methods
    %  Draw Oval Flying Target onto the screen
    function drawTarget(r, sd)
      sd.drawOval(r.x1o, r.y1o, r.x2o, r.y2o, r.fill);
    end
  end
  
end