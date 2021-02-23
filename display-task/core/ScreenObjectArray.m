classdef ScreenObjectArray < ScreenObject
%SCREENOBJECTARRAY Array of ScreenObjects
%   implemented similar to ScreenObjectManager.
  
  properties
    objList; % list of ScreenObjects, automatically filtered to delete invalid objects
  end
  
  properties(Dependent)
    sortedObjList % list of ScreenObjects in objList, sorted by ascending zOrder
  end
  
  methods % extend ScreenObject methods
    function show(obj, objIdx)
      if ~exist('objIdx','var') || isempty(objIdx)
        obj.showObjList();
      else
        obj.showObjList(objIdx);
      end
      show@ScreenObject(obj);
    end
    
    function hide(obj, objIdx)
      if ~exist('objIdx','var') || isempty(objIdx)
        obj.hideObjList();
        hide@ScreenObject(obj);
      else
        obj.hideObjList(objIdx);
      end
    end
  end
  
  methods
    function add(obj, sObj)
      assert(isa(sObj, 'ScreenObject'), ...
        'Can only add objects derived from the ScreenObject class');
      obj.objList = [obj.objList, sObj];
    end
    
    function remove(obj, sobj)
      obj.objList = obj.objList(~isequal(obj.objList, sobj));
    end
    
    function flush(obj)
      obj.objList = [];
    end
    
    function list = get.objList(obj)
      if isempty(obj.objList)
        list = [];
      else
        % filter only the valid objects in the objects list
        list = obj.objList(isvalid(obj.objList));
        obj.objList = list;
      end
    end
    
    function list = get.sortedObjList(obj)
      if isempty(obj.objList)
        list = [];
        return;
      end
      
      zOrderList = [obj.objList.zOrder];
      [~, sortIdx] = sort(zOrderList);
      
      list = obj.objList(sortIdx);
    end
    
    % a one-line string used to concisely describe this object
    function str = describe(obj)
      if isempty(obj.objList)
        str = sprintf('Empty %s.', class(obj));
        return;
      end
      
      nObjs = length(obj.objList);
      str = sprintf('%s with %g ScreenObjects:', class(obj), nObjs);
      for i = 1:nObjs
        str = [str, newline, int2str(i), '. ', obj.objList(i).describe]; %#ok<AGROW>
      end
    end
    
    % update the object, mgr is a ScreenObjectManager
    % can be used to add or remove objects from the manager as well
    function update(obj, mgr, sd)
      %arrayfun(@(t) t.update(mgr, sd), obj.objList); NOTE: for loop is faster on CPU
      
      list = obj.objList;
      for i = 1:length(list)
        list(i).update(mgr, sd);
      end
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(obj, sd)
      %arrayfun(@(t) t.draw(sd), obj.objList([obj.objList.visible])); % NOTE: for loop is faster on CPU
      
      % sort by z order and then draw if visible
      list = obj.objList;
      if isempty(list)
        return;
      end
 
      list = list([list.visible]);
      for i = 1:length(list)
        list(i).draw(sd);
      end
    end
  end
  
  methods
    function showObjList(obj, objIdx)
      obj.visible = true; % ScreenObjectArray is visible now
      if ~exist('objIdx','var') || isempty(objIdx)
        arrayfun(@(t) t.show, obj.objList);
      else
        arrayfun(@(t) t.show, obj.objList(objIdx));
      end
    end
    
    function hideObjList(obj, objIdx)
      if ~exist('objIdx','var') || isempty(objIdx)
        arrayfun(@(t) t.hide, obj.objList);
        obj.visible = false; % ScreenObjectArray is hidden now
      else
        arrayfun(@(t) t.hide, obj.objList(objIdx));
      end
    end
    
    function setColor(obj, color, objIdx)
      if isvector(color) && numel(color) == 3
        if ~exist('objIdx','var') || isempty(objIdx)
          [obj.objList.color] = deal(color);
        else
          for i = 1:length(objIdx)
            obj.objList(objIdx(i)).color = color;
          end
        end
      else
        error('==> Invalid color specification. Expected RGB triplet with the intensities in the range [0 1].');
      end
    end
  end
  
  methods(Access = private, Hidden)
    function arrayfunc(obj, func, objIdx)
      if ~exist('objIdx','var') || isempty(objIdx)
        arrayfun(@(t) func(t), obj.objList);
      else
        arrayfun(@(t) func(t), obj.objList(objIdx));
      end
    end
    
  end
end