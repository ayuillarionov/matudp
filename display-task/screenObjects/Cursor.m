classdef Cursor < Cross
  
  properties
    size; % cross width & height
    penWidth = 3;
    
    sizeTouching = 20;
    penWidthTouching = 5;
    
    touching = 0; % default is non touching
    seen = 0;
    lastNotSeen = []; % date vector [year month day hour minute seconds]
    threshNotSeenRecently = 0.5; % time in seconds that must elapse
  end
  
  properties(Dependent)
    notSeenRecently
  end
  
  methods
    function obj = Cursor()
      size = 10;
      obj = obj@Cross(0, 0, size, size); % Cross(xc, yc, width, height)
      obj.size = 10;
    end
    
    function set.seen(r, val)
      r.seen = val;
      
      if ~r.seen
        r.lastNotSeen = clock(); % current date and time as date vector
      end
    end
    
    function tf = get.notSeenRecently(r)
      if isempty(r.lastNotSeen)
        tf = false;
      else
        tf = etime(clock, r.lastNotSeen) < r.threshNotSeenRecently;
      end
    end
    
    function str = describe(r)
      if r.touching
        touchStr = 'touching';
      else
        touchStr = 'notTouching';
      end
      
      if r.seen
        if r.notSeenRecently
          seenStr = 'seen but missing recently';
        else
          seenStr = 'seen';
        end
      else
        seenStr = 'not seen';
      end
      
      str = sprintf('(%d, %d) %s, %s', ...
        r.xc, r.yc, touchStr, seenStr);
    end
    
    function update(r, mgr, sd)
      % nothing here
    end
    
    function draw(r, sd)
      state = sd.saveState();
      if r.notSeenRecently
        sd.penColor = sd.red;
      else
        sd.penColor = r.color;
      end
      
      if r.touching
        sd.penWidth = r.penWidthTouching;
        sz = r.sizeTouching;
      else
        sd.penWidth = r.penWidth;
        sz = r.size;
      end
      
      sd.drawCross(r.xc, r.yc, sz, sz);
      sd.restoreState(state);
    end
    
  end
  
end