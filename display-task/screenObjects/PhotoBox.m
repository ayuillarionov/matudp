classdef PhotoBox < Circle
  
  properties(SetAccess = protected)
    photoboxId  % unique identifier for this photobox's position
    status      % 0 == off, 1 == on
    flashStatus % 0 == off, 1 == pending_draw, 2 == drawn
    
    % every other frame the intensity is slightly toggled,
    % regardless of whether the photobox is on or off
    oscillateEachFrame = true;
    
    frameEven = false;
  end
  
  properties(Constant)
    OFF = 0;
    ON = 1;
    
    FLASH_OFF = 0;
    FLASH_PENDING_DRAW = 1;
    FLASH_DRAWN = 2;
  end
  
  methods
    function r = PhotoBox(cxt, photoboxId)
      if nargin < 1
        error('Usage: photobox(DisplayContext)');
      end
      if nargin < 2
        photoboxId = 1;
      end
     
      border_color = [0 0 0]; % black
      border_width = 5;       % the radius will be extended by this value
      
      if isempty(cxt.photoboxPositions) || length(cxt.photoboxPositions) < photoboxId
        xc = 0;
        yc = 0;
        rad = 20 + border_width;
      else
        pos = cxt.photoboxPositions(photoboxId);
        xc = pos.xc;
        yc = pos.yc;
        border_width = pos.borderWidth;
        rad = pos.radius + border_width;
      end
      
      r = r@Circle(xc,yc,rad);
      r.photoboxId = photoboxId;
      
      r.fill = true;
      r.borderColor = border_color;
      r.borderWidth = border_width;
      r.hide();
      
      r.status = r.OFF;
      r.flashStatus = r.FLASH_OFF;
    end
    
    function str = describe(r)
      str = sprintf('PhotoBox %d', r.photoboxId);
    end
    
    function on(r)
      r.show();
      r.status = r.ON;
      r.flashStatus = r.FLASH_OFF;
    end
    
    function off(r)
      % allow for frame by frame modulations too
      r.show();
      r.status = r.OFF;
      r.flashStatus = r.FLASH_OFF;
    end
    
    function toggle(r)
      % allow for frame by frame modulations too
      r.show();
      if r.status == r.OFF
        r.status = r.ON;
      else
        r.status = r.OFF;
      end
      r.flashStatus = r.FLASH_OFF;
    end
    
    function flash(r)
      r.show();
      r.status = r.ON;
      r.flashStatus = r.FLASH_PENDING_DRAW;
    end
    
    function update(r, mgr, sd)
      if isempty(r.fillColor)
        r.fillColor = sd.white;
        %r.borderColor = sd.white;
      end
      
      update@Circle(r, sd);
      
      if r.flashStatus == r.FLASH_DRAWN
        r.status = r.OFF;
        r.flashStatus = r.FLASH_OFF;
      end
      
      if r.status == r.ON
        if r.frameEven || ~r.oscillateEachFrame
          r.fillColor = [1 1 1];
        else
          r.fillColor = [0.9 0.9 0.9];
        end
      else
        if r.frameEven && r.oscillateEachFrame
          r.fillColor = [0.2 0.2 0.2];
        else
          r.fillColor = [0 0 0];
        end
      end
      
      r.frameEven = ~r.frameEven;
      %fprintf('%g %g %g\n', r.fillColor(1), r.fillColor(2), r.fillColor(3));
    end
    
    function draw(r, sd)
      if r.flashStatus == r.FLASH_PENDING_DRAW
        r.flashStatus = r.FLASH_DRAWN;
      end
      draw@Circle(r, sd);
    end
  end
  
end