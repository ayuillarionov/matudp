classdef PhotoBox < Circle
  
  properties(SetAccess = protected)
    photoboxId  % unique identifier for this photobox's position
    status      % 0 == off, 1 == on
    flashStatus % 0 == off, 1 == pending_draw, 2 == drawn
    
    % every other frame the intensity is slightly toggled,
    % regardless of whether the photobox is on or off
    oscillateEachFrame = true;
    
    frameEven = false;
    
    frameRepeater = 1; % 1 2 3 repeated sequence
  end
  
  properties(Constant)
    OFF = 0;
    ON = 1;
    
    FLASH_OFF = 0;
    FLASH_PENDING_DRAW = 1;
    FLASH_DRAWN = 2;
  end
  
  methods
    function pb = PhotoBox(cxt, photoboxId)
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
      
      pb = pb@Circle(xc, yc, rad);
      pb.photoboxId = photoboxId;
      
      pb.fill = true;
      pb.borderColor = border_color;
      pb.borderWidth = border_width;
      pb.hide();
      
      pb.status = pb.OFF;
      pb.flashStatus = pb.FLASH_OFF;
    end
    
    function str = describe(pb)
      str = sprintf('PhotoBox %d', pb.photoboxId);
    end
    
    function resetFrameRepeater(pb)
      pb.frameRepeater = 1; 
    end
    
    function on(pb)
      pb.status = pb.ON;
      pb.flashStatus = pb.FLASH_OFF;
      pb.resetFrameRepeater;
      pb.show();
    end
    
    function off(pb)
      % allow for frame by frame modulations too
      pb.status = pb.OFF;
      pb.flashStatus = pb.FLASH_OFF;
      pb.resetFrameRepeater;
      pb.show();
    end
    
    function toggle(pb)
      % allow for frame by frame modulations too
      if pb.status == pb.OFF
        pb.status = pb.ON;
      else
        pb.status = pb.OFF;
      end
      pb.flashStatus = pb.FLASH_OFF;
      pb.resetFrameRepeater;
      pb.show();
    end
    
    function flash(pb)
      pb.status = pb.ON;
      pb.flashStatus = pb.FLASH_PENDING_DRAW;
      pb.resetFrameRepeater;
      pb.show();
    end
    
    function update(pb, mgr, sd)
      if isempty(pb.fillColor)
        pb.fillColor = sd.white;
        if isempty(pb.borderColor)
          pb.borderColor = sd.white;
        end
      end
      
      update@Circle(pb, sd);
      
      if pb.flashStatus == pb.FLASH_DRAWN
        pb.status = pb.OFF;
        pb.flashStatus = pb.FLASH_OFF;
      end
      
      if pb.status == pb.ON
        if pb.frameRepeater == 1 || ~pb.oscillateEachFrame
          pb.fillColor = [1 1 1];
        elseif pb.frameRepeater == 2
          pb.fillColor = [0.9 0.9 0.9];
        else
          pb.fillColor = [0.7 0.7 0.7];
        end
      else
        if pb.frameRepeater == 1 || ~pb.oscillateEachFrame
          pb.fillColor = [0 0 0];
        elseif pb.frameRepeater == 2
          pb.fillColor = [0.25 0.25 0.25];
        else
          pb.fillColor = [0.4 0.4 0.4];
        end
      end
      
      %{
      if pb.status == pb.ON
        if pb.frameEven || ~pb.oscillateEachFrame
          pb.fillColor = [1 1 1];
        else
          pb.fillColor = [0.9 0.9 0.9];
        end
      else
        if pb.frameEven && pb.oscillateEachFrame
          pb.fillColor = [0.2 0.2 0.2];
        else
          pb.fillColor = [0 0 0];
        end
      end
      
      pb.frameEven = ~pb.frameEven;
      %}
      
      pb.frameRepeater = mod(pb.frameRepeater, 3) + 1; % 1 2 3 repeated sequence

      %fprintf('%g %g %g\n', pb.fillColor(1), pb.fillColor(2), pb.fillColor(3));
    end
    
    function draw(pb, sd)
      if pb.flashStatus == pb.FLASH_PENDING_DRAW
        pb.flashStatus = pb.FLASH_DRAWN;
      end
      draw@Circle(pb, sd);
    end
  end
  
end