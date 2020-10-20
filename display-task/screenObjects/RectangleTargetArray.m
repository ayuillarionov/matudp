classdef RectangleTargetArray < ScreenTargetObjectArray
  %RECTANGLETARGETARRAY Array of RectangleTarget ScreenTargetObjects
  %   RectangleTargetArray is a ScreenObject itself but implemented
  %   similar to ScreenObjectManager.
  
  methods
    function obj = RectangleTargetArray(nTargets)
      if nargin < 1
        obj.targets = [];
      else
        obj = obj.createTargets(nTargets);
      end
    end
    
    function obj = createTargets(obj, n)
      for i = 1:n
        obj.add(RectangleTarget(NaN, NaN, NaN, NaN));
      end
    end
  end
end