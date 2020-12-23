classdef Oval < ScreenObject
  % Define an oval target with a specified rectangle.
  
  properties
    xc
    yc
    width
    height
    
    color
    
    borderWidth = 0;
    borderColor
    
    fillColor
    fill = false;
  end
  
  properties(Dependent)
    x1
    y1
    x2
    y2
  end

  methods
    function r = Oval(xc, yc, width, height)
      r.xc = xc;
      r.yc = yc;
      r.width = width;
      r.height = height;
    end
    
    % a one-line string used to concisely describe this object
    function str = describe(r)
      if r.fill
        fillStr = 'filled';
      else
        fillStr = 'unfilled';
      end
      
      str = sprintf('%s: (%g, %g) size %g x %g, %s', ...
        class(r), r.xc, r.yc, r.width, r.height, fillStr);
    end
    
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw object
    function update(r, mgr, sd) %#ok<INUSD>
      % nothing here
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(r, sd)
      state = sd.saveState();
      sd.penColor = r.borderColor;
      sd.penWidth = r.borderWidth;
      sd.fillColor = r.fillColor;
      sd.drawOval(r.x1, r.y1, r.x2, r.y2, r.fill);
      sd.restoreState(state);
    end

    function contour(r)
      if isprop(r, 'fill')
        r.fill = false;
      end
    end
    
    function fillIn(r)
      if isprop(r, 'fill')
        r.fill = true;
      end
    end
    
    function color = get.borderColor(r)
      % fill color defaults to frame color unless specified otherwise
      if isempty(r.borderColor)
        color = r.color;
      else
        color = r.borderColor;
      end
    end
    
    function color = get.fillColor(r)
      % fill color defaults to frame color unless specified otherwise
      if isempty(r.fillColor) && r.fill
        color = r.color;
      else
        color = r.fillColor;
      end
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
  
end