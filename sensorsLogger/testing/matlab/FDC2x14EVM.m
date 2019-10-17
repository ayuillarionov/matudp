classdef FDC2x14EVM < handle
  %% FDC2x14 Description
  % The FDC2x14 is a multi-channel family of noise and EMI-resistant, high-resolution, high-speed
  % capacitance to digital converters for implementing capacitive sensing solutions. The devices
  % employ an innovative narrow-band based architecture to offer high rejection of noise and
  % interferers while providing high resolution at high speed. The devices support excitation
  % frequencies from 10kHz to 10MHz, offering flexibility in system design.
  % The FDC2214 is optimized for high resolution, up to 28 bits, while FDC2114 offers fast sample
  % rate, up to 13.3ksps, for easy implementation of applications that use fast moving targets. The
  % very large input capacitance of 250nF allows for the use of remote sensors, as well as for
  % tracking environmental changes over time, temperature and humidity. 
  %% FDC2214 Features
  % Number of channels: 4 (FDC2114(-Q1), FDC2214(-Q1))
  % Maximum Input Capacitance: 250nF (@10kHz with 1mH inductor)
  % Maximum output rates (one active channel): 13.3ksps (FDC2114), 4.08ksps FDC2214)
  % Resolution: 28-bit (FDC2214), 12-bit (FDC2114)
  % Sensor excitation frequency: 10kHz to 10MHz
  % Supply voltage: 2.7V to 3.6V
  % Low-Power Sleep Mode: 35uA
  % Shutdown: 200nA
  % Interface: I2C
  % Temp range: -40 to +125C
  %% FDC2214 EVM (MSP430 microcontroller) Description
  % The MSP430 microcontroller is used to interface the FDC to a host computer through USB interface.
  % http://e2e.ti.com/support/sensor/inductive-sensing/f/938/t/295036#Q41
  
  properties(SetAccess = protected)
    serialPort
    serialObject
    
    isOpen = false;
    isSleeping = true;
    isStreaming = false;
    
    sensorsUsed = [1 1 1 1]; % default
    
    startTime; % [year month day hour minute seconds] from the serial opening
  end
  
  properties(Dependent, Hidden)
    device_id % 3055 (FDC2212, FDC2214 only)
  end
  
  properties(Constant, Hidden) % Subclasses inherit constant properties, but cannot change them.
    read_header  = '4C120100032A';  % Read register command header
    write_header = '4C130100042A';  % Write register command header
    
    %write_header = '4C150100042A';    % Write register command header
    %set_header   = '4C150100022A';    % Set register to read command header
    %read_header  = '4C140100022A02';  % Read register command header
    
    %start_streaming = '4C0501000601290404302A'; % Continuously output data from device to serial port
    start_streaming = '4C0501000601000104302A'; % Continuously output data from device to serial port
    %stop_streaming  = '4C0601000101'; % Stop the streaming
    stop_streaming  = '4C07010000'; % Stop the streaming
    
    % http://www.ti.com/product/MSP430F5528
    % MSP430F5528IRGC addressing space  % default values
    DATA_MSB_CH0        = '00';     % 0000 - Channel 0 MSB Conversion Result and status
    DATA_LSB_CH0        = '01';     % 0000 - Channel 0 LSB Conversion Result and status
    DATA_MSB_CH1        = '02';     % 0000 - Channel 1 MSB Conversion Result and status
    DATA_LSB_CH1        = '03';     % 0000 - Channel 1 LSB Conversion Result and status
    DATA_MSB_CH2        = '04';     % 0000 - Channel 2 MSB Conversion Result and status
    DATA_LSB_CH2        = '05';     % 0000 - Channel 2 LSB Conversion Result and status
    DATA_MSB_CH3        = '06';     % 0000 - Channel 3 MSB Conversion Result and status
    DATA_LSB_CH3        = '07';     % 0000 - Channel 3 LSB Conversion Result and status
    RCOUNT_CH0          = '08';     % ffff - Reference Count setting for Channel 0 (max ffff - 26214.10us)
    RCOUNT_CH1          = '09';     % ffff - Reference Count setting for Channel 1
    RCOUNT_CH2          = '0A';     % ffff - Reference Count setting for Channel 2
    RCOUNT_CH3          = '0B';     % ffff - Reference Count setting for Channel 3
    OFFSET_CH0          = '0C';     % 0000 - Offset value for Channel 0
    OFFSET_CH1          = '0D';     % 0000 - Offset value for Channel 1
    OFFSET_CH2          = '0E';     % 0000 - Offset value for Channel 2
    OFFSET_CH3          = '0F';     % 0000 - Offset value for Channel 3
    SETTLECOUNT_CH0     = '10';     % 0400 - Channel 0 Settling Reference Count (= 1024 (409.6us))
    SETTLECOUNT_CH1     = '11';     % 0400 - Channel 1 Settling Reference Count
    SETTLECOUNT_CH2     = '12';     % 0400 - Channel 2 Settling Reference Count
    SETTLECOUNT_CH3     = '13';     % 0400 - Channel 3 Settling Reference Count
    CLOCK_DIVIDERS_CH0  = '14';     % 1001 - Reference divider settings for Channel 0
    CLOCK_DIVIDERS_CH1  = '15';     % 1001 - Reference divider settings for Channel 1
    CLOCK_DIVIDERS_CH2  = '16';     % 1001 - Reference divider settings for Channel 2
    CLOCK_DIVIDERS_CH3  = '17';     % 1001 - Reference divider settings for Channel 3
    STATUS              = '18';     % 0000 - Device Status Reporting
    ERROR_CONFIG        = '19';     % 0001 - Device Status Reporting Configuration
    CONFIG              = '1A';     % 1601 - Conversion Configuration
    MUX_CONFIG          = '1B';     % c209 - Channel Multiplexing Configuration
    RESET_DEV           = '1C';     % 0000 - Reset Device
    DRIVE_CURRENT_CH0   = '1E';     % 8c40 - Channel 0 sensor current drive configuration
    DRIVE_CURRENT_CH1   = '1F';     % 8c40 - Channel 1 sensor current drive configuration
    DRIVE_CURRENT_CH2   = '20';     % 8c40 - Channel 2 sensor current drive configuration
    DRIVE_CURRENT_CH3   = '21';     % 8c40 - Channel 3 sensor current drive configuration
    MANUFACTURER_ID     = '7E';     % 5449 - Manufacturer ID (Texas Instruments)
    DEVICE_ID           = '7F';     % 3055 - Device ID (FDC2212, FDC2214 only)
  end
  
  properties(Constant, Hidden)
    % max sensor frequency fSENSOR = 1/(2*pi*sqrt(LC)) = 1/(2*pi*sqrt(18*10^-6 * 53*10^-12)) = 5.15 MHz
    parallelInductance  = 18; % 18 muH
    parallelCapacitance = 33; % surface mount capacitance = 33 pF (total capacitance = 53pF)
    fCLK = 40;                % (external) frequency measurement master clock
    ENOB = 18;                % number of required effective bits
    
    % drive current (in mA)
    driveCurrent = [0.016, 0.018, 0.021, 0.025, 0.028, 0.033, 0.038, 0.044, 0.052, 0.060, 0.069, ...
                    0.081, 0.093, 0.108, 0.126, 0.146, 0.169, 0.196, 0.228, 0.264, 0.307, 0.356, ...
                    0.413, 0.479, 0.555, 0.644, 0.747, 0.867, 1.006, 1.167, 1.354, 1.571];
    iDrive = 15; % 0.196 mA
  end
  
  properties
    CH_FIN_SEL      = [];
    CH_FREF_DIVIDER = [];
    CH_SETTLECOUNT  = [];
    CH_RCOUNT       = [];
  end
  
  properties
    DEBUG_PRINT_TX_DATA = 1;
    DEBUG_PRINT_RX_DATA = 1;
    DEBUG_PRINT_READ_DATA = 1;
    DEBUG_PRINT_STREAM_DATA = 1;
  end
  
   properties(Constant, Hidden, Access = private)
     msgID = 'MATLAB:FDC2x14EVM';
   end
  
  properties(Hidden, Access = private)
    %BaudRate = 9600;               % 3.3ms per 32byte package
    %BaudRate = 115200;             % 0.28ms per 32byte package
    BaudRate = 1000000;             % 0.25ms per 32byte package
    InputBufferSize = 2^18;        % in bytes
    PackagesAvailableFcnCount = 2; % MSP send always 32 bytes packages (take 2 packages for non-blocking streaming)
    isDAQ = ~isempty(ver('daq'));  % is Data Acquisition Toolbox installed?
  end
  
  methods
    % Example:
    % On Linux:     serialPort = '/dev/ttyS0';
    % On MacOS:     serialPort = '/dev/tty.KeySerial1';
    % On Windows:   serialPort = 'COM1';
    function ts = FDC2x14EVM(serialPort)
      if nargin < 1 || ~(ischar(serialPort) || isstring(serialPort))
        error([ts.msgID, ':usageError'], ...
          ' Usage: FDC2214EVM(''serialPort'')');
      end
      
      if any(strcmp(seriallist('available'), serialPort))
        ts.serialPort = serialPort;
      else
        error([ts.msgID, ':serialPortNonAvailable'], ...
          ' Serial port %s is not available on the computer', serialPort);
      end
    end
  end
  
  methods
    function open(ts, baudRate, packagesAvailableFcnCount)
      if exist('baudRate', 'var') && ~isempty(baudRate)
        ts.BaudRate = baudRate;
      end
      if exist('packagesAvailableFcnCount', 'var') && ~isempty(packagesAvailableFcnCount)
        if packagesAvailableFcnCount >= 2
          ts.PackagesAvailableFcnCount = packagesAvailableFcnCount;
        else
          ts.PackagesAvailableFcnCount = 2; % Not less as 2
        end
      end

      if isempty(ts.serialObject)
        ts.serialObject = serial(ts.serialPort, 'BaudRate', ts.BaudRate);
        ts.serialObject.Name = ['FDC2214-Serial-', ts.serialObject.Port];
      end
      if ~ts.isOpen && ~strcmp(ts.serialObject.Status, 'open')
        ts.startTime = clock;
        
        ts.serialObject.Terminator = ''; % empty
        ts.serialObject.Timeout = 1;     % maximum time (in sec) to wait to complete a read or write operation
        ts.serialObject.ReadAsyncMode = 'continuous'; % automatically read and store data in the input buffer
        
        ts.serialObject.InputBufferSize = ts.InputBufferSize;
        % Execute the callback function when BytesAvailableFcnCount bytes are available in the input buffer
        ts.serialObject.BytesAvailableFcnMode = 'byte';
        ts.serialObject.BytesAvailableFcnCount = 32*ts.PackagesAvailableFcnCount + 1;
        ts.serialObject.BytesAvailableFcn = {@Serial_OnDataReceived, ts.startTime};
        % Streaming data storage
        ts.serialObject.Userdata = struct('isNew', false, 'timeStamp', [], 'data', []);
        
        if strcmp(ts.serialObject.Status, 'closed')
          fopen(ts.serialObject);
        else
          error([ts.msgID, ':serialPortAlreadyOpen'], ...
            ' Serial port %s is already open', ts.serialPort);
        end
        ts.isOpen = true;
        
        % check device ID
        if ts.device_id ~= "3055"
          error([ts.msgID, ':notFDC2214'], ...
            ' Attached to %s device is not a capacitive sensor FDC2214', ts.serialPort);
        end

        % default configuration
        ts.defaultConfig;
      end
    end
    
    function delete(ts)
      ts.close();
      delete(ts.serialObject);
    end
    
    function close(ts)
      if ts.isStreaming
        ts.stopStreaming;
      end
      flushinput(ts.serialObject);
      if ts.isOpen
        fclose(ts.serialObject);
      end
      ts.isOpen = false;
    end
    
    function writeRegister_error = writeRegister(ts, addr, data, addCRC8)
      if ~exist('addCRC8', 'var') || isempty(addCRC8)
        addCRC8 = 1;
      end
      [~, writeRegister_error] = ...
        ts.queryData([ts.write_header, char(addr), char(data)], addCRC8, 'Error in write register');
    end
    
    function [hexData, binData, readRegister_error] = readRegister(ts, addr, addCRC8)
      if ~exist('addCRC8', 'var') || isempty(addCRC8)
        addCRC8 = 1;
      end
      
      [hexData, readRegister_error] = ...
        ts.queryData([ts.read_header, char(addr), '02'], addCRC8, 'Error in read register');
      
      hexData = hexData(15:18);
      
      if ts.isDAQ % use Data Acquisition Toolbox
        binData = int2str(hexToBinaryVector(hexData, 4*length(hexData))); % logical array
      else
        binData = int2str(FDC2x14EVM.hex2bin(hexData, 4*length(hexData)));
      end
      binData = binData(~isspace(binData)); % string array
      
      if ts.DEBUG_PRINT_READ_DATA
        % print to the command window
        fprintf(1, 'Addr: %s, Data: %s, binData: %s\n', addr, hexData, binData);
      end
    end
    
    function defaultConfig(ts)
      ts.getDriveCurrent(1);
      ts.getDriveCurrent(3);
      %ts.sleepMode; % enter into Sleep Mode
      
      % 0 - Continuous conversion on the single channel selected by CONFIG.ACTIVE_CHAN
      % 1 - Auto-Scan conversions as selected by MUX_CONFIG.RR_SEQUENCE
      AUTOSCAN_EN = 1;
      % 00 - Ch0-Ch1; 01 - Ch0-Ch2; 10 - Ch0-Ch3; 11 - Ch0-Ch1
      RR_SEQUENCE = [1 0];
      % Reserved. Must be set to 00 0100 0001
      RESERVED = [0 0 0 1 0 0 0 0 0 1];
      % Input deglitch filter bandwidth.
      % Select the lowest setting that exceeds the oscillation tank oscillation frequency:
      % 001 - 1MHz; 100 - 3.3MHz; 101 - 10MHz; 111 - 33MHz
      DEGLITCH = [1 0 1];
      
      if ts.isDAQ % use Data Acquisition Toolbox
        hexConfig = binaryVectorToHex([AUTOSCAN_EN, RR_SEQUENCE, RESERVED, DEGLITCH]);
      else
        hexConfig = FDC2x14EVM.bin2hex([AUTOSCAN_EN, RR_SEQUENCE, RESERVED, DEGLITCH]);
      end
      
      writeRegister(ts, ts.MUX_CONFIG, hexConfig);
      
      if isequal(RR_SEQUENCE, [0 1])
        ts.sensorsUsed = [1 1 1 0];
      elseif isequal(RR_SEQUENCE, [1 0])
        ts.sensorsUsed = [1 1 1 1];
      else
        ts.sensorsUsed = [1 1 0 0];
      end
      
      % clock configuration (read frequency dividers)
      ts.clockConfig;
      
      ts.normalMode; % enter into Normal Mode
    end
    
    function clockConfig(ts)
      reg = ["08", "09", "0A", "0B"; ... % RCOUNT
        "10", "11", "12", "13"; ...      % SETTLECOUNT
        "14", "15", "16", "17"];         % CLOCK_DIVIDERS
      
      for i = 1:size(ts.sensorsUsed,2)
        if ts.sensorsUsed(i)
          ts.CH_RCOUNT(i) = hex2dec(ts.readRegister(reg(1,i)));
          ts.CH_SETTLECOUNT(i) = hex2dec(ts.readRegister(reg(2,i)));
          
          [~, clockDivider] = ts.readRegister(reg(3,i));
          ts.CH_FIN_SEL(i) = bin2dec(clockDivider(3:4));
          ts.CH_FREF_DIVIDER(i) = bin2dec(clockDivider(7:end));
        end
      end
    end
    
    function [binStatus, ...
        ERR_CHAN, ERR_WD, ERR_AHW, ERR_ALW, DRDY, ...
        CH0_UNREADCONV, CH1_UNREADCONV, CH2_UNREADCONV, CH3_UNREADCONV] = status(ts)
      if ~ts.isOpen
        error([ts.msgID, ':statusError'], ...
          ' Open serial port %s first', ts.serialPort);
      end
      
      [~, binStatus] = readRegister(ts, ts.STATUS);    % Address 0x18
      
      % Indicates which channel has generated a Flag or Error. Once flagged, any reported error is
      % latched and maintained until either the STATUS register or the DATA_CHx register corresponding
      % to the Error Channel is read.
      % 00 - Ch0, 01 - Ch1, 10 - Ch2, 11 - Ch3
      ERR_CHAN       = binStatus(1:2);
      % Watchdog Timeout error
      ERR_WD         = str2double(binStatus(5));
      % Amplitude High Warning
      ERR_AHW        = str2double(binStatus(6));
      % Amplitude Low Warning
      ERR_ALW        = str2double(binStatus(7));
      % Data Ready Flag
      DRDY           = str2double(binStatus(10));
      % Channels 0-3 Unread Conversion present (read Register DATA_CH0-3 to retrieve conversion results)
      CH0_UNREADCONV = str2double(binStatus(13));
      CH1_UNREADCONV = str2double(binStatus(14));
      CH2_UNREADCONV = str2double(binStatus(15));
      CH3_UNREADCONV = str2double(binStatus(16));
    end
    
    % Conversion stop and all register values return to their default values.
    function reset(ts)
      hexData = '8000'; % '1 0000 00 0 0000 0000'
      writeRegister(ts, ts.RESET_DEV, hexData);
    end
    
    % NOTE: the register contents are maintained.
    function sleepMode(ts)
      ts.switchMode(1);
    end
    
    function normalMode(ts)
      ts.switchMode(0);
    end
    
    function switchMode(ts, sleep)
      if exist('sleep', 'var') && sleep == 1
        SLEEP_MODE_EN = 1;     % device is in Sleep Mode
        ts.isSleeping = true;
      else
        SLEEP_MODE_EN = 0;     % device is in Normal Mode
        ts.isSleeping = false;
      end

      ACTIVE_CHAN = [0 0];   % 00 - ch0, 01 - ch1, 10 - ch2, 11 - ch3
      SENSOR_ACTIVE_SEL = 0; % maximum sensor current for a shorter sensor activation time
      REF_CLK_SRC = 1;       % reference frequency is provided from CLKIN pin (40 MHz)
      INTB_DIS = 0;          % INTB pin will be asserted when status register updates
      HIGH_CURRENT_DRV = 0;  % drive all channels with normal sensor current (1.5mA max)
      
      if ts.isDAQ % use Data Acquisition Toolbox
        hexData = binaryVectorToHex([ACTIVE_CHAN, SLEEP_MODE_EN, ...
          1, SENSOR_ACTIVE_SEL, 1, REF_CLK_SRC, 0, INTB_DIS, HIGH_CURRENT_DRV, [0 0 0 0 0 1]]);
      else
        hexData = FDC2x14EVM.bin2hex([ACTIVE_CHAN, SLEEP_MODE_EN, ...
          1, SENSOR_ACTIVE_SEL, 1, REF_CLK_SRC, 0, INTB_DIS, HIGH_CURRENT_DRV, [0 0 0 0 0 1]]);
      end
      
      writeRegister(ts, ts.CONFIG, hexData);
    end
    
    function [binConfig, ...
        ACTIVE_CHAN, SLEEP_MODE_EN, SENSOR_ACTIVE_SEL, ...
        REF_CLK_SRC, INTB_DIS, HIGH_CURRENT_DRV] = getConfig(ts)
      if ~ts.isOpen
        error([ts.msgID, ':getConfigError'], ...
          ' Open serial port %s first', ts.serialPort);
      end
      
      [~, binConfig] = readRegister(ts, ts.CONFIG);    % Address 0x1A
      
      % Active Channel Selection when MUX_CONFIG.AUTOSCAN_EN = 0
      %00 - ch0, 01 - ch1, 10 - ch2, 11 - ch3
      ACTIVE_CHAN = binConfig(1:2);
      % 0 - device is active, 1 - device in Sleep Mode
      SLEEP_MODE_EN = str2double(binConfig(3));
      % Sensor Activation Mode:
      % 0 - Full Current Activation Mode, 1 - Low Power Activation Mode (use DRIVE_CURRENT_CHx)
      SENSOR_ACTIVE_SEL = str2double(binConfig(5));
      % Reference Frequency Source
      % 0 - internal oscillator (43.3 MHz Typical), 1 - reference frequency is provided from CLKIN pin (40 MHz)
      REF_CLK_SRC = str2double(binConfig(7));
      % 0 (1) - INTB pin will be (NOT) asserted when status register updates
      INTB_DIS = str2double(binConfig(9));
      % High Current Sesor Drive
      % 0 - drive all channels with normal sensor current (1.5mA max)
      % 1 - drive Ch0 with current > 1.5mA (only if MUX_CONFIG.AUTOSCAN_EN = 0)
      HIGH_CURRENT_DRV = str2double(binConfig(10));
    end
    
    function [iDrive, current] = getDriveCurrent(ts, channel)
      reg = [ts.DRIVE_CURRENT_CH0; ts.DRIVE_CURRENT_CH1 ; ts.DRIVE_CURRENT_CH2; ts.DRIVE_CURRENT_CH3];
      
      [~, binCurrent] = readRegister(ts, reg(channel,:));
      
      iDrive = bin2dec(binCurrent(1:5));   % 0 - 31
      current = ts.driveCurrent(iDrive+1); % in mA
    end
    
    function [iDrive, current] = setDriveCurrent(ts, channel, iDrive)
      reg = [ts.DRIVE_CURRENT_CH0; ts.DRIVE_CURRENT_CH1 ; ts.DRIVE_CURRENT_CH2; ts.DRIVE_CURRENT_CH3];
      
      if ~(isreal(iDrive) && rem(iDrive,1)==0) || (iDrive < 0) || (iDrive > 31)
        error([ts.msgID, ':setDriveCurrentError'], ...
          ' iDrive should be an integer positive number, less as 32.');
      end
      
      % read the present value to get the binary tail
      [~, binCurrent] = readRegister(ts, reg(channel,:));
      
      % write the new one
      hexCurrent = dec2hex(bin2dec([dec2bin(iDrive), binCurrent(6:16)]));
      writeRegister(ts, reg(channel,:), hexCurrent);
      
      current = ts.driveCurrent(iDrive+1);
    end
    
    function [samplingTime, switchDelay, settleTime, conversionTime, ENOB] ...
        = channelSamplingTime(ts, channel) % micro seconds
      switchDelay            = ts.channelSwitchDelay(channel);
      settleTime             = ts.channelSettleTime(channel);
      [conversionTime, ENOB] = ts.channelConversionTime(channel);
      
      samplingTime = switchDelay + settleTime + conversionTime;
    end
    
    function regValues = readAllRegisters(ts)
      if ~ts.isOpen
        error([ts.msgID, ':readAllRegistersError'], ...
          ' Open serial port %s first', ts.serialPort);
      end
      
      regValues = table('Size', [35 4], ...
        'VariableTypes', {'string', 'string', 'string', 'string'}, ...
        'VariableNames', {'Register', 'Address', 'CurrentValue', 'Bits'});
      
      % Channel 0 MSB Conversion Result and status
      regValues.Register(1) = 'DATA_MSB_CH0'; regValues.Address(1) = '00';
      % Channel 0 LSB Conversion Result and status
      regValues.Register(2) = 'DATA_LSB_CH0'; regValues.Address(2) = '01';
      % Channel 1 MSB Conversion Result and status
      regValues.Register(3) = 'DATA_MSB_CH1'; regValues.Address(3) = '02';
      % Channel 1 LSB Conversion Result and status
      regValues.Register(4) = 'DATA_LSB_CH1'; regValues.Address(4) = '03';
      % Channel 2 MSB Conversion Result and status
      regValues.Register(5) = 'DATA_MSB_CH2'; regValues.Address(5) = '04';
      % Channel 2 LSB Conversion Result and status
      regValues.Register(6) = 'DATA_LSB_CH2'; regValues.Address(6) = '05';
      % Channel 3 MSB Conversion Result and status
      regValues.Register(7) = 'DATA_MSB_CH3'; regValues.Address(7) = '06';
      % Channel 3 LSB Conversion Result and status
      regValues.Register(8) = 'DATA_LSB_CH3'; regValues.Address(8) = '07';
      
      % Reference Count setting for Channel 0 (ffff - max)
      regValues.Register(9)  = 'RCOUNT_CH0'; regValues.Address(9)  = '08';
      % Reference Count setting for Channel 1 (ffff - max)
      regValues.Register(10) = 'RCOUNT_CH1'; regValues.Address(10) = '09';
      % Reference Count setting for Channel 2 (ffff - max)
      regValues.Register(11) = 'RCOUNT_CH2'; regValues.Address(11) = '0A';
      % Reference Count setting for Channel 3 (ffff - max)
      regValues.Register(12) = 'RCOUNT_CH3'; regValues.Address(12) = '0B';
 
      % Offset value for Channel 0
      regValues.Register(13) = 'OFFSET_CH0'; regValues.Address(13) = '0C';
      % Offset value for Channel 1
      regValues.Register(14) = 'OFFSET_CH1'; regValues.Address(14) = '0D';
      % Offset value for Channel 2
      regValues.Register(15) = 'OFFSET_CH2'; regValues.Address(15) = '0E';
      % Offset value for Channel 3
      regValues.Register(16) = 'OFFSET_CH3'; regValues.Address(16) = '0F';

      % Channel 0 Settling Reference Count (= 1024 (409.6us))
      regValues.Register(17) = 'SETTLECOUNT_CH0'; regValues.Address(17) = '10';
      % Channel 1 Settling Reference Count (= 1024 (409.6us))
      regValues.Register(18) = 'SETTLECOUNT_CH1'; regValues.Address(18) = '11';
      % Channel 2 Settling Reference Count (= 1024 (409.6us))
      regValues.Register(19) = 'SETTLECOUNT_CH2'; regValues.Address(19) = '12';
      % Channel 3 Settling Reference Count (= 1024 (409.6us))
      regValues.Register(20) = 'SETTLECOUNT_CH3'; regValues.Address(20) = '13';

      % Reference divider settings for Channel 0
      regValues.Register(21) = 'CLOCK_DIVIDERS_CH0'; regValues.Address(21) = '14';
      % Reference divider settings for Channel 1
      regValues.Register(22) = 'CLOCK_DIVIDERS_CH1'; regValues.Address(22) = '15';
      % Reference divider settings for Channel 2
      regValues.Register(23) = 'CLOCK_DIVIDERS_CH2'; regValues.Address(23) = '16';
      % Reference divider settings for Channel 3
      regValues.Register(24) = 'CLOCK_DIVIDERS_CH3'; regValues.Address(24) = '17';
      
      % Device Status Reporting
      regValues.Register(25) = 'STATUS'; regValues.Address(25) = '18';
      
      % Device Status Reporting Configuration
      regValues.Register(26) = 'ERROR_CONFIG'; regValues.Address(26) = '19';
      
      % Conversion Configuration
      regValues.Register(27) = 'CONFIG'; regValues.Address(27) = '1A';
      
      % Channel Multiplexing Configuration
      regValues.Register(28) = 'MUX_CONFIG'; regValues.Address(28) = '1B';
      
      % Reset Device
      regValues.Register(29) = 'RESET_DEV'; regValues.Address(29) = '1C';
      
      % Channel 0 sensor current drive configuration
      regValues.Register(30) = 'DRIVE_CURRENT_CH0'; regValues.Address(30) = '1E';
      % Channel 1 sensor current drive configuration
      regValues.Register(31) = 'DRIVE_CURRENT_CH1'; regValues.Address(31) = '1F';
      % Channel 2 sensor current drive configuration
      regValues.Register(32) = 'DRIVE_CURRENT_CH2'; regValues.Address(32) = '20';
      % Channel 3 sensor current drive configuration
      regValues.Register(33) = 'DRIVE_CURRENT_CH3'; regValues.Address(33) = '21';
      
      % Manufacturer ID (Texas Instruments)
      regValues.Register(34) = 'MANUFACTURER_ID'; regValues.Address(34) = '7E';
      
      % Device ID (FDC2212, FDC2214 only)
      regValues.Register(35) = 'DEVICE_ID'; regValues.Address(35) = '7F';
      
      for i = 1:size(regValues,1)
        [regValues.CurrentValue(i), regValues.Bits(i)] = ...
          readRegister(ts, convertStringsToChars(regValues.Address(i)));
      end
    end
    
    function startStreaming_error = startStreaming(ts)
      if ~ts.isStreaming
        [~, startStreaming_error] = ts.queryData(ts.start_streaming, 'startStreaming error');
        if startStreaming_error >= 0
          ts.isStreaming = true;
        end
      else
        disp('Streamin is already started')
      end
    end
    
    function stopStreaming_error = stopStreaming(ts)
      [~, stopStreaming_error] = ts.queryData(ts.stop_streaming, 'stopStreaming error');
      flushinput(ts.serialObject); % removes all data from input buffer and set BytesAvailable to 0

      if stopStreaming_error >= 0
        ts.isStreaming = false;
      end
    end

    function [frequency, totalCapacitance, sensorCapacitance, data, hexData] = getStreamingData(ts)
      if ~ts.isStreaming
        ts.startStreaming;
      end
      
      % wait until respond by serial listener
      tic;
      while ~ts.serialObject.UserData.isNew
        if toc >= ts.serialObject.Timeout
          error(message('MATLAB:serial:FDC2x14EVM:getStreamingDataError', ...
            ' The expected amount of data was not returned within the Timeout period.'))
        end
      end
      
      if ts.serialObject.UserData.isNew % get the streaming data from cache
        hexRecv = ts.serialObject.UserData.data;
        ts.serialObject.UserData.isNew = 0;
      else                              % read the streaming data from device
        [asciiData, ~, ~] = fread(ts.serialObject, 32*fix(ts.serialObject.BytesAvailable/32), 'char');
        hexRecv = unique(reshape(sprintf('%02X', asciiData), 64, [])', 'rows', 'stable');
      end
      
      if ts.DEBUG_PRINT_STREAM_DATA
        fprintf(1, 'Stream: %s\n', hexRecv(end,:)); % print to the command window
      end
      
      hexData = [hexRecv(end,13:20); hexRecv(end,21:28); hexRecv(end,29:36); hexRecv(end,37:44)];
      data = hex2dec(hexData);
      
      frequency = zeros(4,1); totalCapacitance = zeros(4,1); sensorCapacitance = zeros(4,1);

      for i = 1:length(data)
        [frequency(i), totalCapacitance(i), sensorCapacitance(i)] = ts.calculatedSensorData(i, data(i));
      end
    end
    
    function DS = streamingStats(ts)
      % Returns timing statistics of sampling data.
      if ts.serialObject.UserData.isNew
        DS = datastats(diff(unique(ts.serialObject.UserData.timeStamp, 'rows', 'stable')));
      end
    end
    
    function [channelFrequency, rawData, status] = getChannelFrequency(ts, channel)
      if ~ts.isOpen
        error([ts.msgID, ':getChannelDataError'], ...
          ' Open serial port %s first', ts.serialPort);
      end

      channelFrequency = 0;
      
      status = ts.status();
      if ~str2double(status(10)) || ~str2double(status(12 + channel))
        fprintf(1, 'No new data available on channel %i\n', channel);
        return;
      end
      
      switch(channel)
        case 1
          DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH0);
          DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH0);
        case 2
          DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH1);
          DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH1);
        case 3
          DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH2);
          DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH2);
        case 4
          DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH3);
          DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH3);
        case delault
          DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH0);
          DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH0);
      end
      
      rawData = hex2dec([DATA_MSB_CH, DATA_LSB_CH]);
      
      channelFrequency = ts.calculatedSensorData(channel, rawData);
    end
    
    function [frequency, totalCapacitance, sensorCapacitance, data, status] = scanChannels(ts)
      if ~ts.isOpen
        error([ts.msgID, ':scanChannelsError'], ...
          ' Open serial port %s first', ts.serialPort);
      end
      
      if ts.isSleeping
        ts.normalMode;
      end
      
      data = zeros(4,1); frequency = data; totalCapacitance = data; sensorCapacitance = data;
       
      status = ts.status();
      if ~str2double(status(10))
        %disp('Error: No new data is available!');
        return;
      end
      
      if ts.sensorsUsed(1) || ~str2double(status(13))
        DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH0);
        DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH0);
        data(1) = hex2dec([DATA_MSB_CH, DATA_LSB_CH]);
        [frequency(1), totalCapacitance(1), sensorCapacitance(1)] = ts.calculatedSensorData(1, data(1));
      end
      if ts.sensorsUsed(2) || ~str2double(status(14))
        DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH1);
        DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH1);
        data(2) = hex2dec([DATA_MSB_CH, DATA_LSB_CH]);
        [frequency(2), totalCapacitance(2), sensorCapacitance(2)] = ts.calculatedSensorData(2, data(2));
      end
      if ts.sensorsUsed(3) || ~str2double(status(14))
        DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH2);
        DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH2);
        data(3) = hex2dec([DATA_MSB_CH, DATA_LSB_CH]);
        [frequency(3), totalCapacitance(3), sensorCapacitance(3)] = ts.calculatedSensorData(3, data(3));
      end
      if ts.sensorsUsed(4) || ~str2double(status(14))
        DATA_MSB_CH = ts.readRegister(ts.DATA_MSB_CH3);
        DATA_LSB_CH = ts.readRegister(ts.DATA_LSB_CH3);
        data(4) = hex2dec([DATA_MSB_CH, DATA_LSB_CH]);
        [frequency(4), totalCapacitance(4), sensorCapacitance(4)] = ts.calculatedSensorData(4, data(4));
      end
    end
    
  end
  
  methods
    function device_id = get.device_id(ts)
      assert(ts.isOpen, 'Open FDC2214EVM first!');
      device_id = ts.readRegister(ts.DEVICE_ID);
    end
  end
    
  methods(Access = private)
    function [hexRecv, nValues] = queryData(ts, hexData, addCRC8, errorMessage)
      if ~ts.isOpen
        error([ts.msgID, ':querryDataError'], ...
          ' Open serial port %s first', ts.serialPort);
      end
      
      %{
      if ts.isStreaming
        ts.stopStreaming;
      end
      %}
      
      % Check if string elements are in the range of valid hexadecimal digits
      if ~all(isstrprop(hexData, 'xdigit'))
        error([ts.msgID, ':querryDataError'], ...
          ' Input must be a valid hexadecimal character string');
      end
      
      if ~exist('addCRC8', 'var') || isempty(addCRC8)
        addCRC8 = 1;
      end

      if addCRC8
        hexSend = [hexData, FDC2x14EVM.crc8(hexData)];
      else
        hexSend = hexData;
      end

      flushinput(ts.serialObject);
      fwrite(ts.serialObject, char(sscanf(hexSend, '%02X').'), 'char', 'sync');
      
      %{
      % wait until respond by serial listener
      tic;
      while ~ts.serialObject.UserData.isNew
        if toc >= ts.serialObject.Timeout
          error(message('MATLAB:serial:FDC2x14EVM:queryData', ...
            ' The expected amount of data was not returned within the Timeout period.'))
        end
      end
      
      nValues = 32;
      hexRecv = ts.serialObject.UserData.data(1,:);
      ts.serialObject.UserData.isNew = 0;
      %}
 
      % get data from serial object
      [asciiRecv, nValues] = fread(ts.serialObject, 32, 'char'); % nValues = 32
      hexRecv = sprintf('%02X', asciiRecv);
        
      if ts.DEBUG_PRINT_RX_DATA
        fprintf(1, 'Read: %s\n', hexRecv); % print to the command window
      end
     
      if (hexRecv(7:8) ~= char('00'))
        if exist('errorMessage', 'var') && ~isempty(errorMessage)
          disp(errorMessage)
        else
          disp('Error in queryData')
        end
        nValues = -1;
      end
    end
    
    % Frequency[MHz], total Capacitance[pF]
    function [frequency, totalCapacitance, sensorCapacitance] = calculatedSensorData(ts, channel, data)
      frequency = ts.CH_FIN_SEL(channel)/ts.CH_FREF_DIVIDER(channel) * ts.fCLK/2^28 * data;
      totalCapacitance = 1/(2*pi*frequency)^2/ts.parallelInductance * 10^6; % fSENSOR = 1/(2*pi*sqrt(LC))
      sensorCapacitance = totalCapacitance - ts.parallelCapacitance;
    end
    
    function switchDelay = channelSwitchDelay(ts, channel) % micro seconds
      switchDelay = 692*10^-3 + 5/ts.fCLK*ts.CH_FREF_DIVIDER(channel);
    end
    
    function settleTime = channelSettleTime(ts, channel) % micro seconds
      settleTime = 16/ts.fCLK*ts.CH_FREF_DIVIDER(channel) * ts.CH_SETTLECOUNT(channel);
    end
    
    function [converionTime, ENOB] = channelConversionTime(ts, channel) % micro seconds
      converionTime = 16/ts.fCLK*ts.CH_FREF_DIVIDER(channel) * ts.CH_RCOUNT(channel);
      ENOB = log2(16*ts.CH_RCOUNT(channel)) + 1; % number of effective bits
    end
  end
  
  methods(Static, Hidden, Access = private)
    function crc8 = crc8(hexData)
      % This function calculates the CRC-8 checksum for the LDC 13xx/16xx EVMs (e.g FDC2214EVM)
      % hexData must be a valid hexadecimal character string. 
      %
      % copyright by:
      % Alexey Yu. Illarionov (C) 2018
      % e-mail: ayuillarionov (at) ini.uzh.ch
      %
      % Poly: 0x07, Check (over the string "123456789" or hex "0x313233343536373839"): 0xF4
      % InitialState (XorIn): 0x00, ReflectInput: false, ReflectRemainder: false, FinalXOR: 0x00
      
      if ~all(isstrprop(hexData, 'xdigit'))
        error('MATLAB:FDC2x14EVM:crc8Error', ...
          ' Input must be a valid hexadecimal character string');
      end
      
      isDAQ = ~isempty(ver('daq')); % is Data Acquisition Toolbox installed?
      
      poly = [1 0 0 0 0 0 1 1 1]; % CRC-8 array: z^8+z^2+z+1.
      
      if isDAQ % use Data Acquisition Toolbox
        A = hexToBinaryVector(hexData, 4*length(hexData));
      else
        A = FDC2x14EVM.hex2bin(hexData, 4*length(hexData));
      end
      
      data_length = length(A);
      A = [A, zeros(1,8)];
      
      for k=1:data_length
        if A(k) == 1
          A(k:k+8) = xor(A(k:k+8), poly);
        end
      end
      
      if isDAQ % use Data Acquisition Toolbox
        crc8 = binaryVectorToHex(A(end-7:end));
      else
        crc8 = FDC2x14EVM.bin2hex(A(end-7:end));
      end
      
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
    
  end
  
end

% Serial Data Processing Function
function Serial_OnDataReceived(obj, event, startTime)
  if strcmp(obj.Status, 'open')
    % SERIAL_ONDATARECEIVED is the "BytesAvailableFcn" for serial port object, so it is called
    % automatically when BytesAvailableFcnCount bytes of data have been received at the serial port.
    
    if ~obj.BytesAvailable
      return;
    end
    
    [asciiData, ~, ~] = fread(obj, 32*fix(obj.BytesAvailable/32), 'char'); % MSP send always 32 bytes blocks

    hexData = unique(reshape(sprintf('%02X', asciiData), 64, [])', 'rows', 'stable');
    
    if ts.DEBUG_PRINT_STREAM_DATA
      fprintf(1, 'Stream: %s\n', hexData); % print to the command window
    end
    
    %timeStamp = repmap(etime(event.Data.AbsTime, startTime), size(hexData,1), 1);
    timeStamp = etime(event.Data.AbsTime, startTime) * ones(size(hexData,1), 1);
    if ~obj.UserData.isNew
      % indicate that we have new data
      obj.UserData.isNew     = true;
      obj.UserData.timeStamp = timeStamp;
      obj.UserData.data      = hexData;
    else
      % append this new data to the previous one
      obj.UserData.timeStamp = [obj.UserData.timeStamp; timeStamp];
      obj.UserData.data      = [obj.UserData.data; hexData];
    end
  end
end