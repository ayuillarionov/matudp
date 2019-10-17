/*
 * File Name : FDC2x14EVM.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Mon 19 Nov 2018 02:32:23 PM CET
 * Modified  : Wed 20 Feb 2019 01:13:39 PM CET
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-39-lowlatency x86_64 x86_64
 *
 * Purpose   :  FDC2x14EVM (MSP430 microcontroller) serial communication
 *              The MSP430 microcontroller is used to interface the FDC to a host computer through USB interface.
 *              http://e2e.ti.com/support/sensor/inductive-sensing/f/938/t/295036#Q41
 */

#include "errors.h"
#include "timer.h"

#include <fcntl.h>   /* File Control Definitions (O_RDWR, O_NOCTTY, O_NDELAY etc.) */
#include <termios.h> /* POSIX Terminal Control Definitions (man termios to get more info) */
                     /* https://en.wikibooks.org/wiki/Serial_Programming/termios          */

#include <float.h>  /* Characteristics of floating-point types */
#include <math.h>   /* Math library */

#include "FDC2x14EVM_cmd.h"
#include "FDC2x14EVM.h"
#include "crc8.h"


/* baudrate settings are defined in <asm/termbits.h>, which is included by <termios.h> */
#if defined(__linux__)
	#define BAUDRATE B1000000 // 010010
	#define ctz  __builtin_ctz
#elif defined(__APPLE__) && defined(__MACH__)
	#define BAUDRATE B230400
	#define ctz  __builtin_ctz
#elif defined(_WIN64)       // Microsoft Windows (64-bit)
	#include <windows.h>
	#define _USE_MATH_DEFINES
#endif

/* sleepTime between send/read:  approx 10 uS per char transmit */
#define sleepTime 0

/* Use this variable to remember original terminal attributes */
struct termios saved_attributes;

int calculatedSensorData(serialDevice *dev) {
	for (int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] && fabs(dev->data.rawData[i]) > DBL_MIN ) {
			if (dev->device_id == DEVICE_FDC2214)
				dev->data.frequency[i] = dev->ch_fin_sel[i]/dev->ch_fref_divider[i] * dev->fCLK
					* dev->data.rawData[i] / 268435456.;
			else if (dev->device_id == DEVICE_FDC2114) {
				dev->data.frequency[i] = dev->ch_fin_sel[i]/dev->ch_fref_divider[i] * dev->fCLK
					* (dev->data.rawData[i]/4096/dev->output_gain + (double)dev->ch_offset[i]/65536);
				if (dev->data.rawData[i] >= 4095)
					fprintf(stderr, "\tWarning: Channel %i of %s is saturated\n", i, dev->name);
			} else
				return -1;

			// fSENSOR = 1/(2*pi*sqrt(LC))
			dev->data.totalCapacitance[i] = 1/pow(2*M_PI*dev->data.frequency[i],2) / dev->parallelInductance * 1000000;
			dev->data.sensorCapacitance[i] = dev->data.totalCapacitance[i] - dev->parallelCapacitance;
		} else {
			dev->data.frequency[i] = 0;
			dev->data.totalCapacitance[i] = 0;
			dev->data.sensorCapacitance[i] = 0;
		}
	}
	return 0;
}

double startDeviceStreaming(serialDevice *dev) {
	double tcom;

	activeMode(dev); // Wake up if sleeping

	if ( !dev->isStreaming ) {
		tcom = sendCommand(dev->fd, START_STREAMING, "startStreaming");
		if (tcom >= 0)
			dev->isStreaming = true;
		tcflush(dev->fd, TCIFLUSH); /* discards old data in the Rx buffer */
	} else {
		fprintf(stderr, "\t%s is already streaming", dev->name);
		return -1;
	}

	return tcom;
}

double stopDeviceStreaming(serialDevice *dev) {
	double tcom;

	if ( dev->isStreaming ) {
		tcom = sendCommand(dev->fd, STOP_STREAMING, "stopStreaming");
		if (tcom >= 0)
			dev->isStreaming = false;
		tcflush(dev->fd, TCIFLUSH); /* discards old data in the Rx buffer */
	} else {
		fprintf(stderr, "\t%s is already stop streaming", dev->name);
		return -1;
	}

	return tcom;
}

int getDeviceStreamingData(serialDevice *dev) {
	if ( !dev->isStreaming )
		startDeviceStreaming(dev);

	char asciiRecv[RECV_SIZE], hexRecv[HEX_RECV_SIZE]; // it is always 32 ascii char response --> 65 hex char
	if ( read(dev->fd, asciiRecv, RECV_SIZE) == RECV_SIZE ) // returns after 32 chars have been input
		asciiToHex(hexRecv, HEX_RECV_SIZE, asciiRecv);   // convert ascii into hex
	else
		return -1;

	for (int i = 0; i < 4; i++) {
		strncpy(dev->data.hexData[i], "0x", 2);
		if (dev->device_id == DEVICE_FDC2214)
			strncpy(&(dev->data.hexData[i])[2], &hexRecv[12+i*8], 8);
		else if (dev->device_id == DEVICE_FDC2114) {
			strncpy(&(dev->data.hexData[i])[2], &hexRecv[12+i*8], 4);
		}
		// convert 0x string to double according to the given base
		dev->data.rawData[i] = (double)strtoul(dev->data.hexData[i], NULL, 16);
	}

	// frequency, total capacitance, sensor capacitance
	calculatedSensorData(dev);

	dev->data.recvTime = getTime()*1e-6; // in msec

	if (DEBUG_PRINT_STREAM_DATA) {
		printf("hexRecv: 0x%s (nchars = %ld)\n", hexRecv, strlen(hexRecv));
		printf("Channels hexData:\t %s\t %s\t %s\t %s\n",
				dev->data.hexData[0], dev->data.hexData[1], dev->data.hexData[2], dev->data.hexData[3]);
		printf("Channels rawData:\t %.0f\t %.0f\t %.0f\t %.0f\t (time = %.6f [msec])\n",
				dev->data.rawData[0], dev->data.rawData[1], dev->data.rawData[2], dev->data.rawData[3],
				dev->data.recvTime);
		printf("Channels frequency:\t %f\t %f\t %f\t %f\n",
				dev->data.frequency[0], dev->data.frequency[1], dev->data.frequency[2], dev->data.frequency[3]);
		printf("Channels sensor caps:\t %f\t %f\t %f\t %f\n",
				dev->data.sensorCapacitance[0], dev->data.sensorCapacitance[1],
			 	dev->data.sensorCapacitance[2], dev->data.sensorCapacitance[3]);
	}

	return 0;
}

