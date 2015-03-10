function [bus, valid, offset] = deserializeBus_TestBusOuter(in, offset, valid)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   writeDeserializeBusModelPackagedCode('testPacketSend', 'TestBusOuter')

    if nargin < 2
         offset = uint16(1);
    end
    if nargin < 3
         valid = uint8(1);
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing fixed-sized field val1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(15 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(15-1)), ...
        uint8([0, 2, 0, typecast(uint16(4), 'uint8'), 'val1', typecast(uint16(2), 'uint8'), 'AU', 3, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(15);

    % Establishing size
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.val1 = zeros([1 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) ~= uint16(1), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.val1 = zeros([1 1], 'uint8');
        else
            % read and typecast data
            assert(elements <= uint16(1));
            bus.val1 = zeros([1 1], 'uint8');
            if elements > uint16(0)
                bus.val1(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing fixed-sized field val2
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(17 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(17-1)), ...
        uint8([0, 2, 0, typecast(uint16(4), 'uint8'), 'val2', typecast(uint16(4), 'uint8'), 'char', 3, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(17);

    % Establishing size
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.val2 = zeros([5 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) ~= uint16(5), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.val2 = zeros([5 1], 'uint8');
        else
            % read and typecast data
            assert(elements <= uint16(5));
            bus.val2 = zeros([5 1], 'uint8');
            if elements > uint16(0)
                bus.val2(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing fixed-size field nested as nested Bus: TestBusInner
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % deserialize each bus element within
    [bus.nested, valid, offset] = testPacketSendLib.deserializeBus_TestBusInner(in, offset, valid);


end