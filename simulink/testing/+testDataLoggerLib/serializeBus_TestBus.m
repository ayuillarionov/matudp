function [out, valid] = serializeBus_TestBus(bus)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   BusSerialize.writeSerializeBusModelPackagedCode('testDataLogger', 'TestBus')

    valid = uint8(0);
    coder.varsize('out', 6491);
    outSize = testDataLoggerLib.getSerializedBusLength_TestBus(bus);
    out = zeros(outSize, 1, 'uint8');
    offset = uint16(1);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize variable-sized centerSize
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % centerSize bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);

    % centerSize signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(4);
    offset = offset + uint16(1);

    % centerSize concatenation dimension
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % centerSize bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(1);

    % centerSize name
    if(offset+uint16(2+10 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(10), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(10-1))) = uint8('centerSize');
    offset = offset + uint16(10);

    % centerSize units
    if(offset+uint16(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(2-1))) = uint8('mm');
    offset = offset + uint16(2);

    % centerSize data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(3); % data type is uint8
    offset = offset + uint16(1);

    % centerSize dimensions
    if(offset > numel(out)), return, end
    if(offset+uint16(1+2*2-1) > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*2-1))) = typecast(uint16(size(bus.centerSize)), 'uint8');
    offset = offset + uint16(2*2);

    % centerSize data
    nBytes = uint16(1 * size(bus.centerSize, 1) * size(bus.centerSize, 2));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.centerSize) || islogical(bus.centerSize)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.centerSize(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.centerSize(:), 'uint8');
    end
    offset = offset + nBytes;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize fixed-sized holdWindowCenter
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % holdWindowCenter bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % holdWindowCenter signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(4);
    offset = offset + uint16(1);

    % holdWindowCenter concatenation dimension
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % holdWindowCenter bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);

    % holdWindowCenter name
    if(offset+uint16(2+16 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(16), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(16-1))) = uint8('holdWindowCenter');
    offset = offset + uint16(16);

    % holdWindowCenter units
    if(offset+uint16(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(2-1))) = uint8('mm');
    offset = offset + uint16(2);

    % holdWindowCenter data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(3); % data type is uint8
    offset = offset + uint16(1);

    % holdWindowCenter dimensions
    if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.holdWindowCenter)), 'uint8');
    offset = offset + uint16(2*1);

    % holdWindowCenter data
    nBytes = uint16(1 * numel(bus.holdWindowCenter));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.holdWindowCenter) || islogical(bus.holdWindowCenter)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.holdWindowCenter(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.holdWindowCenter(:), 'uint8');
    end
    offset = offset + nBytes;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize variable-sized holdWindowTarget
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % holdWindowTarget bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);

    % holdWindowTarget signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(4);
    offset = offset + uint16(1);

    % holdWindowTarget concatenation dimension
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % holdWindowTarget bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(1);

    % holdWindowTarget name
    if(offset+uint16(2+16 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(16), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(16-1))) = uint8('holdWindowTarget');
    offset = offset + uint16(16);

    % holdWindowTarget units
    if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('char');
    offset = offset + uint16(4);

    % holdWindowTarget data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(8); % data type is char
    offset = offset + uint16(1);

    % holdWindowTarget dimensions
    if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.holdWindowTarget)), 'uint8');
    offset = offset + uint16(2*1);

    % holdWindowTarget data
    nBytes = uint16(1 * numel(bus.holdWindowTarget));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.holdWindowTarget) || islogical(bus.holdWindowTarget)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.holdWindowTarget(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.holdWindowTarget(:), 'uint8');
    end
    offset = offset + nBytes; %#ok<NASGU>

    valid = uint8(1);
end