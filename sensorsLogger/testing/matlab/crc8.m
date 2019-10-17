function crc8hex = crc8(data_hex)
% This function calculates the CRC-8 checksum for the LDC 13xx/16xx EVMs (e.g FDC2214EVM)
%
% copyright by:
% Alexey Yu. Illarionov (C) 2018
% e-mail: ayuillarionov (at) ini.uzh.ch
%
% Check: 0xF4, Poly: 0x07,
% InitialState: 0x00, ReflectInput: false, ReflectRemainder: false, FinalXOR: 0x00

  poly = [1 0 0 0 0 0 1 1 1]; % CRC-8 array: z^8+z^2+z+1.
  
  %A = hexToBinaryVector(data_hex, 4*length(data_hex));
  A = hex2bin(data_hex, 4*length(data_hex))
  data_length = length(A);
  A = [A, zeros(1,8)];

  for k=1:data_length
    if A(k) == 1
      A(k:k+8) = xor(A(k:k+8), poly);
    end
  end
  
  %crc8hex = binaryVectorToHex(A(end-7:end));
  crc8hex = bin2hex(A(end-7:end));
end

function bin = hex2bin(hexString, n)
% This function converts a hexadecimal string of just about any length
% to the proper binary equivalent with at least n bits.
%
% copyright by:
% Alexey Yu. Illarionov (C) 2018
% e-mail: ayuillarionov (at) ini.uzh.ch
%
  if isempty(hexString), bin = []; return, end

  hexLength = length(hexString);

  if nargin == 2
    if ~(isnumeric(n) || ischar(n)) || ~isscalar(n) || n<0
      error('MATLAB:FDC2x14EVM:hex2bin:InvalidBitArg', ...
        ' N must be a positive scalar numeric.');
    end
    n = round(double(n)); % Make sure n is an integer.
    if n < 4*hexLength
      error('MATLAB:FDC2x14EVM:hex2bin:InsufficientBitsNumber', ...
        ' Insufficient number of bits specified for conversion.');
    end
  else
    n = 4*hexLength;
  end

  hex = upper(hexString(:)); % Make sure h is a column vector.

  % Check for out of range values
  if any(any(~((hex>='0' & hex<='9') | (hex>='A' & hex<='F'))))
    error('MATLAB:FDC2x14EVM:hex2bin:IllegalHexadecimal', ...
      'Input string found with characters other than 0-9, a-f, or A-F.');
  end
  %
  for i = 1:hexLength
    switch hex(i)
      case{'0'}
        bin((i*4)-3:i*4) = [0 0 0 0];
      case{'1'}
        bin((i*4)-3:i*4) = [0 0 0 1];
      case{'2'}
        bin((i*4)-3:i*4) = [0 0 1 0];
      case{'3'}
        bin((i*4)-3:i*4) = [0 0 1 1];
      case{'4'}
        bin((i*4)-3:i*4) = [0 1 0 0];
      case{'5'}
        bin((i*4)-3:i*4) = [0 1 0 1];
      case{'6'}
        bin((i*4)-3:i*4) = [0 1 1 0];
      case{'7'}
        bin((i*4)-3:i*4) = [0 1 1 1];
      case{'8'}
        bin((i*4)-3:i*4) = [1 0 0 0];
      case{'9'}
        bin((i*4)-3:i*4) = [1 0 0 1];
      case{'A', 'a'}
        bin((i*4)-3:i*4) = [1 0 1 0];
      case{'B', 'b'}
        bin((i*4)-3:i*4) = [1 0 1 1];
      case{'C', 'c'}
        bin((i*4)-3:i*4) = [1 1 0 0];
      case{'D', 'd'}
        bin((i*4)-3:i*4) = [1 1 0 1];
      case{'E', 'e'}
        bin((i*4)-3:i*4) = [1 1 1 0];
      case{'F', 'f'}
        bin((i*4)-3:i*4) = [1 1 1 1];
    end
  end
  bin = logical([zeros(1, n-length(bin)), bin]); % convert into logical array
end

function hex = bin2hex(binVector)
% This function converts binary vector value of any length to hexadecimal with MSB bit order.
% binVector is the binary vector to convert to hexadecimal specified as a numeric vector with 0s and 1s.
% hex is the output hexadecimal value returned as a character vector.
%
% copyright by:
% Alexey Yu. Illarionov (C) 2018
% e-mail: ayuillarionov (at) ini.uzh.ch
%
  if isempty(binVector), hex = []; return, end

  % Convert to string if input is not a string
  if ~ischar(binVector)
    binString = num2str(binVector);
  else
    binString = binVector;
  end
  binString = strrep(binString, ' ', '');

  % Check for out of range values
  if ~all(binString=='0' | binString=='1')
    error('MATLAB:FDC2x14EVM:bin2hex:IllegalBinVector',...
      'Input vector found with values other than 0s and 1s');
  end
  %
  n = length(binString);

  for i = ceil(n/4) : -1 : 1
    if n > 4
      hex(i) = b2h(binString(n-3:n));
      n = n-4;
    else
      hex(i) = b2h(binString(1:n));
    end
  end

    function h = b2h(b)
      switch b
        case {'0', '00', '000', '0000'}
          h = '0';
        case {'1', '01', '001', '0001'}
          h = '1';
        case {'10', '010', '0010'}
          h = '2';
        case {'11', '011', '0011'}
          h = '3';
        case {'100', '0100'}
          h = '4';
        case {'101', '0101'}
          h = '5';
        case {'110', '0110'}
          h = '6';
        case {'111', '0111'}
          h = '7';
        case '1000'
          h = '8';
        case '1001'
          h = '9';
        case '1010'
          h = 'A';
        case '1011'
          h = 'B';
        case '1100'
          h = 'C';
        case '1101'
          h = 'D';
        case '1110'
          h = 'E';
        case '1111'
          h = 'F';
      end
    end
end