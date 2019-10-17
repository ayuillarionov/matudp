#ifndef __SERIAL_LIST_H_
#define __SERIAL_LIST_H_

#include "FDC2x14EVM.h"

/* hold serial port names and structures */
typedef struct serialList {
	serialDevice ** tty;
	int num_tty;
} serialList;

int parseSerialAddress(struct serialList *s, const char *tty_name, const bool verbose);
// deallocates the memory previously allocated by serialList
void freeSerialList(struct serialList *s);

// Open the serial ports
int open_devices(const serialList *s, unsigned int baudRate);
// Close the serial ports
int close_devices(const serialList *s);

int startStreaming(const serialList *s);
int stopStreaming(const serialList *s);
int getStreamingData(const serialList *s);

#endif /* __SERIAL_LIST_H_ */
