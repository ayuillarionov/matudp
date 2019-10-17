#ifndef __FDC2x14EVM_H_
#define __FDC2x14EVM_H_

/* 
 * %% FDC2x14 Description
 * % The FDC2x14 is a multi-channel family of noise and EMI-resistant, high-resolution, high-speed
 * % capacitance to digital converters for implementing capacitive sensing solutions. The devices
 * % employ an innovative narrow-band based architecture to offer high rejection of noise and
 * % interferers while providing high resolution at high speed. The devices support excitation
 * % frequencies from 10kHz to 10MHz, offering flexibility in system design.
 * % The FDC2214 is optimized for high resolution, up to 28 bits, while FDC2114 offers fast sample
 * % rate, up to 13.3ksps, for easy implementation of applications that use fast moving targets. The
 * % very large input capacitance of 250nF allows for the use of remote sensors, as well as for
 * % tracking environmental changes over time, temperature and humidity.
 * 
 * %% FDC2x14 Features
 * % Number of channels: 4 (FDC2114(-Q1), FDC2214(-Q1))
 * % Maximum Input Capacitance: 250nF (@10kHz with 1mH inductor)
 * % Maximum output rates (one active channel): 13.3ksps (FDC2114), 4.08ksps FDC2214)
 * % Resolution: 28-bit (FDC2214), 12-bit (FDC2114)
 * % Sensor excitation frequency: 10kHz to 10MHz
 * % Supply voltage: 2.7V to 3.6V
 * % Low-Power Sleep Mode: 35uA
 * % Shutdown: 200nA
 * % Interface: I2C
 * % Temp range: -40 to +125C
 *
 * %% FDC2x14 EVM (MSP430 microcontroller) Description
 * % The MSP430 microcontroller is used to interface the FDC to a host computer through USB interface.
 * % http://e2e.ti.com/support/sensor/inductive-sensing/f/938/t/295036#Q41
 */

/*===============================================================================*/
/* Sellecting the Serial port Number on Linux                                    */
/* ------------------------------------------------------------------------------*/
/* /dev/ttyACMx - when using USB to Serial Converter, where x can be 0,1,2...etc */
/* /dev/ttySx   - for PC hardware based Serial ports, where x can be 0,1,2...etc */
/*===============================================================================*/
/* Selecting the Serial port Number on MAC OSX                                   */
/* ------------------------------------------------------------------------------*/
/* /dev/cu.usbmodemxxxxx                                                         */
/*===============================================================================*/
/* Sellecting the Serial port Number on Windows                                  */
/* ------------------------------------------------------------------------------*/
/* COMx                                                                          */
/*===============================================================================*/

/* baudrate settings are defined in <asm/termbits.h>, which is included by <termios.h> */
#if defined(__linux__)
  #define BAUDRATE B1000000 // 010010
#elif defined(__APPLE__) && defined(__MACH__)
  #define BAUDRATE B230400
#elif defined(_WIN64)       // Microsoft Windows (64-bit)
  #include <windows.h>
  #define _USE_MATH_DEFINES
#endif

#define DEVICE_FDC2114 3054
#define DEVICE_FDC2214 3055

#define RECV_SIZE     32 // it is always 32 bytes (ASCII) response
#define HEX_RECV_SIZE 65 // it is always 64 char (HEX) response + '\0'

#if defined(DEBUG)
	#define DEBUG_PRINT_TX_DATA     1
	#define DEBUG_PRINT_RX_DATA     1
	#define DEBUG_PRINT_QUERY_INFO  1
	#define DEBUG_PRINT_SCAN_DATA   1
	#define DEBUG_PRINT_STREAM_DATA 1
#else
	#define DEBUG_PRINT_TX_DATA     0
	#define DEBUG_PRINT_RX_DATA     0
	#define DEBUG_PRINT_QUERY_INFO  0
	#define DEBUG_PRINT_SCAN_DATA   0
	#define DEBUG_PRINT_STREAM_DATA 0
#endif

#include <stdbool.h> /* macros for a Boolean data type */
#include <termios.h> /* POSIX Terminal Control Definitions (man termios to get more info) */
                     /* https://en.wikibooks.org/wiki/Serial_Programming/termios          */
#include <time.h>    // date and time information

/* DEFAULT SENSORS CONFIGURATION */
/* --------------------------------------------------------------------------------------------------------- */
static const bool sensorsUsed[4] = { true, true, true, true };

// max sensor frequency fSENSOR = 1/(2*pi*sqrt(LC)) = 1/(2*pi*sqrt(18*10^-6 * 53*10^-12)) = 5.15 MHz
static const double parallelInductance  = 18;  // L = 18 muH
static const double parallelCapacitance = 33;  // surface mount capacitance = 33 pF (total capacitance = 53pF)
static const double fCLK = 40;                 // (external) frequency measurement master clock (in MHz)

