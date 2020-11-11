classdef Cursor < Cross
  
  properties
    size; % cross width & height
    penWidth = 3;
    
    sizeTouching = 20;
    penWidthTouching = 5;
    
    touching = false; % default is non touching
    seen = false;
    lastNotSeen = []; % date vector [year month day hour minute seconds]
    threshNotSeenRecently = 0.5; % time in seconds that must elapse
  end
  
  properties(Dependent)
    notSeenRecently
  end
  
  methods
    function obj = Cursor(size)
      if nargin < 1
        size = 10;
      end
      obj = obj@Cross(0, 0, size, size); % Cross(xc, yc, width, height)
      obj.size = size;
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
      
      str = sprintf('%s: (%g, %g) %s, %s.', ...
        class(r), r.xc, r.yc, touchStr, seenStr);
    end
    
    function set.seen(r, val)
      if val
        r.seen = true;
      else
        r.seen = false;
      end
      
      if ~r.seen
        r.lastNotSeen = clock(); %#ok<MCSUP> % current date and time as date vector
      end
    end
    
    function tf = get.notSeenRecently(r)
      if isempty(r.lastNotSeen)
        tf = true;
      else
        tf = etime(clock, r.lastNotSeen) >= r.threshNotSeenRecently;
      end
    end
    
    function update(r, mgr, sd) %#ok<INUSD>
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