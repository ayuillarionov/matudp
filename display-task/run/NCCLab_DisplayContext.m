classdef NCCLab_DisplayContext < DisplayContext
  
  methods
    function cxt = NCCLab_DisplayContext()
      cxt.name = 'NCCLab-displayPC';
      
      cxt.cs = ShiftScaleCoordSystem.buildCenteredForScreenSize(1); % default in mm
      
      % --- network communication with xPC Target
      % 1. broadcast UDP to the target (receiveAtIP on xpcDisplay)
      %cxt.networkTargetIP = '127.0.0.1'; % to the localhost for testing
      cxt.networkTargetIP = '100.1.1.3';
      % 2. (receivePort on xpcDisplay Target)
      cxt.networkTargetPort = 10001;
      % 3. receive UDP from broadcast (destIP on xpcDisplay Target)
      cxt.networkReceiveIP = '100.1.1.2';
      % 4. must match whatever the send UDP block on the target is set to
      % (destPort on xpcDisplay Target)
      cxt.networkReceivePort = 25001;
      
      % --- photobox position on the screen (external diameter is 17.8mm, internal is 13mm)
      cxt.photoboxPositions.xc = -253.1;
      cxt.photoboxPositions.yc = 137.1;
      cxt.photoboxPositions.radius = 8.9;
    end
  end
  
end