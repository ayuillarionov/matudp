classdef ScreenLog < ScreenObject
  
  properties
    x
    y
    width
    height
    
    titleStr              % log title
    titleColor            % color of the title
    titleHeight
    titleSpacing = 0;     % spacing below title before first entry
    
    respectHeight = true; % if true, only shows last N lines which fit in .height;
                          % if false, shows all lines regardless of height
    respectWidth = false; % if true, text is wrapped, otherwise all entries on one line
    
    data
    % .message : text
    % .color : color to display it in
    % .indent : number of indents to add
    % .height : uY this (wrapped) text occupies
    
    fontFace = 'Ubuntu Mono' % use a monospaced font to do wrapping well
    fontSize = 24;
    fontStyle = 0;

    wrapWidth            % number of characters per line
    entrySpacing = 0;    % vertical gap between entries in data
    wrapLineSpacing = 0; % vertical gap for wrapped lines
  end
  
  methods
    function r = ScreenLog(x, y, width, height, titleStr)
      r.x = x;
      r.y = y;
      r.width = width;
      r.height = height;
      r.titleStr = titleStr;
      r.flush();
    end
    
    function str = describe(r)
      str = sprintf('%s: %s (%g + %g, %g + %g)', ...
        class(r), r.titleStr, r.x, r.width, r.y, r.height);
    end
    
    function flush(r)
      r.data = struct('message', {}, 'color', {}, 'indent', {}, 'height', {});
    end

    function add(r, message, indent, color)
      if ~exist('color', 'var')
        color = [];
      end
      if ~exist('indent', 'var')
        indent = 0;
      end
      
      newData.message = message;
      newData.color = color;
      newData.indent = indent;
      newData.height = []; % leave this blank until update is called
      
      r.data(end+1) = newData;
    end
    
    function update(r, mgr, sd) %#ok<INUSL>
      % setup the font appropriately, cache the old font info
      state = sd.saveState();
      sd.fontFace = r.fontFace;
      sd.fontStyle = r.fontStyle;
      sd.fontSize = r.fontSize;
      
      % if we haven't done this already, calculate the width per character
      % so that we know how many characters wide we should make the log
      if isempty(r.wrapWidth)
        r.wrapWidth = floor(r.width / sd.widthPerChar);
      end
      
      % figure out the height of the title
      if isempty(r.titleHeight)
        [ux, r.titleHeight] = sd.getTextSize(r.titleStr, r.wrapWidth, r.wrapLineSpacing);
      end
      
      % comb through the data entered and check that all the heights are calculated,
      % or calculate them if necessary
      for i = 1:length(r.data)
        if isempty(r.data(i).height)
          [ux, r.data(i).height] = sd.getTextSize(r.data(i).message, r.wrapWidth, r.wrapLineSpacing);
        end
      end
      
      % delete lines to fit within height if asked
      if r.respectHeight
        % keep only the last few lines which fit inside the buffer
        heightRevOrder = fliplr([r.data.height] + r.entrySpacing);
        cumHeightRevOrder = fliplr(cumsum(heightRevOrder));
        lastEntryWhichFits = find(cumHeightRevOrder <= r.height, 1, 'first');
        if isempty(lastEntryWhichFits) && ~isempty(r.data)
          % never throw away the last line, even if it doesn't fit
          lastEntryWhichFits = length(r.data);
        end
        r.data = r.data(lastEntryWhichFits:end);
      end
      
      sd.restoreState(state);
    end
    
    function draw(r, sd)
      % setup the font appropriately, cache the old font info
      state = sd.saveState();
      sd.fontFace = r.fontFace;
      sd.fontStyle = r.fontStyle;
      sd.fontSize = r.fontSize;
      
      y = r.y;
      x = r.x;
      
      % draw the title, skip the appropriate amount of y space
      if isempty(r.titleColor)
        r.titleColor = sd.white;
      end
      sd.penColor = r.titleColor;
      sd.fontStyle = bitor(sd.FontBold, sd.FontUnderline); % Bit-wise OR
      
      sd.drawText(r.titleStr, x, y, r.wrapWidth, r.wrapLineSpacing);
      y = y + sd.ySignDown*(r.titleHeight + r.titleSpacing);
      
      % draw each entry, skippng space in between
      sd.fontStyle = sd.FontNormal;
      for i = 1:length(r.data)
        if isempty(r.data(i).color)
          sd.penColor = sd.gray;
        else
          sd.penColor = r.data(i).color;
        end
        
        if isempty(r.data(i).indent)
          xOffset = 0;
          wrapWidth = r.wrapWidth;
        else
          xOffset = sd.widthPerChar * 4 * r.data(i).indent;
          wrapWidth = r.wrapWidth - 4 * r.data(i).indent;
        end
        
        sd.drawText(r.data(i).message, x+xOffset, y, wrapWidth, r.wrapLineSpacing);
        y = y + sd.ySignDown*(r.data(i).height + r.entrySpacing);
      end
      % restore old font info
      sd.restoreState(state);
    end
    
  end
  
end