// TIMING
static const unsigned ch_fin_sel = 1;          // single-ended sensor configuration
static const unsigned ch_fref_divider = 1;     // fREF = fCLK/ch_fref_divider > 4*fSENSOR = 20.6 MHz
static const unsigned iDrive = 17;             // drive current = (default)17 (= 0.196 mA)
static const unsigned ch_settlecount = 10;     // The settle time is (10*16)/fCLK = 4 microsec
// The reference count value (ENOB = log2(16*ch_rcount)), max 2^16-1
// 2048 (>15), 4096 (>16), 8192 (>17), 16384 (>18), 32768 (>19), 65535 (>20)
static const unsigned ch_rcount = 4096;
// FDC2114EVM only: 1 (0 bits shift), 4 (2 bits shift), 8 (3 bits shift), 16 (4 bits shift)
static const unsigned output_gain = 2;
static const unsigned ch_offset = 0;           // should be < fSENSORx_min/fREFx * 2^16

// ERROR_CONFIG
static const bool wd_err2out  = false; // report Watchdog Timeout Error to Output Register (DATA_CHx.ERR_WD)
static const bool ah_warn2out = false; // report Amplitude High Warning to Output Register (DATA_CHx.ERR_AW)
static const bool al_warn2out = false; // report Amplitude Low Warning to Output Register (DATA_CHx.ERR_AW)
static const bool we_err2int  = true; // report Watchdog Timeout Error by asserting INTB pin and STATUS.ERR_WD
static const bool drdy_2int   = true; // report Data Ready Flag by asserting INTB pin and STATUS.DRDY

// MUX_CONFIG
static const bool autoscan_en = true;    // Auto-Scan mode (true -- sequential)
static const char rr_sequence[3] = "10"; // Auto-Scan Sequence Configuration (10 -- Ch0-Ch3)
static const char deglitch[4] = "101";   // Input deglitch filter bandwidth (> fSENSOR)

// CONFIG
static const unsigned active_ch = 0;         // Active Channel Selection when AUTOSCAN_EN = false
static const bool sleep_mode_en = false;     // sleep mode (false -- active)
static const bool sensor_active_sel = false; // Sensor Activation Mode (false -- full current)
static const bool ref_clk_src = true;        // Reference Frequency Source (true -- external by CLKIN pin)
static const bool intb_dis = false;          // INTB Disable (false -- will be asserted when status register updates)
static const bool high_current_drv = false;  // High Current Sensor Drive (false -- normal sensor current)
/* --------------------------------------------------------------------------------------------------------- */

static const unsigned sampleTimeMinDelay = 100; // min sample delay [ms] at scanChannels (for ENOB < 20)

// drive current (in mA)
static const double driveCurrent[32] = {
	0.016, 0.018, 0.021, 0.025, 0.028, 0.033, 0.038, 0.044, 0.052, 0.060, 0.069,
	0.081, 0.093, 0.108, 0.126, 0.146, 0.169, 0.196, 0.228, 0.264, 0.307, 0.356,
	0.413, 0.479, 0.555, 0.644, 0.747, 0.867, 1.006, 1.167, 1.354, 1.571
};

// Address 0x18
typedef struct deviceStatus {
	/* Indicates which channel has generated a Flag or Error. Once flagged, any reported error is
	 * latched and maintained until either the STATUS register or the DATA_CHx register corresponding
	 * to the Error Channel is read:
	 * 00 - Ch0, 01 - Ch1, 10 - Ch2, 11 - Ch3 */
	char err_chan[3];
	bool err_wd;           // Watchdog Timeout error
	bool err_ahw;          // Amplitude High Warning
	bool err_alw;          // Amplitude Low Warning
	bool drdy;             // Data Ready Flag
	bool ch_unreadconv[4]; // Channels 0-3 Unread Conversion present 
} deviceStatus;

// Address 0x19
typedef struct deviceErrorConfig {
	bool wd_err2out;  // report Watchdog Timeout Error to Output Register (DATA_CHx.ERR_WD)
	bool ah_warn2out; // report Amplitude High Warning to Output Register (DATA_CHx.ERR_AW)
	bool al_warn2out; // report Amplitude Low Warning to Output Register (DATA_CHx.ERR_AW)
	bool we_err2int;  // report Watchdog Timeout Error by asserting INTB pin and STATUS.ERR_WD
	bool drdy_2int;   // report Data Ready Flag by asserting INTB pin and STATUS.DRDY
} deviceErrorConfig;

