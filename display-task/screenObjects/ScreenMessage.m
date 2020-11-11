classdef ScreenMessage < ScreenObject
  
  properties
    x1
    y1
    message
    
    fontFace = 'Ubuntu Mono' % use a monospaced font to do wrapping well
    fontSize = 12;
    fontStyle = 0;
    color
  end
  
  methods
    function r = ScreenMessage(x1, y1)
      r.x1 = x1;
      r.y1 = y1;
    end
    
    function str = describe(r)
      str = sprintf('%s: (%g, %g)', class(r), r.x1, r.y1);
    end
    
    % update the object, mgr is a ScreenObjectManager, sd is a ScreenDraw instance
    function update(r, mgr, sd)
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(r, sd)
      if isempty(r.message)
        return;
      end
      
      state = sd.saveState();
      sd.fontFace = r.fontFace;
      sd.fontStyle = r.fontStyle;
      sd.fontSize = r.fontSize;
      
      if isempty(r.color)
        r.color = sd.white;
      end
      
      sd.penColor = r.color;
      sd.drawText(r.message, r.x1, r.y1);
      
      sd.restoreState(state);
    end
  end
  
end