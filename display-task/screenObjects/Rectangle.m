classdef Rectangle < ScreenObject
  
  properties
    xc
    yc
    width
    height
    
    borderWidth = 1;
    color     % frame color if not filled and fill color if fillColor not set
    
    fillColor % fill color defaults to frame color unless specified otherwise
    fill = false;
  end
  
  properties(Dependent, SetAccess = protected)
    x1
    y1
    x2
    y2
  end
  
  methods
    function obj = Rectangle(xc, yc, width, height)
      obj.xc = xc;
      obj.yc = yc;
      obj.width = width;
      obj.height = height;
    end
    
    function str = describe(r)
      if r.fill
        fillStr = 'filled';
      else
        fillStr = 'unfilled';
      end
      str = sprintf('Rectangle: (%g, %g) size %g x %g, %s.', ...
        r.xc, r.yc, r.width, r.height, fillStr);
    end
    
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw object
    function update(r, mgr, sd) %#ok<INUSD>
      % nothing here
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(r, sd)
      state = sd.saveState();
      sd.penColor  = r.color;
      sd.fillColor = r.fillColor;
      sd.penWidth  = r.borderWidth;
      sd.drawRect(r.x1, r.y1, r.x2, r.y2, r.fill);
      sd.restoreState(state);
    end
    
    function color = get.fillColor(r)
      % fill color defaults to frame color unless specified otherwise
      if isempty(r.fillColor) && r.fill
        color = r.color;
      else
        color = r.fillColor;
      end
    end

    function contour(obj)
      obj.fill = false;
    end
    
    function fillIn(obj)
      obj.fill = true;
    end
    
    function x1 = get.x1(r)
      x1 = r.xc - r.width/2;
    end
    
    function y1 = get.y1(r)
      y1 = r.yc - r.height/2;
    end
    
    function x2 = get.x2(r)
      x2 = r.xc + r.width/2;
    end
    
    function y2 = get.y2(r)
      y2 = r.yc + r.height/2;
    end
  end
  
  methods(Access = private)
    function tf = getIsOffScreen(r, sd)
      tf = false;
      tf = tf || max([r.x1 r.x2]) < sd.xMin;
      tf = tf || min([r.x1 r.x2]) > sd.xMax;
      tf = tf || max([r.y1 r.y1]) < sd.yMin;
      tf = tf || min([r.y1 r.y2]) > sd.yMax;
    end
  end
  
end