int scanChannels(serialDevice *dev, unsigned long tDelay) {
	
	bool ready = false;
  while ( !ready ) {
		if (dev->sampleTime > tDelay)
			usleep((int)((dev->sampleTime+0.5) * 1e3));
		else
			usleep(tDelay * 1e3);

		if ( getStatus(dev) < 0 ) return -1;
		//ready = dev->status.drdy;
		ready = (
				( dev->status.ch_unreadconv[0] == dev->sensorsUsed[0]) &&
				( dev->status.ch_unreadconv[1] == dev->sensorsUsed[1]) &&
				( dev->status.ch_unreadconv[2] == dev->sensorsUsed[2]) &&
				( dev->status.ch_unreadconv[3] == dev->sensorsUsed[3]) );
  }
	
	if ( dev->status.drdy ) { // new conversion result is ready
		for (int i = 0; i < 4; i++) {
			if ( dev->status.ch_unreadconv[i] && dev->sensorsUsed[i] ) { // unread conversion is present for channel i
				strncpy(dev->data.hexData[i], "0x", 2);
				switch (i) {
					case 0:
						readRegister(dev, DATA_MSB_CH0, &(dev->data.hexData[i])[2]);
						if (dev->device_id == DEVICE_FDC2214)
							readRegister(dev, DATA_LSB_CH0, &(dev->data.hexData[i])[6]);
						break;
					case 1:
						readRegister(dev, DATA_MSB_CH1, &(dev->data.hexData[i])[2]);
						if (dev->device_id == DEVICE_FDC2214)
							readRegister(dev, DATA_LSB_CH1, &(dev->data.hexData[i])[6]);
						break;
					case 2:
						readRegister(dev, DATA_MSB_CH2, &(dev->data.hexData[i])[2]);
						if (dev->device_id == DEVICE_FDC2214)
							readRegister(dev, DATA_LSB_CH2, &(dev->data.hexData[i])[6]);
						break;
					case 3:
						readRegister(dev, DATA_MSB_CH3, &(dev->data.hexData[i])[2]);
						if (dev->device_id == DEVICE_FDC2214)
							readRegister(dev, DATA_LSB_CH3, &(dev->data.hexData[i])[6]);
						break;
				}
			}	else {
				strncpy(dev->data.hexData[i], "0x0", 3);
			}
			// convert 0x string into double according to the given base
			dev->data.rawData[i] = (double)strtoul(dev->data.hexData[i], NULL, 16);
		}
		// frequency, total capacitance, sensor capacitance
		if ( calculatedSensorData(dev) ) return -1;
	}

	dev->data.recvTime = getTime()*1e-6; // in msec

	if (DEBUG_PRINT_SCAN_DATA) {
		printf("Channels hexData:\t %s\t %s\t %s\t %s\t (time = %.6f msec)\n",
				dev->data.hexData[0], dev->data.hexData[1], dev->data.hexData[2], dev->data.hexData[3],
				dev->data.recvTime);
		printf("Channels rawData:\t %.0f\t %.0f\t %.0f\t %.0f\n",
				dev->data.rawData[0], dev->data.rawData[1], dev->data.rawData[2], dev->data.rawData[3]);
		printf("Channels frequency:\t %f\t %f\t %f\t %f\n",
				dev->data.frequency[0], dev->data.frequency[1], dev->data.frequency[2], dev->data.frequency[3]);
		printf("Channels sensor caps:\t %f\t %f\t %f\t %f\n\n",
				dev->data.sensorCapacitance[0], dev->data.sensorCapacitance[1],
			 	dev->data.sensorCapacitance[2], dev->data.sensorCapacitance[3]);
	}

	return 0;
}

int sleepMode(serialDevice *dev) {
	if ( !dev->isSleeping ) {
		dev->config.sleep_mode_en = true;
		int status = setConfig(dev);
		if (status > 0)
			sleep(0.05*1e-3); // pause thread for 0.05 msec
		return status; 
	}
	return 0;
}

int activeMode(serialDevice *dev) {
	if ( dev->isSleeping ) {
		dev->config.sleep_mode_en = false;
		return setConfig(dev);
	}
	return 0;
}

const char *boolstring( _Bool b ) { return b ? "1" : "0"; }

bool statusFieldValue(char *status, unsigned int pos) {
	switch ((char)status[pos]) {
		case '1':
			return true;
		case '0':
		default:
			return false;
	}
}

// Addresses 0x08, 0x09, 0x0A, 0x0B
int getRCount_ch(serialDevice *dev, unsigned int iChannel) {
	char *buf = calloc(7, sizeof(char));
	strncpy(buf, "0x", 2);

	switch (iChannel) {
		case 0:
			if ( readRegister(dev, RCOUNT_CH0, &buf[2]) < 0 ) return -1;
			break;
		case 1:
			if ( readRegister(dev, RCOUNT_CH1, &buf[2]) < 0 ) return -1;
			break;
		case 2:
			if ( readRegister(dev, RCOUNT_CH2, &buf[2]) < 0 ) return -1;
			break;
		case 3:
			if ( readRegister(dev, RCOUNT_CH3, &buf[2]) < 0 ) return -1;
			break;
	}
	dev->ch_rcount[iChannel] = strtoul(buf, NULL, 16);

	free(buf);
	return 0;
}

