classdef Circle < Oval
  % Define an circle with a specified radius
  
  properties
    radius
  end
  
  methods
    function set.radius(r, val)
      r.height = val*2;
      r.width = val*2;
    end
    
    function rad = get.radius(r)
      rad = r.height/2;
    end
  end
  
  methods
    function r = Circle(xc, yc, radius)
      r = r@Oval(xc, yc, radius*2, radius*2);
    end
  end
  
end