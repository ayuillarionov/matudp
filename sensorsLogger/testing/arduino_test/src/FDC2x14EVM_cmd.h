#ifndef __FDC2x14EVM_CMD_H_
#define __FDC2x14EVM_CMD_H_

#define READ_HEADER  "4C120100032A"  // Read  register command header
#define WRITE_HEADER "4C130100042A"  // Write register command header

#define START_STREAMING "4C0501000601000104302A" // Continuously output data from device to serial port
#define STOP_STREAMING  "4C07010000"             // Stop the streaming

/* http://www.ti.com/product/MSP430F5528
 * MSP430F5528IRGC addressing space  ---  default values */
#define DATA_MSB_CH0        "00" // 0000 - Channel 0 MSB Conversion Result and status
#define DATA_LSB_CH0        "01" // 0000 - Channel 0 LSB Conversion Result and status
#define DATA_MSB_CH1        "02" // 0000 - Channel 1 MSB Conversion Result and status
#define DATA_LSB_CH1        "03" // 0000 - Channel 1 LSB Conversion Result and status
#define DATA_MSB_CH2        "04" // 0000 - Channel 2 MSB Conversion Result and status
#define DATA_LSB_CH2        "05" // 0000 - Channel 2 LSB Conversion Result and status
#define DATA_MSB_CH3        "06" // 0000 - Channel 3 MSB Conversion Result and status
#define DATA_LSB_CH3        "07" // 0000 - Channel 3 LSB Conversion Result and status
#define RCOUNT_CH0          "08" // ffff - Reference Count setting for Channel 0 (max ffff - 26214.10us)
#define RCOUNT_CH1          "09" // ffff - Reference Count setting for Channel 1
#define RCOUNT_CH2          "0A" // ffff - Reference Count setting for Channel 2
#define RCOUNT_CH3          "0B" // ffff - Reference Count setting for Channel 3
#define OFFSET_CH0          "0C" // 0000 - Offset value for Channel 0
#define OFFSET_CH1          "0D" // 0000 - Offset value for Channel 1
#define OFFSET_CH2          "0E" // 0000 - Offset value for Channel 2
#define OFFSET_CH3          "0F" // 0000 - Offset value for Channel 3
#define SETTLECOUNT_CH0     "10" // 0400 - Channel 0 Settling Reference Count (= 1024 (409.6us))
#define SETTLECOUNT_CH1     "11" // 0400 - Channel 1 Settling Reference Count
#define SETTLECOUNT_CH2     "12" // 0400 - Channel 2 Settling Reference Count
#define SETTLECOUNT_CH3     "13" // 0400 - Channel 3 Settling Reference Count
#define CLOCK_DIVIDERS_CH0  "14" // 1001 - Reference divider settings for Channel 0
#define CLOCK_DIVIDERS_CH1  "15" // 1001 - Reference divider settings for Channel 1
#define CLOCK_DIVIDERS_CH2  "16" // 1001 - Reference divider settings for Channel 2
#define CLOCK_DIVIDERS_CH3  "17" // 1001 - Reference divider settings for Channel 3
#define STATUS              "18" // 0000 - Device Status Reporting
#define ERROR_CONFIG        "19" // 0001 - Device Status Reporting Configuration
#define CONFIG              "1A" // 1601 - Conversion Configuration
#define MUX_CONFIG          "1B" // c209 - Channel Multiplexing Configuration
#define RESET_DEV           "1C" // 0000 - Reset Device
#define DRIVE_CURRENT_CH0   "1E" // 8c40 - Channel 0 sensor current drive configuration
#define DRIVE_CURRENT_CH1   "1F" // 8c40 - Channel 1 sensor current drive configuration
#define DRIVE_CURRENT_CH2   "20" // 8c40 - Channel 2 sensor current drive configuration
#define DRIVE_CURRENT_CH3   "21" // 8c40 - Channel 3 sensor current drive configuration
#define MANUFACTURER_ID     "7E" // 5449 - Manufacturer ID (Texas Instruments)
#define DEVICE_ID           "7F" // 3055 - Device ID (FDC2212, FDC2214 only), 3054 (FDC2112, FDC2114 only)

#endif /* __FDC2x14EVM_CMD_H_ */
