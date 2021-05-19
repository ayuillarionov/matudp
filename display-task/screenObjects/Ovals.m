classdef Ovals < ScreenObjectArray
%OVALS Array of Oval ScreenObjects.
  
  methods
    function add(obj, sObj)
      assert(isa(sObj, 'Oval'), ...
        'Can only add objects derived from the Oval/Circle class');
      add@ScreenObjectArray(obj, sObj);
    end
    
    % a one-line string used to concisely describe this object
    function str = describe(obj)
      if isempty(obj.objList)
        str = sprintf('Empty %s class instance.', class(obj));
        return;
      end
      
      nObjs = length(obj.objList);
      str = sprintf('%s class instance with %g Ovals/Circles:', class(obj), nObjs);
      for i = 1:nObjs
        str = [str, newline, int2str(obj.idxList(i)), '. ', obj.objList(i).describe]; %#ok<AGROW>
      end
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(obj, sd)
      % sort by z order and then draw if visible
      list = obj.objList;
      if isempty(list)
        return;
      end
      list = list([list.visible]);
      
      % draw filled ovals if any
      listFilled = list([list.fill]);
      nFilledOvals = numel(listFilled);
      if nFilledOvals
        fillColor = repmat(makecol(sd.convertColor(sd.fillColor)), 1, nFilledOvals);
        for i = 1:nFilledOvals
          if ~isempty(listFilled(i).fillColor)
            fillColor(:, i) = makecol(sd.convertColor(listFilled(i).fillColor));
          end
        end
        
        rect = [[listFilled.x1]; [listFilled.y1]; [listFilled.x2]; [listFilled.y2]];
        perfectUpToMaxDiameter = max([[listFilled.width], [listFilled.height]]) * 1.01;
        
        Screen('FillOval', sd.window, fillColor, rect, perfectUpToMaxDiameter);
      end
      
      % draw frame around ovals if any borderWidth ~= 0
      listFramed = list(logical([list.borderWidth]));
      nFramedOvals = numel(listFramed);
      if nFramedOvals
        penColor = repmat(makecol(sd.convertColor(sd.penColor)), 1, nFramedOvals);
        penWidth = sd.penWidth * ones(1, nFramedOvals);
        for i = 1:nFramedOvals
          if ~isempty(listFramed(i).borderColor)
            penColor(:, i) = makecol(sd.convertColor(listFramed(i).borderColor));
          end
          penWidth(i) = listFramed(i).borderWidth;
        end
        
        rect = [[listFramed.x1]; [listFramed.y1]; [listFramed.x2]; [listFramed.y2]];
      
        Screen('FrameOval', sd.window, penColor, rect, penWidth);
      end
    end
  end
  
end