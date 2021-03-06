function outSize = getSerializedBusLength_TestBusInner(bus)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   writeGetSerializedBusLengthModelPackagedCode('testDataLogger', 'TestBusInner')

    outSize = uint16(0);
    % element centerSize
    outSize = outSize + uint16(1); % bit flags
    outSize = outSize + uint16(1); % signal type
    outSize = outSize + uint16(1); % concatenation dimension
    outSize = outSize + uint16(2 + 10); % for name
    outSize = outSize + uint16(2 + 2); % for units
    outSize = outSize + uint16(1); % for data type id
    outSize = outSize + uint16(1 + 2*1); % for dimensions
    outSize = outSize + uint16(1 * numel(bus.centerSize)); % for centerSize data 

    % element holdWindowCenter
    outSize = outSize + uint16(1); % bit flags
    outSize = outSize + uint16(1); % signal type
    outSize = outSize + uint16(1); % concatenation dimension
    outSize = outSize + uint16(2 + 16); % for name
    outSize = outSize + uint16(2 + 2); % for units
    outSize = outSize + uint16(1); % for data type id
    outSize = outSize + uint16(1 + 2*1); % for dimensions
    outSize = outSize + uint16(1 * numel(bus.holdWindowCenter)); % for holdWindowCenter data 

    % element holdWindowTarget
    outSize = outSize + uint16(1); % bit flags
    outSize = outSize + uint16(1); % signal type
    outSize = outSize + uint16(1); % concatenation dimension
    outSize = outSize + uint16(2 + 16); % for name
    outSize = outSize + uint16(2 + 2); % for units
    outSize = outSize + uint16(1); % for data type id
    outSize = outSize + uint16(1 + 2*1); % for dimensions
    outSize = outSize + uint16(2 * numel(bus.holdWindowTarget)); % for holdWindowTarget data 


end