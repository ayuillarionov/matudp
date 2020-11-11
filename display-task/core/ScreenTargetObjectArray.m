classdef ScreenTargetObjectArray < ScreenObjectArray
  %SCREENTARGETOBJECTARRAY Array of ScreenTargetObjects
  %   implemented similar to ScreenObjectManager.
  
  methods % modified methods
    function add(obj, target)
      assert(isa(target, 'ScreenTargetObject') && isa(target, 'ScreenObject'), ...
        'Can only add objects derived from the classes ScreenTargetObject & ScreenObject');
      add@ScreenObjectArray(obj, target);
    end
  end
  
  methods % new methods
    function normal(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.normal, obj.objList);
      else
        arrayfun(@(t) t.normal, obj.objList(targetIdx));
      end
    end
    
    function setSuccessColor(obj, color, targetIdx)
      if isvector(color) && numel(color) == 3
        if ~exist('targetIdx','var') || isempty(targetIdx)
          for i = 1:length(obj.objList)
            obj.objList(i).successColor = color;
          end
        else
          for i = 1:length(targetIdx)
            obj.objList(targetIdx(i)).successColor = color;
          end
        end
      else
        error('==> Invalid color specification. Expected RGB triplet with the intensities in the range [0 1].');
      end
    end
    
    function contour(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.contour, obj.objList);
      else
        arrayfun(@(t) t.contour, obj.objList(targetIdx));
      end
    end
    
    function fillIn(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.fillIn, obj.objList);
      else
        arrayfun(@(t) t.fillIn, obj.objList(targetIdx));
      end
    end
    
    function setVibrateSigma(obj, sigma, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        [obj.objList.vibrateSigma] = deal(sigma);
      else
        for i = 1:length(targetIdx)
          obj.objList(targetIdx(i)).vibrateSigma = sigma;
        end
      end
    end
    
    function vibrate(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.vibrate, obj.objList);
      else
        arrayfun(@(t) t.vibrate, obj.objList(targetIdx));
      end
    end
    
    function stopVibrating(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.stopVibrating, obj.objList);
      else
        arrayfun(@(t) t.stopVibrating, obj.objList(targetIdx));
      end
    end
    
    function acquire(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.acquire, obj.objList);
      else
        arrayfun(@(t) t.acquire, obj.objList(targetIdx));
      end
    end
    
    function unacquire(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.unacquire, obj.objList);
      else
        arrayfun(@(t) t.unacquire, obj.objList(targetIdx));
      end
    end
    
    function success(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.success, obj.objList);
      else
        arrayfun(@(t) t.success, obj.objList(targetIdx));
      end
    end
    
    function failure(obj, targetIdx)
      if ~exist('targetIdx','var') || isempty(targetIdx)
        arrayfun(@(t) t.failure, obj.objList);
      else
        arrayfun(@(t) t.failure, obj.objList(targetIdx));
      end
    end
  end
  
end