int getRCount(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( getRCount_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

int setRCount_ch(serialDevice *dev, unsigned int iChannel) {
	char *buf = calloc(5, sizeof(char));
	char tmp[4];

	ulToStr(dev->ch_rcount[iChannel], tmp, 16);
	size_t len = strlen(tmp);
	// ensure that buf is the 4-char hex string
	strncpy(buf, "0000", 4-len);
	strncpy(&buf[4-len], tmp, len);

	switch (iChannel) {
		case 0:
			if ( writeRegister(dev, RCOUNT_CH0, buf) < 0 ) return -1;
			break;
		case 1:
			if ( writeRegister(dev, RCOUNT_CH1, buf) < 0 ) return -1;
			break;
		case 2:
			if ( writeRegister(dev, RCOUNT_CH2, buf) < 0 ) return -1;
			break;
		case 3:
			if ( writeRegister(dev, RCOUNT_CH3, buf) < 0 ) return -1;
			break;
	}

	free(buf);
	return 0;
}

int setRCount(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( setRCount_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

// Addresses 0x10, 0x11, 0x12, 0x13
int getSettleCount_ch(serialDevice *dev, unsigned int iChannel) {
	char *buf = calloc(7, sizeof(char));
	strncpy(buf, "0x", 2);

	switch (iChannel) {
		case 0:
			if ( readRegister(dev, SETTLECOUNT_CH0, &buf[2]) < 0 ) return -1;
			break;
		case 1:
			if ( readRegister(dev, SETTLECOUNT_CH1, &buf[2]) < 0 ) return -1;
			break;
		case 2:
			if ( readRegister(dev, SETTLECOUNT_CH2, &buf[2]) < 0 ) return -1;
			break;
		case 3:
			if ( readRegister(dev, SETTLECOUNT_CH3, &buf[2]) < 0 ) return -1;
			break;
	}
	dev->ch_settlecount[iChannel] = strtoul(buf, NULL, 16);

	free(buf);
	return 0;
}

int getSettleCount(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( getSettleCount_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

int setSettleCount_ch(serialDevice *dev, unsigned int iChannel) {
	char *buf = calloc(5, sizeof(char));
	char tmp[4];

	ulToStr(dev->ch_settlecount[iChannel], tmp, 16);
	size_t len = strlen(tmp);
	// ensure that buf is the 4-char hex string
	strncpy(buf, "0000", 4-len);
	strncpy(&buf[4-len], tmp, len);

	switch (iChannel) {
		case 0:
			if ( writeRegister(dev, SETTLECOUNT_CH0, buf) < 0 ) return -1;
			break;
		case 1:
			if ( writeRegister(dev, SETTLECOUNT_CH1, buf) < 0 ) return -1;
			break;
		case 2:
			if ( writeRegister(dev, SETTLECOUNT_CH2, buf) < 0 ) return -1;
			break;
		case 3:
			if ( writeRegister(dev, SETTLECOUNT_CH3, buf) < 0 ) return -1;
			break;
	}

	free(buf);
	return 0;
}

int setSettleCount(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( setSettleCount_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

// Addresses 0x14, 0x15, 0x16, 0x17
int getClockDividers_ch(serialDevice *dev, unsigned int iChannel) {
	char buf[5], bin[17];

	switch (iChannel) {
		case 0:
			if ( readRegister(dev, CLOCK_DIVIDERS_CH0, buf) < 0 ) return -1;
			break;
		case 1:
			if ( readRegister(dev, CLOCK_DIVIDERS_CH1, buf) < 0 ) return -1;
			break;
		case 2:
			if ( readRegister(dev, CLOCK_DIVIDERS_CH2, buf) < 0 ) return -1;
			break;
		case 3:
			if ( readRegister(dev, CLOCK_DIVIDERS_CH3, buf) < 0 ) return -1;
			break;
	}
	hexToBin(bin, 17, buf);

	dev->ch_fref_divider[iChannel] = (int)strtoul(&bin[6], NULL, 2); // >= 1

	if ( strncmp(&buf[2], "01", 2) == 0 )
		dev->ch_fin_sel[iChannel] = 1;
	else if ( strncmp(&buf[2], "10", 2) == 0 )
		dev->ch_fin_sel[iChannel] = 2;
	else
		dev->ch_fin_sel[iChannel] = -1;

	return 0;
}

int getClockDividers(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( getClockDividers_ch(dev, i) < 0 )
			return -1;
	}
	return 0;
}

int setClockDividers_ch(serialDevice *dev, unsigned int iChannel) {
	char *bin = calloc(17, sizeof(char));
	char *buf = calloc(5, sizeof(char));
	char tmp[11];

	if ( dev->ch_fin_sel[iChannel] == 1 )
		strncpy(bin, "000100\0", 7);
	else if ( dev->ch_fin_sel[iChannel] == 2 )
		strncpy(bin, "001000\0", 7);
	else
		return -1;

	ulToStr(dev->ch_fref_divider[iChannel], tmp, 2); // max frequency scale
	size_t len = strlen(tmp);

	strncat(bin, "000000000", 10-len);
	strncat(bin, tmp, len);

	binToHex(buf, 5, bin);
	switch (iChannel) {
		case 0:
			if ( writeRegister(dev, CLOCK_DIVIDERS_CH0, buf) < 0 ) return -1;
			break;
		case 1:
			if ( writeRegister(dev, CLOCK_DIVIDERS_CH1, buf) < 0 ) return -1;
			break;
		case 2:
			if ( writeRegister(dev, CLOCK_DIVIDERS_CH2, buf) < 0 ) return -1;
			break;
		case 3:
			if ( writeRegister(dev, CLOCK_DIVIDERS_CH3, buf) < 0 ) return -1;
			break;
	}

	free(buf); free(bin);
	return 0;
}

int setClockDividers(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( setClockDividers_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}


int getClockConfigs(serialDevice *dev) {
	if ( getRCount(dev) )        return -1;
	if ( getSettleCount(dev) )   return -1;
	if ( getClockDividers(dev) ) return -1;

	dev->sampleTime = 0;
	for (int i = 0; i < 4; i++) {
		// channel switch delay [micro sec]
		dev->switchDelay[i] = 692*1e-3 + 5/dev->fCLK * dev->ch_fref_divider[i];
		// channel settle count [micro sec]
		dev->settleTime[i] = 16/dev->fCLK * dev->ch_fref_divider[i] * dev->ch_settlecount[i];
		// channel converion time [micro sec]
		dev->converionTime[i] = 16/dev->fCLK * dev->ch_fref_divider[i] * dev->ch_rcount[i];
		// number of effective bits
		dev->ENOB[i] = round(log2(16 * dev->ch_rcount[i]));

		if ( dev->sensorsUsed[i] )
			dev->sampleTime += (dev->converionTime[i] + dev->settleTime[i] + dev->switchDelay[i]) / 1e3; // [ms]
	}

	if (dev->beVerbose)
		printf("Default sample time on %s is %f[ms]\n", dev->name, dev->sampleTime);

	return 0;
}

// Addresses 0x0C, 0x0D, 0x0E, 0x0F
int getOffset_ch(serialDevice *dev, unsigned int iChannel) {
	if (dev->device_id != DEVICE_FDC2114) { // only for FDC2114
		dev->ch_offset[iChannel] = 0;
	} else {
		char *buf = calloc(7, sizeof(char));
		strncpy(buf, "0x", 2);

		switch (iChannel) {
			case 0:
				if ( readRegister(dev, OFFSET_CH0, &buf[2]) < 0 ) return -1;
				break;
			case 1:
				if ( readRegister(dev, OFFSET_CH1, &buf[2]) < 0 ) return -1;
				break;
			case 2:
				if ( readRegister(dev, OFFSET_CH2, &buf[2]) < 0 ) return -1;
				break;
			case 3:
				if ( readRegister(dev, OFFSET_CH3, &buf[2]) < 0 ) return -1;
				break;
		}
		dev->ch_offset[iChannel] = strtoul(buf, NULL, 16);
		free(buf);
	}
	return 0;
}

int getOffset(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( getOffset_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

int setOffset_ch(serialDevice *dev, unsigned int iChannel) {
	if (dev->device_id != DEVICE_FDC2114) { // only for FDC2114
		fprintf(stderr, "\n\tWarning: The frequency offsets is not applicable to %d devices.\n", dev->device_id);
	} else {
		char *buf = calloc(5, sizeof(char));
		char tmp[4];

		ulToStr(dev->ch_offset[iChannel], tmp, 16);
		size_t len = strlen(tmp);
		// ensure that buf is the 4-char hex string
		strncpy(buf, "0000", 4-len);
		strncpy(&buf[4-len], tmp, len);

		switch (iChannel) {
			case 0:
				if ( writeRegister(dev, OFFSET_CH0, buf) < 0 ) return -1;
				break;
			case 1:
				if ( writeRegister(dev, OFFSET_CH1, buf) < 0 ) return -1;
				break;
			case 2:
				if ( writeRegister(dev, OFFSET_CH2, buf) < 0 ) return -1;
				break;
			case 3:
				if ( writeRegister(dev, OFFSET_CH3, buf) < 0 ) return -1;
				break;
		}

		free(buf);
	}
	return 0;
}

int setOffset(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( setOffset_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

// Address 0x18, feel STATUS fields at serialDevice
int getStatus(serialDevice *dev) {
	char buf[5], bin[17];

	if ( readRegister(dev, STATUS, buf) < 0 ) // default 0000
		return -1;

	hexToBin(bin, 17, buf);

	if (DEBUG_PRINT_SCAN_DATA)
		printf("Status: %s => %s: ch=%.*s wd=%.*s ahw=%.*s alw=%.*s drdy=%.*s conv=%.*s (time = %f)\n", buf, bin,
				2, bin, 1, bin+4, 1, bin+5, 1, bin+6, 1, bin+9, 4, bin+12, getTime_msec());

	strncpy(dev->status.err_chan, bin, 2);          // Indicates which channel has generated a Flag or Error
	dev->status.err_wd  = statusFieldValue(bin, 4); // Watchdog Timeout error
	dev->status.err_ahw = statusFieldValue(bin, 5); // Amplitude High Warning
	dev->status.err_alw = statusFieldValue(bin, 6); // Amplitude Low Warning
	dev->status.drdy    = statusFieldValue(bin, 9); // Data Ready Flag
	for (int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] ) {
			dev->status.ch_unreadconv[i] = statusFieldValue(bin, 12+i); // Channel i Unread Conversion presence
		} else {
			dev->status.ch_unreadconv[i] = false;
		}
	}

	return 0;
}

// Address 0x19
int getErrorConfig(serialDevice *dev) {
	char buf[5], bin[17];

	if ( readRegister(dev, ERROR_CONFIG, buf) < 0 ) // default 0001
		return -1;

	hexToBin(bin, 17, buf);

	dev->errConfig.wd_err2out = statusFieldValue(bin, 2);  // report Watchdog Timeout Error
	dev->errConfig.ah_warn2out = statusFieldValue(bin, 3); // report Amplitude High Warning
	dev->errConfig.al_warn2out = statusFieldValue(bin, 4); // report Amplitude Low Warning
	dev->errConfig.we_err2int = statusFieldValue(bin, 10); // report Watchdog Timeout Error by asserting INTB pin
	dev->errConfig.drdy_2int = statusFieldValue(bin, 15);  // report Data Ready Flag by asserting INTB pin

	return 0;
}

int setErrorConfig(serialDevice *dev) {
	char *bin = calloc(17,  sizeof(char));

	strncpy(&bin[0], "00", 2);
	strncpy(&bin[2], boolstring(dev->errConfig.wd_err2out), 1);
	strncpy(&bin[3], boolstring(dev->errConfig.ah_warn2out), 1);
	strncpy(&bin[4], boolstring(dev->errConfig.al_warn2out), 1);
	strncpy(&bin[5], "00000", 5);
	strncpy(&bin[10], boolstring(dev->errConfig.we_err2int), 1);
	strncpy(&bin[11], "0000", 4);
	strncpy(&bin[15], boolstring(dev->errConfig.drdy_2int), 1);

	char *buf = calloc(5, sizeof(char));
	binToHex(buf, 5, bin);

	if ( writeRegister(dev, ERROR_CONFIG, buf) < 0 )
		return -1;

	free(buf); free(bin);
	return 0;
}

// Address 0x1A
int getConfig(serialDevice *dev) {
	char buf[5], bin[17];

	if ( readRegister(dev, CONFIG, buf) < 0 ) // default 1601
		return -1;

	hexToBin(bin, 17, buf);

	// Active Channel Selection when AUTOSCAN_EN = false
	dev->config.active_ch = 0;
	if (strncmp(bin, "01", 2) == 0)
    dev->config.active_ch = 1;
	else if (strncmp(bin, "10", 2) == 0)
    dev->config.active_ch = 2;
	else if (strncmp(bin, "11", 2) == 0)
    dev->config.active_ch = 4;

	dev->config.sleep_mode_en = statusFieldValue(bin, 2);     // Sleep Mode
	dev->config.sensor_active_sel = statusFieldValue(bin, 4); // Sensor Activation Mode
	dev->config.ref_clk_src = statusFieldValue(bin, 6);       // Reference Frequency Source
	dev->config.intb_dis = statusFieldValue(bin, 8);          // INTB pin
	dev->config.high_current_drv = statusFieldValue(bin, 9);  // High Current Sensor Drive

	return 0;
}

int setConfig(serialDevice *dev) {
	char *bin = calloc(17,  sizeof(char));

	if (dev->config.active_ch == 0)
		strncpy(&bin[0], "00", 2);
	else if (dev->config.active_ch == 1)
    strncpy(&bin[0], "01", 2);
	else if (dev->config.active_ch == 2)
    strncpy(&bin[0], "10", 2);
	else if (dev->config.active_ch == 3)
    strncpy(&bin[0], "11", 2);

	strncpy(&bin[2], boolstring(dev->config.sleep_mode_en), 1);
	strncpy(&bin[3], "1", 1);
	strncpy(&bin[4], boolstring(dev->config.sensor_active_sel), 1);
	strncpy(&bin[5], "1", 1);
	strncpy(&bin[6], boolstring(dev->config.ref_clk_src), 1);
	strncpy(&bin[7], "0", 1);
	strncpy(&bin[8], boolstring(dev->config.intb_dis), 1);
	strncpy(&bin[9], boolstring(dev->config.high_current_drv), 1);
	strncpy(&bin[10], "000001", 6);

	dev->isSleeping = dev->config.sleep_mode_en;

	char *buf = calloc(5, sizeof(char));
	binToHex(buf, 5, bin);

	if ( writeRegister(dev, CONFIG, buf) < 0 )
		return -1;

	free(buf); free(bin);
	return 0;
}

// Address 0x1B
int getMuxConfig(serialDevice *dev) {
	char buf[5], bin[17];

	if ( readRegister(dev, MUX_CONFIG, buf) < 0 ) // default C209
		return -1;

	hexToBin(bin, 17, buf);

	dev->muxConfig.autoscan_en = statusFieldValue(bin, 0);
	strncpy(dev->muxConfig.rr_sequence, &bin[1], 2);
	strncpy(dev->muxConfig.deglitch, &bin[13], 3);

	return 0;
}

int setMuxConfig(serialDevice *dev) {
	char *bin = calloc(17,  sizeof(char));

	strncpy(&bin[0], boolstring(dev->muxConfig.autoscan_en), 1);
	strncpy(&bin[1], dev->muxConfig.rr_sequence, 2);
	strncpy(&bin[3], "0001000001", 10);
	strncpy(&bin[13], dev->muxConfig.deglitch, 3);

	char *buf = calloc(5, sizeof(char));
	binToHex(buf, 5, bin);

	if ( writeRegister(dev, MUX_CONFIG, buf) < 0 )
		return -1;

	free(buf); free(bin);
	return 0;
}

// Address 0x1E, 0x1F, 0x20, 0x21
int getDriveCurrent_ch(serialDevice *dev, unsigned int iChannel) {
	char buf[5], bin[17];

	switch (iChannel) {
		case 0:
			if ( readRegister(dev, DRIVE_CURRENT_CH0, buf) < 0 ) return -1;
			break;
		case 1:
			if ( readRegister(dev, DRIVE_CURRENT_CH1, buf) < 0 ) return -1;
			break;
		case 2:
			if ( readRegister(dev, DRIVE_CURRENT_CH2, buf) < 0 ) return -1;
			break;
		case 3:
			if ( readRegister(dev, DRIVE_CURRENT_CH3, buf) < 0 ) return -1;
			break;
	}
	hexToBin(bin, 17, buf); bin[5] = '\0';
	dev->iDrive[iChannel] = strtoul(bin, NULL, 2); // 0 -- 31

	return 0;
}

int getDriveCurrent(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( getDriveCurrent_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

int setDriveCurrent_ch(serialDevice *dev, unsigned int iChannel) {
	char *bin = calloc(17, sizeof(char));
	char *buf = calloc(5, sizeof(char));

	char tmp[5];
	ulToStr(dev->iDrive[iChannel], tmp, 2);
	size_t len = strlen(tmp);
	// ensure that buf is the 5-char binary string
	strncpy(bin, "00000", 5-len);
	strncpy(&bin[5-len], tmp, len);

	strncat(&bin[5], "00000000000", 11);
	binToHex(buf, 5, bin);

	switch (iChannel) {
		case 0:
			if ( writeRegister(dev, DRIVE_CURRENT_CH0, buf) < 0 ) return -1;
			break;
		case 1:
			if ( writeRegister(dev, DRIVE_CURRENT_CH1, buf) < 0 ) return -1;
			break;
		case 2:
			if ( writeRegister(dev, DRIVE_CURRENT_CH2, buf) < 0 ) return -1;
			break;
		case 3:
			if ( writeRegister(dev, DRIVE_CURRENT_CH3, buf) < 0 ) return -1;
			break;
	}

	free(buf); free(bin);
	return 0;
}

int setDriveCurrent(serialDevice *dev) {
	for (unsigned int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] )
			if ( setDriveCurrent_ch(dev, i) < 0 )
				return -1;
	}
	return 0;
}

// Address 0x1C
int resetDevice(serialDevice *dev) {
	fprintf(stderr,
			"\n\n\tWarning: device %s is getting reset!\n\n", dev->name);

	if ( writeRegister(dev, RESET_DEV, "8000") < 0 )
		return -1;

	return 0;
}

int getOutputGain(serialDevice *dev) {
	if (dev->device_id != DEVICE_FDC2114) { // only for FDC2114
		dev->output_gain = 1;
		return 0;
	}

	char buf[5], bin[17];

	if ( readRegister(dev, RESET_DEV, buf) < 0 ) // 0x1C
		return -1;
	
	hexToBin(bin, 17, buf);

	if ( strncmp(&bin[5], "00", 2) == 0 )      // output variation is 100% of full scale (0 bits shift)
		dev->output_gain = 1;
	else if ( strncmp(&bin[5], "01", 2) == 0 ) // output variation is 25% of full scale (2 bits shift)
		dev->output_gain = 4;
	else if ( strncmp(&bin[5], "10", 2) == 0 ) // output variation is 12.5% of full scale (3 bits shift)
		dev->output_gain = 8;
	else if ( strncmp(&bin[5], "11", 2) == 0 ) // output variation is 6.25% of full scale (4 bits shift)
		dev->output_gain = 16;
	else
		dev->output_gain = -1;

	return 0;
}

int setOutputGain(serialDevice *dev) {
	if (dev->device_id != DEVICE_FDC2114) { // only for FDC2114
		fprintf(stderr, "\n\tWarning: The data output gain is not applicable to %d devices.\n", dev->device_id);
		return 0;
	}
	char *bin = calloc(17,  sizeof(char));

	strncpy(bin, "00000\0", 6);
	if ( dev->output_gain == 1 )        // 0 bits shift
		strncat(bin, "00", 2);
	else if ( dev->output_gain == 4 )   // 2 bits shift
    strncat(bin, "01", 2);
	else if ( dev->output_gain == 8 )   // 3 bits shift
    strncat(bin, "10", 2);
	else if ( dev->output_gain == 16 )  // 4 bits shift
    strncat(bin, "11", 2);
	else {
		free(bin); return -1;
	}
	strncat(bin, "000000000", 9);

	char *buf = calloc(5, sizeof(char));
	binToHex(buf, 5, bin);

	if ( writeRegister(dev, RESET_DEV, buf) < 0 )
		return -1;

	free(buf); free(bin);
	return 0;
}

// Address 0x7F, DEVICE_ID. 3055 (FDC2212, FDC2214 only), 3054 (FDC2112, FDC2114 only)
short getDeviceID(serialDevice *dev) {
	char buf[5];
	if ( readRegister(dev, DEVICE_ID, buf) < 0 )
		return -1;
	return (short)atoi(buf);
}

// Address 0x7E, Manufacturer ID (Texas Instruments) = 5449
short getManufacturerID(serialDevice *dev) {
	char buf[5];
	if ( readRegister(dev, MANUFACTURER_ID, buf) < 0 )
		return -1;
	return (short)atoi(buf);
}

int readAllRegisters(serialDevice *dev) {
	char reg[34][4][19];

	memset(reg, '\0', sizeof(reg));

	strncpy(reg[0][0],  "DATA_MSB_CH0", 12);       strncpy(reg[0][1],  DATA_MSB_CH0, 2);
	strncpy(reg[1][0],  "DATA_LSB_CH0", 12);       strncpy(reg[1][1],  DATA_LSB_CH0, 2);
	strncpy(reg[2][0],  "DATA_MSB_CH1", 12);       strncpy(reg[2][1],  DATA_MSB_CH1, 2);
	strncpy(reg[3][0],  "DATA_LSB_CH1", 12);       strncpy(reg[3][1],  DATA_LSB_CH1, 2);
	strncpy(reg[4][0],  "DATA_MSB_CH2", 12);       strncpy(reg[4][1],  DATA_MSB_CH2, 2);
	strncpy(reg[5][0],  "DATA_LSB_CH2", 12);       strncpy(reg[5][1],  DATA_LSB_CH2, 2);
	strncpy(reg[6][0],  "DATA_MSB_CH3", 12);       strncpy(reg[6][1],  DATA_MSB_CH3, 2);
	strncpy(reg[7][0],  "DATA_LSB_CH3", 12);       strncpy(reg[7][1],  DATA_LSB_CH3, 2);
	strncpy(reg[8][0],  "RCOUNT_CH0", 10);         strncpy(reg[8][1],  RCOUNT_CH0, 2);
	strncpy(reg[9][0],  "RCOUNT_CH1", 10);         strncpy(reg[9][1],  RCOUNT_CH1, 2);
	strncpy(reg[10][0], "RCOUNT_CH2", 10);         strncpy(reg[10][1], RCOUNT_CH2, 2);
	strncpy(reg[11][0], "RCOUNT_CH3", 10);         strncpy(reg[11][1], RCOUNT_CH3, 2);
	strncpy(reg[12][0], "OFFSET_CH0", 10);         strncpy(reg[12][1], OFFSET_CH0, 2);
	strncpy(reg[13][0], "OFFSET_CH1", 10);         strncpy(reg[13][1], OFFSET_CH1, 2);
	strncpy(reg[14][0], "OFFSET_CH2", 10);         strncpy(reg[14][1], OFFSET_CH2, 2);
	strncpy(reg[15][0], "OFFSET_CH3", 10);         strncpy(reg[15][1], OFFSET_CH3, 2);
	strncpy(reg[16][0], "SETTLECOUNT_CH0", 15);    strncpy(reg[16][1], SETTLECOUNT_CH0, 2);
	strncpy(reg[17][0], "SETTLECOUNT_CH1", 15);    strncpy(reg[17][1], SETTLECOUNT_CH1, 2);
	strncpy(reg[18][0], "SETTLECOUNT_CH2", 15);    strncpy(reg[18][1], SETTLECOUNT_CH2, 2);
	strncpy(reg[19][0], "SETTLECOUNT_CH3", 15);    strncpy(reg[19][1], SETTLECOUNT_CH3, 2);
	strncpy(reg[20][0], "CLOCK_DIVIDERS_CH0", 18); strncpy(reg[20][1], CLOCK_DIVIDERS_CH0, 2);
	strncpy(reg[21][0], "CLOCK_DIVIDERS_CH1", 18); strncpy(reg[21][1], CLOCK_DIVIDERS_CH1, 2);
	strncpy(reg[22][0], "CLOCK_DIVIDERS_CH2", 18); strncpy(reg[22][1], CLOCK_DIVIDERS_CH2, 2);
	strncpy(reg[23][0], "CLOCK_DIVIDERS_CH3", 18); strncpy(reg[23][1], CLOCK_DIVIDERS_CH3, 2);
	strncpy(reg[24][0], "STATUS", 6);              strncpy(reg[24][1], STATUS, 2);
	strncpy(reg[25][0], "ERROR_CONFIG", 12);       strncpy(reg[25][1], ERROR_CONFIG, 2);
	strncpy(reg[26][0], "CONFIG", 6);              strncpy(reg[26][1], CONFIG, 2);
	strncpy(reg[27][0], "MUX_CONFIG", 10);         strncpy(reg[27][1], MUX_CONFIG, 2);
	strncpy(reg[28][0], "RESET_DEV", 9);           strncpy(reg[28][1], RESET_DEV, 2);
	strncpy(reg[29][0], "DRIVE_CURRENT_CH0", 17);  strncpy(reg[29][1], DRIVE_CURRENT_CH0, 2);
	strncpy(reg[30][0], "DRIVE_CURRENT_CH1", 17);  strncpy(reg[30][1], DRIVE_CURRENT_CH1, 2);
	strncpy(reg[31][0], "DRIVE_CURRENT_CH2", 17);  strncpy(reg[31][1], DRIVE_CURRENT_CH2, 2);
	strncpy(reg[32][0], "DRIVE_CURRENT_CH3", 17);  strncpy(reg[32][1], DRIVE_CURRENT_CH3, 2);
	strncpy(reg[33][0], "DEVICE_ID", 9);           strncpy(reg[33][1], DEVICE_ID, 2);

	printf("\n           Register\tAddress\tCurrentValue\t  Bits\n");
	for (int i = 0; i < 34; i++) {
		if ( readRegister(dev, reg[i][1], reg[i][2]) < 0 ) return -1;
		hexToBin(reg[i][3], 17, reg[i][2]);
		printf("%19s\t%s\t%s\t    %s\n", reg[i][0], reg[i][1], reg[i][2], reg[i][3]);
	}

	return 0;
}

int writeRegister(serialDevice *dev, const char *addr, const char *data) {
	if ( !dev->isOpen ) {
		fprintf(stderr, "\tOpen device fisrt\n");
		return -1;
	}

	size_t headlen = strlen(WRITE_HEADER);
	size_t addrlen = strlen(addr);
	size_t datalen = strlen(data);
	size_t hex_len = headlen + addrlen + datalen + 1;

	char *hexSend = malloc(hex_len * sizeof(char));

	strncpy(hexSend, WRITE_HEADER, headlen);
	strncpy(&hexSend[headlen], addr, addrlen);
	strncpy(&hexSend[headlen+addrlen], data, datalen);
	hexSend[hex_len-1] = '\0'; // add null character

	char msg[19] = "writeRegister (";
	strncat(strncat(msg, addr, 2), ")", 1);

	double tcom = sendCommand(dev->fd, hexSend, msg);

	free(hexSend);
	return (tcom>=0)?0:-1;
}

// NOTE definition: char data[5].
int readRegister(serialDevice *dev, const char *addr, char *data) {
	if ( !dev->isOpen ) {
		fprintf(stderr, "\tOpen device first\n");
		return -1;
	}

	size_t headlen = strlen(READ_HEADER);
	size_t addrlen = strlen(addr);
	size_t hex_len = headlen + addrlen + 3;

	char *hexSend = calloc(hex_len, sizeof(char));

	strncpy(hexSend, READ_HEADER, headlen);
	strncpy(&hexSend[headlen], addr, addrlen);
	strncpy(&hexSend[headlen+addrlen], "02", 2);

	char msg[18] = "readRegister (";
	strncat(strncat(msg, addr, 2), ")", 1);

	char hexRecv[HEX_RECV_SIZE];
	int status = queryData(dev->fd, hexRecv, hexSend, true, msg);

	strncpy(data, &hexRecv[14], 4);
	data[4] = '\0'; // add null character

	free(hexSend);

	return status;
}

double sendCommand(const int fd, const char *hexSend, const char *fromMsg) {
	double time0 = getTime();

	char hexRecv[HEX_RECV_SIZE];
	int status = queryData(fd, hexRecv, hexSend, true, fromMsg);

	if (status == RECV_SIZE)
		return (getTime() - time0)*1e-6;
	else
		return -1;
}

int queryData(const int fd, char *hexRecv, const char *hexSend, const bool addCRC8, const char *fromMsg) {
	double time0 = 0;
	if (DEBUG_PRINT_QUERY_INFO)
		time0 = getTime();

	// Check if hexSend elements are in the range of valid hexadecimal digits
	if (hexSend[strspn(hexSend, "0123456789abcdefABCDEF")] != 0) {
		fprintf(stderr,
				"\tError: queryData from %s. Input must be a valid hexadecimal character string.\n", fromMsg);
		return -1;
	}

	char *hexCRC8;
	if (addCRC8) {
		hexCRC8 = malloc((strlen(hexSend)+3) * sizeof(char));
		add_crc8_to_hexstring(hexCRC8, hexSend, strlen(hexSend));
	} else {
		hexCRC8 = malloc((strlen(hexSend)+1) * sizeof(char));
		strncpy(hexCRC8, hexSend, strlen(hexSend));
	}

	tcflush(fd, TCIFLUSH);               /* discards old data in the Rx buffer */

	// convert hex into ascii
	char *asciiSend;
	unsigned int str_len = strlen(hexCRC8)/2;
	asciiSend = malloc((str_len+1) * sizeof(char));
	hexToAscii(asciiSend, str_len, hexCRC8);

	int bSend = write(fd, asciiSend, str_len); /* use write() to send data to port */

	// waits until all output written to the object referred to by fd has been transmitted
	tcdrain(fd); /* delay for output */

	if (DEBUG_PRINT_TX_DATA) {
		printf("\nhexSend: 0x%s (nchars = %ld)\n", hexCRC8, strlen(hexCRC8));
		/*
		printf("asciiSend (%u): ", str_len);
		for(int i = 0; i <= str_len; i++) printf("%c", asciiSend[i]);
		printf("\n");
		*/
		printf(" --> %d bytes written\n", bSend);
	}

	// sleep enough to transmit the 11 plus receive 32:  approx 10 uS per char transmit
	//usleep ((bSend + RECV_SIZE) * (int)sleepTime);

	// restore normal (blocking) behavior
	//fcntl(fd, F_SETFL, 0);

	/*
	// Getting the Number of Bytes Available
	int bytes;
	ioctl(fd, FIONREAD, &bytes);
	*/

	char asciiRecv[RECV_SIZE]; // it is always 32 char response
	int bRecv  = read(fd, asciiRecv, RECV_SIZE);   /* returns after 32 chars have been input */
	asciiRecv[bRecv] = '\0'; // add null character

	// restore non-blocking behavior
	//fcntl(fd, F_SETFL, FNDELAY);

	// convert ascii into hex: 2*32+1 = 65
	asciiToHex(hexRecv, HEX_RECV_SIZE, asciiRecv);

	if (DEBUG_PRINT_RX_DATA) {
		printf(" <-- %d bytes read\n", bRecv);
		printf("hexRecv: 0x%s (nchars = %ld)\n", hexRecv, strlen(hexRecv));
		/*
		printf("asciiRecv (%u): ", bRecv);
		for(int i = 0; i < RECV_SIZE; i++) printf("\n%c", asciiRecv[i]);
		printf("\n");
		*/
	}

	if ( strncmp(&hexRecv[6], "00", 2) != 0 ) {
		fprintf(stderr,
				"\tError: queryData from %s. Recv error.\n", fromMsg);
		return -1;
	}

	free(hexCRC8); hexCRC8 = NULL;
	free(asciiSend); asciiSend = NULL;

	if (DEBUG_PRINT_QUERY_INFO)
		printf("%s quering for %f msec\n", fromMsg, (getTime() - time0)*1e-6);

	return bRecv;
}

// Scan device registers and fill the configuration fields in serialDevice
int getDeviceConfigs(serialDevice *dev) {
		dev->manufacturer_id = getManufacturerID(dev); // = 5449 (Texas Instruments)
		dev->device_id = getDeviceID(dev);             // = 3054 (FDC2114), 3055 (FDC2214)

		if ( getClockConfigs(dev) ) { // addresses 0x08, 0x09, 0x0A, 0x0B, 0x10 -- 0x17
			fprintf(stderr, "\tDevice %s: getClockConfigs error\n", dev->name);
			return -1;
		}
		if ( getOffset(dev) ) {       // addresses 0x0C, 0x0D, 0x0E, 0x0F
			fprintf(stderr, "\tDevice %s: getOffset error\n", dev->name);
			return -1;
		}
		if ( getOutputGain(dev) ) {   // addresses 0x1C
			fprintf(stderr, "\tDevice %s: getOutputGain error\n", dev->name);
			return -1;
		}
		if ( getErrorConfig(dev) ) {  // address 0x19
			fprintf(stderr, "\tDevice %s: getErrorConfig error\n", dev->name);
			return -1;
		}
		if ( getConfig(dev) ) {       // address 0x1A
			fprintf(stderr, "\tDevice %s: getConfig error\n", dev->name);
			return -1;
		}
		if ( getMuxConfig(dev) ) {    // address 0x1B
			fprintf(stderr, "\tDevice %s: getMuxConfig error\n", dev->name);
			return -1;
		}
		if ( getDriveCurrent(dev) ) {; // addresses 0x1E, 0x1F, 0x20, 0x21
			fprintf(stderr, "\tDevice %s: getDriveCurrent error\n", dev->name);
			return -1;
		}

	return 0;
}

int setDeviceConfigs(serialDevice *dev) {
	bool ini = false;

	// CLOCK_DIVIDER_CHx
	for (int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] &&
				( (dev->ch_fin_sel[i] != ch_fin_sel) || (dev->ch_fref_divider[i] != ch_fref_divider) )) {
			dev->ch_fin_sel[i] = ch_fin_sel;
			if (dev->ch_fref_divider[i] != ch_fref_divider) {
				dev->ch_fref_divider[i] = ch_fref_divider;
				dev->switchDelay[i] = 692*1e-3 + 5/dev->fCLK * dev->ch_fref_divider[i]; // micro seconds
				ini = true;
			}

			if (dev->beVerbose)
				printf("Set CLOCK_DIVIDER_CH%d:\n\tch_fin_sel = %d, ch_fref_divider = %d (switchDelay = %f[micro sec])\n",
					 	i, ch_fin_sel, ch_fref_divider, dev->switchDelay[i]);

			setClockDividers_ch(dev, i);
		}
	}

	// DRIVE_CURRENT_CHx
	for (int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] && (dev->iDrive[i] != iDrive) ) {
			dev->iDrive[i] = iDrive;

			if (dev->beVerbose)
				printf("Set DRIVE_CURRENT_CH%d:\n\tiDrive = %d\n",
						i, iDrive);

			setDriveCurrent_ch(dev, i);
		}
	}
	
	// CHx_SETTLECOUNT
	for (int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] && (dev->ch_settlecount[i] != ch_settlecount) ) {
			dev->ch_settlecount[i] = ch_settlecount;
			dev->settleTime[i] = 16/dev->fCLK * dev->ch_fref_divider[i] * dev->ch_settlecount[i];
			ini = true;

			if (dev->beVerbose)
				printf("Set CH%d_SETTLECOUNT:\n\t ch_settlecount = %d (settleTime = %f[micro sec])\n",
					 	i, ch_settlecount, dev->settleTime[i]);

			setSettleCount_ch(dev, i);
		}
	}

	// CHx_RCOUNT
	//unsigned int ch_rcount = round(pow(2, ENOB)/16);
	for (int i = 0; i < 4; i++) {
		if ( dev->sensorsUsed[i] && (dev->ch_rcount[i] != ch_rcount) ) {
			dev->ch_rcount[i] = ch_rcount;
			dev->converionTime[i] = 16/dev->fCLK * dev->ch_fref_divider[i] * dev->ch_rcount[i];
			dev->ENOB[i] = (unsigned int)(log2(16 * dev->ch_rcount[i])+0.5);
			ini = true;

			if (dev->beVerbose)
				printf("Set CH%d_RCOUNT:\n\t ch_rcount = %d (converionTime = %f[micro sec], ENOB >= %d)\n",
					 	i, ch_rcount, dev->converionTime[i], dev->ENOB[i]);

			setRCount_ch(dev, i);
		}
	}

	// update settleTime
	if (ini) {
		dev->sampleTime = 0;
		for (int i = 0; i < 4; i++) {
			if ( dev->sensorsUsed[i] )
				dev->sampleTime += (dev->converionTime[i] + dev->settleTime[i] + dev->switchDelay[i]) / 1e3; // [ms]
		}
		if (dev->beVerbose)
			printf("\t Set sample time on %s to %f [ms]\n", dev->name, dev->sampleTime);

		sleep(2); // sleep for 2 secs
	}

	// OUTPUT_GAIN (FDC2114EVM only)
	if ( dev->device_id == DEVICE_FDC2114 && dev->output_gain != output_gain ) {
		dev->output_gain = output_gain;

		if (dev->beVerbose)
			printf("Set OUTPUT_GAIN:\n\t output_gain = %d (%i bits shift)\n", output_gain, ctz(output_gain));

		if ( setOutputGain(dev) < 0 )
			fprintf(stderr, "\n\tError. OUTPUT_GAIN can be set only to 1, 4, 8 and 16.\n");
	}

	// CH_OFFSET (FDC2114EVM only)
	if ( dev->device_id == DEVICE_FDC2114 ) {
		for (int i = 0; i < 4; i++) {
			if ( dev->sensorsUsed[i] && (dev->ch_offset[i] != ch_offset) ) {
				dev->ch_offset[i] = ch_offset;

				if (dev->beVerbose)
					printf("Set CH%d_OFFSET:\n\t ch_offset = %d\n",
							i, ch_offset);

				setOffset_ch(dev, i);
			}
		}
	}

	// ERROR_CONFIG
	ini = false;
	if (dev->errConfig.wd_err2out != wd_err2out) {
		dev->errConfig.wd_err2out = wd_err2out; ini = true;
	}
	if (dev->errConfig.ah_warn2out != ah_warn2out) {
		dev->errConfig.ah_warn2out = ah_warn2out; ini = true;
	}
	if (dev->errConfig.al_warn2out != al_warn2out) {
		dev->errConfig.al_warn2out = al_warn2out; ini = true;
	}
	if (dev->errConfig.we_err2int != we_err2int) {
		dev->errConfig.we_err2int = we_err2int; ini = true;
	}
	if (dev->errConfig.drdy_2int != drdy_2int) {
		dev->errConfig.drdy_2int = drdy_2int; ini = true;
	}
	if (ini)
		setErrorConfig(dev);

	// MUX_CONFIG
	ini = false;
	if (dev->muxConfig.autoscan_en != autoscan_en) {
		dev->muxConfig.autoscan_en = autoscan_en; ini = true;

		if (dev->beVerbose) {
			if (autoscan_en)
				printf("Set MUX_CONFIG:\n\tAuto-scan conversions as selected by rr_sequence = %s\n", rr_sequence);
			else
				printf("Set MUX_CONFIG:\n\tContinuous conversion on the single channel %d\n", active_ch);
		}
	}
	if ( strncmp(dev->muxConfig.rr_sequence, rr_sequence, 2) != 0 ) {
		strncpy(dev->muxConfig.rr_sequence, rr_sequence, 2); ini = true;

		if (dev->beVerbose)
			printf("Set MUX_CONFIG:\n\tAuto-Scan Sequence rr_sequence = %s\n", rr_sequence);
	}
	if ( strncmp(dev->muxConfig.deglitch, deglitch, 3) != 0 ) {
		strncpy(dev->muxConfig.deglitch, deglitch, 3); ini = true;

		if (dev->beVerbose)
			printf("Set MUX_CONFIG:\n\tInput deglitch filter bandwidth = %s\n", deglitch);
	}
	if (ini)
		setMuxConfig(dev);

	// CONFIG
	ini = false;
	if (dev->config.active_ch != active_ch) {
    dev->config.active_ch = active_ch; ini = true;

		if (dev->beVerbose & !autoscan_en)
			printf("Set CONFIG:\n\tPerform continuous converion on Channel %d\n", active_ch);
	}
	if (dev->config.sleep_mode_en != sleep_mode_en) {
    dev->config.sleep_mode_en = sleep_mode_en; ini = true;

		if (dev->beVerbose) {
			if (sleep_mode_en)
				printf("Set CONFIG:\n\tDevice is in Sleep Mode\n");
			else
				printf("Set CONFIG:\n\tDevice is active\n");
		}
	}
	if (dev->config.sensor_active_sel != sensor_active_sel) {
    dev->config.sensor_active_sel = sensor_active_sel; ini = true;

		if (dev->beVerbose) {
			if (sensor_active_sel)
				printf("Set CONFIG:\n\tLow Power Activation Mode\n");
			else
				printf("Set CONFIG:\n\tFull Current Activation Mode\n");
		}
	}
	if (dev->config.ref_clk_src != ref_clk_src) {
    dev->config.ref_clk_src = ref_clk_src; ini = true;

		if (dev->beVerbose) {
			if (ref_clk_src)
				printf("Set CONFIG:\n\tUse external reference frequency clock on CLKIN pin\n");
			else
				printf("Set CONFIG:\n\tUse internal oscillator as reference frequency (43.3 MHz Typical)\n");
		}
	}
	if (dev->config.intb_dis != intb_dis) {
    dev->config.intb_dis = intb_dis; ini = true;

		if (dev->beVerbose) {
			if (intb_dis)
				printf("Set CONFIG:\n\tINTB pin will NOT be asserted when status register updates\n");
			else
				printf("Set CONFIG:\n\tINTB pin will be asserted when status register updates\n");
		}
	}
	if (dev->config.high_current_drv != high_current_drv) {
    dev->config.high_current_drv = high_current_drv; ini = true;

		if (dev->beVerbose && !autoscan_en) {
			if (high_current_drv)
				printf("Set CONFIG:\n\tDrive channel 0 with current > 1.5mA (not supported if autoscan_en = true)\n");
			else
				printf("Set CONFIG:\n\tDrive all channels with normal sensor current (1.5mA max)\n");
		}
	}
	if (ini)
		setConfig(dev);
	
	return 0;
}

// Open the serial ports
int open_device(serialDevice *dev, unsigned int baudRate) {
	int fd = open(dev->name, O_RDWR | O_NOCTTY); /* ttyACM[i] is the FT232 based USB2SERIAL converter */
	                                             /* O_RDWR   - read/write access to serial port       */
	                                             /* O_NOCTTY - no terminal will control the process   */
	                                             /* O_NDELAY - use non-blocking I/O. Otherwise        */
	                                             /*            open in blocking mode, read will wait  */
	if (fd < 0) // error checking
		fprintf(stderr, "\n\tError (%d). Failed to open %s device : %s\n", errno, dev->name, strerror(errno));
	else if ( !isatty(fd) ) {
		fprintf(stderr, "\n\tError (%d), %s is not a tty device : %s\n", errno, dev->name, strerror(errno));
		return -1;
	} else {
		printf("\n %s opened successfully as %s\n\n", dev->name, ttyname(isatty(fd)));
		set_interface_attribs(fd, baudRate); // configurate serial port using termios structure
		tcflush(fd, TCIFLUSH);               // discards old data in the Rx buffer

		dev->fd = fd;
		dev->saved_attributes = saved_attributes; // save the terminal attributes so we can restore them later
		dev->isOpen = true;

		// fill the configuration fields in the serialDevice structure
		if ( getDeviceConfigs(dev) ) return -1;
		// update device configurations as requested
		if ( setDeviceConfigs(dev) ) return -1;

		dev->isSleeping = dev->config.sleep_mode_en;

	}
	return fd;
}

// Close the serial port
int close_device(serialDevice *dev) {
	int fd = dev->fd;

	if (dev->isStreaming)
		stopDeviceStreaming(dev);

	tcflush(fd, TCIOFLUSH);  // flushes both data received but not read, and data written but not transmitted
	tcsetattr(fd, TCSANOW, &(dev->saved_attributes));  // restore the terminal attributes
	close(fd);

	dev->isOpen = false;

	return 0;
}

// Setting the attributes of the serial port using termios structure
int set_interface_attribs(const int fd, unsigned int baudRate) {
	struct termios tty;

	/* get the current attributes of the serial interface */
	if (tcgetattr(fd, &tty) < 0) {
		perror("Failed to get the current configuration of the serial interface");
		return -1;
	}

	// save the terminal attributes so we can restore them later
	tcgetattr(fd, &saved_attributes);
	// register the function to be called at normal program termination
	//atexit(reset_input_mode);

	/* baud rate setting: set read/write speed as BAUDRATE baud */
	if (cfsetispeed(&tty, (speed_t)baudRate) || cfsetospeed(&tty, (speed_t)baudRate)) {
		perror("Invalid baud rate");
		return -1;
	} else {
		baudRate = cfgetispeed(&tty);
		printf(" set read/write speed to: %u\n", (unsigned int)baudRate);
	}

	/* Control mode flags. 8n1 mode (8bit,no parity,1 stopbit) */
	tty.c_cflag &= ~PARENB;  /* disables the parity enable bit (PARENB), so no parity   */
	tty.c_cflag &= ~CSTOPB;  /* CSTOPB = 2 stop bits, here it is cleared so 1 stop bit  */
	tty.c_cflag &= ~CSIZE;	 /* clears the mask for setting the data size               */
	tty.c_cflag |=  CS8;     /* set the data bits = 8                                   */

	tty.c_cflag &= ~CRTSCTS;       /* no hardware flow control                          */
	tty.c_cflag |= CREAD | CLOCAL; /* enable receiver, ignore modem control lines       */

	/* Input mode flags. Setup for non-canonical mode */
	tty.c_iflag &= ~(IXON | IXOFF | IXANY);  /* disable XON/XOFF flow control both i/p and o/p */
	tty.c_iflag &= ~(ICANON | ECHO | ECHOE | ISIG);  /* Non-Cannonical mode                    */

	/* Output mode flags. Setup for non-canonical mode */
	tty.c_oflag &= ~OPOST; /* no output processing */

	/* Control characters. Setting time outs */
	tty.c_cc[VMIN]  = RECV_SIZE; /* blocking read until 32 characters received                 */
	tty.c_cc[VTIME] = 1;         /* wait 0.1sec (= 1 decisecond), (NOTE: 0 - wait indefinetly) */

	/* apply the configuration */
	if (tcsetattr(fd, TCSAFLUSH, &tty) < 0) {
		perror("Error in setting attributes");
		return -1;
	} else
		printf("\n  BaudRate = %d \n  StopBits = 1 \n  Parity   = none\n", baudRate);

	/*
	 tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
	 tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	 tty.c_oflag &= ~OPOST;
	*/

	return 0;
}