// Address 0x1A
typedef struct deviceConfig {
	/* Active Channel Selection when MUX_CONFIG.AUTOSCAN_EN = 0
	 * 0 - ch0, 1 - ch1, 2 - ch2, 3 - ch3 */
	unsigned int active_ch;
	/* 0 - device is active, 1 - device in Sleep Mode */
	bool sleep_mode_en;
	/* Sensor Activation Mode:
	 * 0 - Full Current Activation Mode, 1 - Low Power Activation Mode (use DRIVE_CURRENT_CHx) */
	bool sensor_active_sel;
	/* Reference Frequency Source:
	 * 0 - internal oscillator (43.3 MHz Typical), 1 - reference frequency is provided from CLKIN pin (40 MHz) */
	bool ref_clk_src;
	/* 0 (1) - INTB pin will be (NOT) asserted when status register updates */
	bool intb_dis;
	/* High Current Sensor Drive:
	 * 0 - drive all channels with normal sensor current (1.5mA max)
	 * 1 - drive Ch0 with current > 1.5mA (only if MUX_CONFIG.AUTOSCAN_EN = 0) */
	bool high_current_drv;
} deviceConfig;

// Address 0x1B
typedef struct deviceMuxConfig {
	/* Auto-scan Mode:
	 * 0 - Continuous conversion on the single channel selected by CONFIG.ACTIVE_CHAN
	 * 1 - Auto-Scan conversions as selected by MUX_CONFIG.RR_SEQUENCE */
	bool autoscan_en; 
	/* Auto-Scan Sequence Configuration:
	 * 00 - Ch0-Ch1; 01 - Ch0-Ch2; 10 - Ch0-Ch3; 11 - Ch0-Ch1 */
	char rr_sequence[3];
	/* Input deglitch filter bandwidth:
	 * Select the lowest setting that exceeds the oscillation tank oscillation frequency:
	 * 001 - 1MHz; 100 - 3.3MHz; 101 - 10MHz; 111 - 33MHz */
	char deglitch[4];
} deviceMuxConfig;

// push the current alignment setting on an internal stack and then sets the new alignment to 1.
// so, no padding into the data and each member follows the previous one
#pragma pack(push,1)
typedef struct channelsData {
	double frequency[4];
	double totalCapacitance[4];
	double sensorCapacitance[4];
	double rawData[4];
	char   hexData[4][11];
	double recvTime;
	unsigned long id;
} channelsData;
#pragma pack(pop) // restores the alignment setting to the one saved at the top of the internal stack

typedef struct hw_info {
	char *name;
#if defined(__linux__)
	char *sysfs;                             // sysfs entry for this hardware, if any
	char *sysfs_bus;                         // sysfs bus id for this hardware, if any
	char *sysfs_links;
#endif // __linux__
#if defined(__APPLE__)
	char *IOTTYBaseName;                    // "usbmodem"
	unsigned int IOTTYSuffix;               // Location ID
	unsigned int current_required;          // 100 mA
#endif // __APPLE__
  unsigned int vid, pid, rev;              // vid = 0x2047, pid = 0x08f8
  char *manufact, *product, *serialNumber; // Texas_Instruments, MSP430-USB_Example
	char *driver;                            // currently active driver
	unsigned int bus, addr;
  unsigned int major, minor;
  unsigned int speed;
} hw_info_t;

typedef struct serialDevice {
	char *name;             // device path
	char *sysPath;          // libusb bus location
	char *serialNumber;     // S/N if present
	time_t ctime;           // system time when device was attached

	hw_info_t hwInfo;

	int fd;                 // POSIX file descriptor

	bool sensorsUsed[4];

	bool beVerbose;
	bool isOpen;
	bool isSleeping;        // 0 - active, 1 - sleeping
	bool isStreaming;

	deviceStatus status;

	channelsData data;

	deviceErrorConfig errConfig;
	deviceConfig config;
	deviceMuxConfig muxConfig;

	// NOTE: max sensor frequency fSENSOR = 1/(2*pi*sqrt(LC)) = 1/(2*pi*sqrt(18*10^-6 * 53*10^-12)) = 5.15 MHz
	double parallelInductance;       // L = (default)18 muH
	double parallelCapacitance;      // surface mount capacitance = (default)33 pF (total capacitance = 53pF)
	double fCLK;                     // (external) frequency measurement master clock

	// Clock configuration
	unsigned int ch_rcount[4];       // CHx Reference Count Conversion Interval Time
	unsigned int ch_settlecount[4];  // CHx Converion Setting
	unsigned int ch_fin_sel[4];      // CHx Sensor frequency configuration select (= 1 or 2)
	unsigned int ch_fref_divider[4]; // CHx Reference Divider (use to scale max conversion frequency)

	double sampleTime;               // = ch_number * (setting_time + ch_switch_delay + converision_time) [ms]
	double switchDelay[4];           // CHx switch delay [micro sec]
	double settleTime[4];            // CHx settle count [micro sec]
	double converionTime[4];         // CHx converion time [micro sec]
	unsigned int ENOB[4];            // number of required effective bits

	unsigned int ch_offset[4];       // CHx Conversion Offset. fOFFSET = (ch_offset/2^16)*fREF
	unsigned int output_gain;        // Output gain control (FDC2114 only)

	unsigned int iDrive[4];          // drive current per channel = (default)17 (= 0.196 mA)

	struct termios saved_attributes;

	short manufacturer_id;           // 5449 (Texas Instruments)
	short device_id;                 // 3055 (FDC2212, FDC2214 only), 3054 (FDC2112, FDC2114 only)

	// last registers values [FDC2x14EVM_cmd.h defines the register ordering. NOTE: register[29=0x1D] is always 0]
	unsigned short int registers[35];
} serialDevice;


