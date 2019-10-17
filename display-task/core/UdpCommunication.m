classdef UdpCommunication < handle
  
  properties(SetAccess = protected) % access from class or subclasses
    rxIP       % local IP to receive on
    rxPort     % local port to receive on
    targetIP   % target IP to send on
    targetPort % target port to send on
  end
  
  properties(SetAccess = protected, Hidden)
    state
  end
  
  properties(Dependent)
    isOpen
  end
  
  properties(Constant, Hidden)
    PACKET_SIZE = 1600;
    STATE_CLOSED = 0;
    STATE_OPEN = 1;
  end
  
  methods
    function com = UdpCommunication(cxt)
      com.state = UdpCommunication.STATE_CLOSED;
      
      % extract network parameters from display context
      com.targetIP = cxt.networkTargetIP;
      com.targetPort = cxt.networkTargetPort;
      com.rxIP = cxt.networkReceiveIP;
      com.rxPort = cxt.networkReceivePort;
    end
    
    function tf = get.isOpen(com)
      tf = (com.state == UdpCommunication.STATE_OPEN);
    end
    
    function open(com)
      if com.isOpen
        return;
      end
      
      udpMexReceiver('start', sprintf('%s:%d', com.rxIP, com.rxPort), sprintf('%s:%d', com.targetIP, com.targetPort));
      com.state = UdpCommunication.STATE_OPEN;
    end
    
    function close(com)
      udpMexReceiver('stop');
      com.state = UdpCommunication.STATE_CLOSED;
    end
    
    function delete(com)
      com.close();
    end
    
    function writePacket(com, varargin)
      com.open();
      udpMexReceiver('send', varargin{:});
    end
    
    function groups = readGroups(com)
      com.open();
      groups = udpMexReceiver('retrieveGroups');
    end
  end
  
end