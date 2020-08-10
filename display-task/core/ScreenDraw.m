classdef ScreenDraw < handle
  
  properties(SetAccess = protected) % access from class or subclasses
    si % ScreenInfo instance
  end
  
  properties
    penColor = [1 1 1];  % default white
    penWidth = 1;
    fillColor = [0 0 0]; % default black
    
    fontStyle = 0;
    fontSize = 24;
    fontFace = 'Ubuntu Mono'; % use a monospaced font to do wrapping well
    
    % cached size of single character, updated whenever .font* is set
    charSizeCached
    
    cursorVisible; % is the mouse cursor visible
    
    % The absolute value depends on the operating system,
    % e.g., seconds since system bootup on OS-X and Windows, seconds since
    % January 1973 00:00:00 GMT on Linux.
    % NOTE: internally executes GetSecs()
    flipTimeStamps = NaN(1,3); % [VBLTimestamp StimulusOnsetTime FlipTimestamp]
  end
  
  properties(Constant) % Subclasses inherit constant properties, but cannot change them.
    FontNormal = 0;
    FontBold = 1;
    FontItalic = 2;
    FontUnderline = 4;
    FontOutline = 8;
  end
  
  properties(Dependent)
    cs     % shortcut to si.coordSystem
    window % shortcut to si.window (windowPtr)
    
    xMin   % shortcut to si.uxMin (min x value in units of coordSystem)
    xMax   % shortcut to si.uxMax (max x value in units of coordSystem)
    
    xSignRight % if -1, right is decreasing numbers, 1 is increasing numbers
    
    yMin   % shortcut to si.uyMin (min y value in units of coordSystem)
    yMax   % shortcut to si.uyMax (min y value in units of coordSystem)
    
    ySignDown % if -1, down is decreasing numbers, 1 means increasing numbers
    
    uy1py  % 1 pixel height in units of y
    ux1px  % 1 pixel width  in units of x
    
    cMax   % shortcut to si.cMax (pixel value for white)
    cMin   % shortcut to si.cMin (pixel value for black)
    
    % derived from charSizeCached
    widthPerChar
    heightPerChar
  end
  
  properties(Constant) % Subclasses inherit constant properties, but cannot change them.
    % preset colors
    black      = [0 0 0];
    white      = [1 1 1];
    gray       = [0.5 0.5 0.5];
    red        = [1 0 0];
    green      = [0 1 0];
    blue       = [0 0 1];
    lightgreen = [0 0.5 0];
    yellow     = [1 1 0];
  end
  
  methods
    function sd = ScreenDraw(si)
      if nargin < 1 || ~isa(si, 'ScreenInfo')
        error('Usage: ScreenDraw(ScreenInfo si)');
      end
      sd.si = si;

      sd.penColor = sd.white;
      sd.penWidth = 3;
      sd.fillColor = sd.black;
      sd.cursorVisible = true;
    end
  end
  
  methods % Some wrappers around ScreenInfo's and PT methods for convenience
    function open(sd)
      sd.si.open();
    end
    
    function close(sd)
      sd.si.close();
    end
    
    function hideCursor(sd)
      HideCursor();
      sd.cursorVisible = false;
    end
    
    function showCursor(sd)
      ShowCursor();
      sd.cursorVisible = true;
    end
  end
  
  methods % drawing function signatures, see @ScreenDraw/ subdirectory
    function px = toPx(sd, ux)
      px = sd.cs.toPx(sd.si, ux);
    end
    
    function py = toPy(sd, uy)
      py = sd.cs.toPy(sd.si, uy);
    end
    
    function ux = toUx(sd, px)
      ux = sd.cs.toUx(sd.si, px);
    end
    
    function uy = toUy(sd, py)
      uy = sd.cs.toUy(sd.si, py);
    end
    
    function state = saveState(sd)
      state.penColor = sd.penColor;
      state.penWidth = sd.penWidth;
      state.fillColor = sd.fillColor;
      state.fontStyle = sd.fontStyle;
      state.fontSize = sd.fontSize;
      state.fontFace = sd.fontFace;
    end
    
    function restoreState(sd, state)
      sd.penColor = state.penColor;
      sd.penWidth = state.penWidth;
      sd.fillColor = state.fillColor;
      sd.fontStyle = state.fontStyle;
      sd.fontSize = state.fontSize;
      sd.fontFace = state.fontFace;
    end
    
    function color = convertColor(sd, value)
      % convert to RGBA color (red, green, blue, alpha opacity)
      if numel(value) == 1
        value = repmat(value, 1, 3);
      end
      
      if max(value) > 1 || min(value) < 0
        error('Colors must be in [0, 1]');
      end
      
      if numel(value) == 4
        color = [makerow(value(1:3))*(sd.cMax-sd.cMin) + sd.cMin, value(4)];
      elseif numel(value) == 3
        color = [makerow(value)*(sd.cMax-sd.cMin) + sd.cMin, 1]; % fully opaque
      else
        error('Colors must be 1, 3, or 4 vectors');
      end
    end
    
    function drawText(sd, str, ux, uy, wrapWidth, lineSpacing)
      % Draws a string of text 'str' into Psychtoolbox window 'window'.
      % 'px' defines the left border of the text
      % 'py' defines the baseline of the (first line of the) text
      % 'wrapWidth' will automatically break text strings longer than 'wrapWidth' characters
      %             into newline separated strings of roughly 'wrapWidth' characters
      % 'lineSpacing' sets the spacing between the lines (in Units, default is 1 pixel)
      
      flipHorizontal = ceil((1-sd.xSignRight)/2);
      flipVertical   = ceil((1-sd.ySignDown)/2);
      
      if exist('wrapWidth', 'var') && ~isempty(wrapWidth)
        if exist('lineSpacing', 'var')
          lineSpacingPx = ceil(lineSpacing / sd.uy1py); % in pixels
        else
          lineSpacingPx = sd.uy1py; % defaults is 1 pixel
        end
        
        % DrawFormattedText wants its vSpacing argument in units of line height
        % so we need to convert lineSpacingPx in pixels to line height units.
        % Also, lineSpacingPx = 0 means vSpacing = 1 line.
        pyPerChar = sd.heightPerChar / sd.uy1py;
        vSpacing = 1 + lineSpacingPx / pyPerChar;
        
        if sd.si.glTransformLevel > 0
          % reset an OpenGL matrix to its default identity setting
          Screen('glLoadIdentity', sd.window);
          % draw text
          DrawFormattedText(sd.window, str, sd.toPx(ux), sd.toPy(uy), sd.convertColor(sd.penColor), ...
            wrapWidth, 0, 0, vSpacing);
          % re-apply scaling and translation to align openGL coordinates with coordinate system.
          sd.cs.applyTransform(sd.si);
        else
          DrawFormattedText(sd.window, str, ux, uy, sd.convertColor(sd.penColor), ...
            wrapWidth, flipHorizontal, flipVertical, vSpacing);
        end
      else
        if sd.si.glTransformLevel > 0
          % reset an OpenGL matrix to its default identity setting
          Screen('glLoadIdentity', sd.window);
          % draw text
          DrawFormattedText(sd.window, str, sd.toPx(ux), sd.toPy(uy), sd.convertColor(sd.penColor), ...
            (sd.yMax-sd.yMin)/sd.uy1py);
          % re-apply scaling and translation to align openGL coordinates with coordinate system.
          sd.cs.applyTransform(sd.si);
        else
          DrawFormattedText(sd.window, str, ux, uy, sd.convertColor(sd.penColor), ...
            sd.yMax-sd.yMin, flipHorizontal, flipVertical);
        end
      end
        
    end
    
    function [ux, uy, numRows] = getTextSize(sd, str, wrapWidth, lineSpacing)
      % 'wrapWidth' will automatically break text strings longer than 'wrapWidth' characters
      %             into newline separated strings of roughly 'wrapWidth' characters
      % 'lineSpacing' sets the spacing between the lines (in Units, default is 1 pixel
      if ~exist('wrapWidth', 'var')
        wrapWidth = [];
      end
      if ~exist('lineSpacing', 'var')
        % default to 1 pixel
        lineSpacing = abs(sd.toUx(1) - sd.toUx(0));
      end
      
      uy = sd.heightPerChar;
      ux = sd.widthPerChar * length(str);
      
      if ~isempty(wrapWidth)
        % we're going to be wrapping this text, so rearrange the characters into multiple rows
        lineBreak = newline; % sprintf('\n')
        wrapped = WrapString(str, wrapWidth); %  Wraps text by changing spaces into linebreaks '\n'
        numRows = nnz(wrapped == lineBreak) + 1;
        ux = ux / numRows;
        uy = uy * numRows + lineSpacing*(numRows-1);
      else
        numRows = 1;
      end
    end
    
    %[] = drawLine(sd, x1, y1, x2, y2);
    function drawLine(sd, px1, py1, px2, py2)
      % convert into pixels
      %             px1 = sd.toPx(x1);
      %             px2 = sd.toPx(x2);
      %             py1 = sd.toPy(y1);
      %             py2 = sd.toPy(y2);
      
      % Screen('DrawLine', windowPtr [,color], fromH, fromV, toH, toV [,penWidth]);
      Screen('DrawLine', sd.window, sd.convertColor(sd.penColor), px1, py1, px2, py2, sd.penWidth);
    end
    
    function drawRect(sd, px1, py1, px2, py2, filled)
      % convert into pixels
      %      px = sd.toPx([x1 x2]);
      %      py = sd.toPy([y1 y2]);
      %      px = sd.toPx([px1 px2]);
      %      py = sd.toPy([py1 py2]);
      px = [px1 px2];
      py = [py1 py2];
      
      rect = [min(px) min(py) max(px) max(py)];
      if filled
        Screen('FillRect', sd.window, sd.convertColor(sd.fillColor), rect);
      end
      
      Screen('FrameRect', sd.window, sd.convertColor(sd.penColor), rect, sd.penWidth);
    end
    
    function drawOval(sd, x1, y1, x2, y2, filled)
      % convert into pixels
      %             px = sd.toPx([x1 x2]);
      %             py = sd.toPy([y1 y2]);
      px = [x1 x2];
      py = [y1 y2];
      
      rect = [min(px) min(py) max(px) max(py)];
      
      if filled
        Screen('FillOval', sd.window, sd.convertColor(sd.fillColor), rect);
      end
      if sd.penWidth > 0
        Screen('FrameOval', sd.window, sd.convertColor(sd.penColor), rect, sd.penWidth);
      end
    end
    
    function drawCircle(sd, xc, yc, r, filled)
      if nargin < 5
        filled = false;
      end
      
      % convert into pixels
      px = [xc-r xc+r];
      py = [yc-r yc+r];
      
      rect = [min(px) min(py) max(px) max(py)];
      if filled
        Screen('FillOval', sd.window, sd.convertColor(sd.fillColor), rect);
      end
      
      if sd.penWidth > 0
        Screen('FrameOval', sd.window, sd.convertColor(sd.penColor), rect, sd.penWidth);
      end
    end
    
    % drawGrid(sd, spacing, xc, yc, xLim, yLim);
    function drawGrid(sd, spacing, xc, yc, xLim, yLim)
      % help for drawGrid
      
      if ~isstruct(spacing)
        if length(spacing) == 1
          s = spacing;
          clear spacing;
          spacing.x = s;
          spacing.y = s;
        else
          s = spacing;
          clear spacing;
          spacing.x = s(1);
          spacing.y = s(2);
        end
      end
      
      if ~exist('xc', 'var')
        xc = 0;
      end
      if ~exist('yc', 'var')
        yc = 0;
      end
      if ~exist('xLim', 'var')
        xLim = [sd.xMin sd.xMax]; % full screen
      end
      if ~exist('yLim', 'var')
        yLim = [sd.yMin sd.yMax]; % full screen
      end
      
      for x = union(xc : -spacing.x : xLim(1), xc : spacing.x : xLim(2))
        sd.drawLine(x, yLim(1), x, yLim(2));
      end
      
      for y = union(yc : -spacing.y : yLim(1), yc : spacing.y : yLim(2))
        sd.drawLine(xLim(1), y, xLim(2), y);
      end
      
    end
    
    % drawCross(sd, xc, yc, width, height);
    function drawCross(sd, xc, yc, width, height)
      sd.drawLine(xc-width/2, yc, xc+width/2, yc);
      sd.drawLine(xc, yc-height/2, xc, yc+height/2);
    end
    
    function drawPoly(sd, px, py)
      %             px = makerow(sd.toPx(xpts));
      %             py = makerow(sd.toPy(ypts));
      
      px = makerow(px);
      py = makerow(py);
      
      nPts = numel(px);
      pts = nan(2, nPts*2);
      pts(1, 1:2:end) = px;
      pts(2, 1:2:end) = py;
      pts(1, 2:2:end) = [px(2:end) px(1)];
      pts(2, 2:2:end) = [py(2:end) py(1)];
      
      %Screen('FramePoly', sd.window, sd.penColor, [px py], sd.penWidth);
      Screen('DrawLines', sd.window, pts, sd.penWidth, repmat(makecol(sd.convertColor(sd.penColor)), 1, size(pts, 2)), [0 0], 1);
    end
    
    % query mouse position (in user units) and button status
    function [mouseX, mouseY, buttons] = getMouse(sd)
      [px, py, buttons] = GetMouse(sd.window);
      mouseX = sd.toUx(px);
      mouseY = sd.toUy(py);
    end
    
    function drawTexture(sd, textureIndex, rect, angle, filterMode, globalAlpha, modulateColor)
      % texturePointer - specifies OpenGL texture
      % rect           - rectangular subpart of the window where the texture should be drawn
      % angle          - specifies a rotation angle in radians for rotated drawing of the texture
      %  (Defaults to 0 deg. = upright)
      % filterMode     - pixel color values when the texture is drawn magnified, minified
      %  or drawn shifted: see Screen DrawTexture?
      % globalAlpha    - global alpha transparency value for blending:
      %  0 = fully transparent to 1 = fully opaque
      % modulateColor  - global color that gets applied to the texture as a whole.
      % NOTE: If 'modulateColor' is specified, the 'globalAlpha' value will be ignored.
      
      x1 = rect(1);
      y1 = rect(2);
      x2 = rect(3);
      y2 = rect(4);
      
      if nargin < 4
        angle = 0;
      end
      if nargin < 5 || isempty(filterMode)
        filterMode = 1;
      end
      if nargin < 6
        globalAlpha = 1;
      end
      if nargin < 7
        modulateColor = [];
      end
      
      %             px = sd.toPx([x1 x2]);
      %             py = sd.toPy([y1 y2]);
      px = [x1 x2];
      py = [y1 y2];
      
      rect = [min(px) min(py) max(px) max(py)];
      % Make a texture from this image
      % convert angle provided in radians to degrees
      Screen('DrawTexture', sd.window, textureIndex, [], rect, angle*180/pi, ...
        filterMode, globalAlpha, modulateColor);
    end
    
    function textureIndex = makeTexture(sd, img)
      % Make a texture from this image
      %if size(img, 3) == 3
      %    img(:,:, 3) = 255*ones(size(img, 1), size(img, 2));
      %else
      %    img(:,:, 4) = 255*img(:,:,4);
      %end
      
      % needs float precision
      floatprecision = 2; % 0 - 8 bit per color component precision, 1 - 16 bit, 2 - 32 bit
      %try
      textureIndex = Screen('MakeTexture', sd.window, img, [], [], floatprecision);
      %catch
      %    textureIndex = Screen('MakeTexture', sd.window, img, [], [], 0);
      %end
    end
    
    function clearTexture(sd, textureIndex)
      Screen('CScreelose', textureIndex);
    end
    
  end
  
  methods
    function [VBL, StOnset, flipTime] = flip(sd)
      % Flip front and back display surfaces in sync with vertical retrace and return completion timestamps.
      
      when = 0; % flip on the next possible video retrace
      dontclear = 0; % clear the framebuffer to background color after each flip
      dontsync = 0; % =1 --- *NOT* wait for the flip to happen (NOTE: all returned timestamps are invalid!)
      [VBL, StOnset, flipTime] = Screen('Flip', sd.window, when, dontclear, dontsync);
      
      % VBL      - the system time (in seconds) when the actual flip has happened
      % StOnset  - an estimate of Stimulus-onset time
      % flipTime - a timestamp taken at the end of Flip's execution
      sd.flipTimeStamps = [VBL, StOnset, flipTime];
    end
    
    function fill(sd, color)
      Screen('FillRect', sd.window, sd.convertColor(color));
    end
    
    function fillBlack(sd)
      sd.fill(sd.black);
    end
    
    function fillGray(sd)
      sd.fill(sd.gray);
    end
  end
  
  methods % shortcut accessors
    function window = get.window(sd)
      window = sd.si.window;
    end
    
    function penColor = get.penColor(sd) % RGBA
      if isempty(sd.penColor)
        penColor = sd.white;
      elseif numel(sd.penColor) == 3
        penColor = [makerow(sd.penColor), 1]; % fully opaque
      else
        penColor = makerow(sd.penColor);
      end
    end
    
    function cs = get.cs(sd)
      cs = sd.si.cs;
    end
    
    function cMax = get.cMax(sd)
      cMax = sd.si.cMax;
    end
    
    function cMin = get.cMin(sd)
      cMin = sd.si.cMin;
    end
    
    function xMin = get.xMin(sd)
      xMin = sd.si.uxMin;
    end
    
    function xMax = get.xMax(sd)
      xMax = sd.si.uxMax;
    end
    
    function xSignRight = get.xSignRight(sd)
      xSignRight = sd.si.uxSignRight;
    end
    
    function yMin = get.yMin(sd)
      yMin = sd.si.uyMin;
    end
    
    function yMax = get.yMax(sd)
      yMax = sd.si.uyMax;
    end
    
    function ySignDown = get.ySignDown(sd)
      ySignDown = sd.si.uySignDown;
    end
    
    function uy1py = get.uy1py(sd)
      uy1py = abs(sd.toUy(1) - sd.toUy(0));
    end
    
    function ux1px = get.ux1px(sd)
      ux1px = abs(sd.toUx(1) - sd.toUx(0));
    end
    
    % changing the font settings automatically updates the size of a character properties
    function set.fontFace(sd, name)
      sd.fontFace = name;
      Screen('TextFont', sd.window, name);
      sd.charSizeCached = [];
    end
    
    function set.fontSize(sd, val)
      sd.fontSize = val;
      Screen('TextSize', sd.window, val);
      sd.charSizeCached = [];
    end
    
    function set.fontStyle(sd, val)
      % 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend
      sd.fontStyle = val;
      %Screen('TextStyle', sd.window, val);
      sd.charSizeCached = [];
    end
    
    function calculateCharSize(sd)
      % set height and width per character with the given font settings
      h = abs(sd.toUy(sd.fontSize) - sd.toUy(0));
      
      rect = Screen('TextBounds', sd.window, '_'); % size of the text in units of pixels
      w = abs(sd.toUx(rect(3)) - sd.toUx(rect(1)));
      sd.charSizeCached = [w h];
    end
    
    function width = get.widthPerChar(sd)
      if isempty(sd.charSizeCached)
        sd.calculateCharSize();
      end
      width = sd.charSizeCached(1);
    end
    
    function height = get.heightPerChar(sd)
      if isempty(sd.charSizeCached)
        sd.calculateCharSize();
      end
      height = sd.charSizeCached(2);
    end
  end
  
end