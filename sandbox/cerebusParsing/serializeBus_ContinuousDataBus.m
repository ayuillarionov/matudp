function [out, valid] = serializeBus_ContinuousDataBus(bus)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   BusSerialize.writeSerializeBusCode('ContinuousDataBus')

    if nargin < 5, namePrefix = uint8(''); end
    namePrefixBytes = uint8(namePrefix(:))';
    valid = uint8(0);
    coder.varsize('out', 61739);
    outSize = getSerializedBusLength_ContinuousDataBus(bus, namePrefix);
    out = zeros(outSize, 1, 'uint8');
    offset = uint32(1);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize variable-sized continuousTimeOffsets
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Check input size is valid
    assert(numel(bus.continuousTimeOffsets) <= 60, 'numel(bus.continuousTimeOffsets) exceeds max size of 60');    % continuousTimeOffsets bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(3);
    offset = offset + uint32(1);

    % continuousTimeOffsets signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint32(1);

    % continuousTimeOffsets name with prefix 
    if(offset+uint32(2+21 -1) > numel(out)), return, end
    out(offset:(offset+uint32(1))) = typecast(uint16(numel(namePrefixBytes) + 21), 'uint8');
    offset = offset + uint32(2);
    out(offset:(offset+uint32(numel(namePrefixBytes) + 21-1))) = [namePrefixBytes, uint8('continuousTimeOffsets')];
    offset = offset + uint32(numel(namePrefixBytes) + 21);

    % continuousTimeOffsets units
    if(offset+uint32(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint32(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint32(2);
    out(offset:(offset+uint32(2-1))) = uint8('ms');
    offset = offset + uint32(2);

    % continuousTimeOffsets data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(1); % data type is single
    offset = offset + uint32(1);

    % continuousTimeOffsets dimensions
    if(offset > numel(out)), return, end
    if(offset+uint32(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint32(1);
    out(offset:(offset+uint32(2*1-1))) = typecast(uint16(numel(bus.continuousTimeOffsets)), 'uint8');
    offset = offset + uint32(2*1);

    % continuousTimeOffsets data
    nBytes = uint32(4 * numel(bus.continuousTimeOffsets));
    if nBytes > uint32(0)
        if(offset+uint32(nBytes-1) > numel(out)), return, end
        out(offset:(offset+uint32(nBytes-1))) = typecast(single(bus.continuousTimeOffsets(:))', 'uint8')';
    end
    offset = offset + nBytes;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize variable-sized continuousData
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Check input size is valid
    assert(ndims(bus.continuousData) == 2, 'ndims(bus.continuousData) must be 2');    assert(size(bus.continuousData, 1) <= 128, 'size(bus.continuousData, 1) exceeds max size of 128');    assert(size(bus.continuousData, 2) <= 60, 'size(bus.continuousData, 2) exceeds max size of 60');    % continuousData bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(3);
    offset = offset + uint32(1);

    % continuousData signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(5);
    offset = offset + uint32(1);

    % continuousData name with prefix 
    if(offset+uint32(2+14 -1) > numel(out)), return, end
    out(offset:(offset+uint32(1))) = typecast(uint16(numel(namePrefixBytes) + 14), 'uint8');
    offset = offset + uint32(2);
    out(offset:(offset+uint32(numel(namePrefixBytes) + 14-1))) = [namePrefixBytes, uint8('continuousData')];
    offset = offset + uint32(numel(namePrefixBytes) + 14);

    % continuousData units
    if(offset+uint32(2+0 -1) > numel(out)), return, end
    out(offset:(offset+uint32(1))) = typecast(uint16(0), 'uint8');
    offset = offset + uint32(2);

    % continuousData data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(0); % data type is double
    offset = offset + uint32(1);

    % continuousData dimensions
    if(offset > numel(out)), return, end
    if(offset+uint32(1+2*2-1) > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint32(1);
    out(offset:(offset+uint32(2*2-1))) = typecast(uint16(size(bus.continuousData)), 'uint8');
    offset = offset + uint32(2*2);

    % continuousData data
    nBytes = uint32(8 * size(bus.continuousData, 1) * size(bus.continuousData, 2));
    if nBytes > uint32(0)
        if(offset+uint32(nBytes-1) > numel(out)), return, end
        out(offset:(offset+uint32(nBytes-1))) = typecast(double(bus.continuousData(:))', 'uint8')';
    end
    offset = offset + nBytes; %#ok<NASGU>

    valid = uint8(1);
end