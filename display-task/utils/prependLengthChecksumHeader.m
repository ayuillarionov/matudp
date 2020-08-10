function [packet, length] = prependLengthChecksumHeader(data, prependHeader)
%#codegen

  % 4 byte header on first packet containing 2 byte length, 2 byte checksum

  coder.varsize('packet', 65504);

  if prependHeader
    % include custom 4 byte custom header with length and checksum
    headerPre = zeros(4, 1, 'uint8');
    headerPre(1:2) = typecast(uint16(numel(data)), 'uint8');
    checksum = uint16(mod(sum(uint32(data)), uint32(65536)));
    headerPre(3:4) = typecast(checksum, 'uint8');
    packet = [headerPre; makecol(data)];
    length = uint16(numel(data) + 4);
  else
    packet = makecol(data);
    length = uint16(numel(data));
  end

end