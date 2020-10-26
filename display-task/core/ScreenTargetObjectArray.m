classdef ScreenTargetObjectArray < ScreenObject
  %SCREENTARGETOBJECTARRAY Array of ScreenTargetObjects
  %   implemented similar to ScreenObjectManager.
  
  properties
    targets; % list of RectangleTargets in targets, automatically filtered to delete invalid objects
  end
  
  properties(Dependent)
    sortedTargets % list of RectangleTargets in targets, sorted by ascending zOrder
  end
  
  methods % extend ScreenObject methods
      function show(obj)
          obj.showTargets();
          show@ScreenObject(obj);
      end
      
      function hide(obj)
          obj.hideTargets();
          hide@ScreenObject(obj);
      end
  end
  
  methods
    function add(obj, target)
      assert(isa(target, 'ScreenTargetObject') && isa(target, 'ScreenObject'), ...
        'Can only add objects derived from the classes ScreenTargetObject & ScreenObject');
      obj.targets = [obj.targets, target];
    end
    
    function remove(obj, target)
      obj.targets = obj.targets(~isequal(obj.targets, target));
    end
    
    function flush(obj)
      obj.targets = [];
    end
    
    function targets = get.targets(obj)
      if isempty(obj.targets)
        targets = [];
      else
        % filter only the valid objects in the target's list
        targets = obj.targets(isvalid(obj.targets));
        obj.targets = targets;
      end
    end
    
    function targets = get.sortedTargets(obj)
      if isempty(obj.targets)
        targets = [];
        return;
      end
      
      zOrderList = [obj.targets.zOrder];
      [~, sortIdx] = sort(zOrderList);

      targets = obj.targets(sortIdx);
    end
    
    % a one-line string used to concisely describe this object
    function str = describe(obj)
      if isempty(obj.targets)
        str = sprintf('Empty %s.', class(obj));
        return;
      end
      
      nTarget = length(obj.targets);
      str = sprintf('%s with %g targets:', class(obj), nTarget);
      for i = 1:nTarget
        str = [str, newline, int2str(i), '. ', obj.targets(i).describe]; %#ok<AGROW>
      end
    end
    
    % update the object, mgr is a ScreenObjectManager
    % can be used to add or remove objects from the manager as well
    function update(obj, mgr, sd)
      targets = obj.targets; %#ok<*PROPLC>
      for i = 1:length(targets)
        targets(i).update(mgr, sd);
      end
    end
    
    % use the ScreenDraw object to draw this object onto the screen
    function draw(obj, sd)
      % sort by z order and then draw if visible
      targets = obj.targets;
      if isempty(targets)
        return;
      end
      targets = targets([targets.visible]);
      for i = 1:length(targets)
        targets(i).draw(sd);
      end
    end
  end
  
  methods
      function showTargets(obj, targetIdx)
          if ~exist('targetIdx','var') || isempty(targetIdx)
              arrayfun(@(t) t.show, obj.targets);
          else
              arrayfun(@(t) t.show, obj.targets(targetIdx));
          end
      end
      
      function hideTargets(obj, targetIdx)
          if ~exist('targetIdx','var') || isempty(targetIdx)
              arrayfun(@(t) t.hide, obj.targets);
          else
              arrayfun(@(t) t.hide, obj.targets(targetIdx));
          end
      end
    
    function normal(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.normal, obj.targets);
      else
        arrayfun(@(t) t.normal, obj.targets(targetIdx));
      end
    end
    
    function setSuccessColor(obj, color, targetIdx)
      if isvector(color) && numel(color) == 3
        if ~exist('targetIdx','var') || isempty(targetIdx)
          for i = 1:length(obj.targets)
            obj.targets(i).successColor = color;
          end
        else
          for i = 1:length(targetIdx)
            obj.targets(targetIdx(i)).successColor = color;
          end
        end
      else
        error('==> Invalid color specification. Expected RGB triplet with the intensities in the range [0 1].');
      end
    end
    
    function contour(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.contour, obj.targets);
      else
        arrayfun(@(t) t.contour, obj.targets(targetIdx));
      end
    end
    
    function fillIn(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.fillIn, obj.targets);
      else
        arrayfun(@(t) t.fillIn, obj.targets(targetIdx));
      end
    end
    
    function setVibrateSigma(obj, sigma, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        for i = 1:length(obj.targets)
          obj.targets(i).vibrateSigma = sigma;
        end
      else
        for i = 1:length(targetIdx)
          obj.targets(targetIdx(i)).vibrateSigma = sigma;
        end
      end
    end
    
    function vibrate(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.vibrate, obj.targets);
      else
        arrayfun(@(t) t.vibrate, obj.targets(targetIdx));
      end
    end
    
    function stopVibrating(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.stopVibrating, obj.targets);
      else
        arrayfun(@(t) t.stopVibrating, obj.targets(targetIdx));
      end
    end
    
    function acquire(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.acquire, obj.targets);
      else
        arrayfun(@(t) t.acquire, obj.targets(targetIdx));
      end
    end
    
    function unacquire(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.unacquire, obj.targets);
      else
        arrayfun(@(t) t.unacquire, obj.targets(targetIdx));
      end
    end
    
    function success(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.success, obj.targets);
      else
        arrayfun(@(t) t.success, obj.targets(targetIdx));
      end
    end
    
    function failure(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.failure, obj.targets);
      else
        arrayfun(@(t) t.failure, obj.targets(targetIdx));
      end
    end
  end
  
  methods(Access = private, Hidden)
    function arrayfunc(obj, func, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) func(t), obj.targets);
      else
        arrayfun(@(t) func(t), obj.targets(targetIdx));
      end
    end
    
  end
end