int scanChannels(serialDevice *dev, unsigned long tDelay); // sample time delay in ms

double startDeviceStreaming(serialDevice *dev);
double stopDeviceStreaming(serialDevice *dev);
int getDeviceStreamingData(serialDevice *dev);

int sleepMode(serialDevice *dev);
int activeMode(serialDevice *dev);

int getDeviceConfigs(serialDevice *dev);
int setDeviceConfigs(serialDevice *dev);

// Addresses 0x08, 0x09, 0x0A, 0x0B
int getRCount(serialDevice *dev);
int setRCount(serialDevice *dev);
// Addresses 0x10, 0x11, 0x12, 0x13
int getSettleCount(serialDevice *dev);
int setSettleCount(serialDevice *dev);
// Addresses 0x14, 0x15, 0x16, 0x17
int getClockDividers(serialDevice *dev);
int setClockDividers(serialDevice *dev);
// Addresses 0x08, 0x09, 0x0A, 0x0B, 0x10 -- 0x17
int getClockConfigs(serialDevice *dev);

/*
 * An offset value maybe subtrackted from each DATA value to compensate for a frequency offset or maximize the
 * dynamic range of the sample data. The offset values should be < fSENSOR/fREF. The offset is zero for FDC2214.
 */
// Addresses 0x0C, 0x0D, 0x0E, 0x0F
int getOffset(serialDevice *dev);
int setOffset(serialDevice *dev);

// Address 0x18, fill STATUS fields at serialDevice
int getStatus(serialDevice *dev);
// Address 0x19
int getErrorConfig(serialDevice *dev);
int setErrorConfig(serialDevice *dev);
// Address 0x1A
int getConfig(serialDevice *dev);
int setConfig(serialDevice *dev);
// Address 0x1B
int getMuxConfig(serialDevice *dev);
int setMuxConfig(serialDevice *dev);
// Addresses 0x1E, 0x1F, 0x20, 0x21
int getDriveCurrent(serialDevice *dev);
int setDriveCurrent(serialDevice *dev);

// Address 0x1C
int resetDevice(serialDevice *dev);
/*
 * FDC2114 only: allow access to the 4 LSBs of the original 16-bit result (12-bits only reported)
 * for systems in which the sensor signal variation is less than 25% of the full-scale range.
 */
int getOutputGain(serialDevice *dev); // FDC2114 only
int setOutputGain(serialDevice *dev); // FDC2114 only

// Address 0x7F, DEVICE_ID. 3055 (FDC2212, FDC2214 only), 3054 (FDC2112, FDC2114 only)
short getDeviceID(serialDevice *dev);
// Address 0x7E, Manufacturer ID (Texas Instruments) = 5449
short getManufacturerID(serialDevice *dev);

int readAllRegisters(serialDevice *dev);

int readRegister(serialDevice *dev, const char *addr, char *data);
int writeRegister(serialDevice *dev, const char *addr, const char *data);
double sendCommand(const int fd, const char *hexSend, const char *errorMessage);

// query data into hexRecv[32*2+1]; // it is always 65 char response
int queryData(const int fd, char *hexRecv, const char *hexSend, const bool addCRC8, const char* errorMessage);

// Open the serial port
int open_device(serialDevice *dev, unsigned int baudRate);
// Close the serial port
int close_device(serialDevice *dev);
// Setting the attributes of the serial port using termios structure
int set_interface_attribs(const int fd, unsigned int baudRate);
// check if the fileDescriptor is valid
int fd_isValid(int fd);
// free memory
void free_hwInfo(hw_info_t *hwInfo);
void freeSerialDevice(serialDevice *dev);

#endif /* __FDC2x14EVM_H_ */
