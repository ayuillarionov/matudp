#ifndef __SENSORS_THREAD_H_
#define __SENSORS_THREAD_H_

#include <pthread.h>    // unix POSIX multi-threaded

#include "FDC2x14EVM.h"

// One of these is initialized for each FDC2x14EVM thread.
// It contains the "identity" of each device.
typedef struct device_tag {
	int          index;    // thread's index, -1 if no threads
	pthread_t    thread;   // thread for device
	serialDevice *dev;     // pointer to FDC2x14EVM device
} device_t, *device_p;

// hold serial port names and structures. mutex protected
typedef struct serialList_tag {
	bool isThreadsStarted;    // true if sensors threads started for FDC2x14EVM boards

	pthread_mutex_t mutex;    // protects access to serialList data
	pthread_mutexattr_t mutexAttr;
	pthread_cond_t cond;      // signals change to flag/signaledThread
	bool flag;                // true if data available by dev. Access protected by mutex
	pthread_t signaledThread; // signaled thread

	device_t ** tty;
	int num_tty;              // number of allocated devices
} serialList_t;

// default initialization of serialList_t
int initializeSerialList(serialList_t *s);
// add tty_name device to the serialList_t
int parseSerialAddress(serialList_t *s, const char *tty_name, const bool verbose);
// check if tty_name is valid and not present in serialList_t already. Return TRUE if valid and not present
bool isValidSerialAddress(serialList_t *s, const char *tty_name);
// find device index in the SerialList_t. Return -1 if none
int findSerialID(serialList_t *s, const char *tty_name);
// deallocates the memory previously allocated by serialList
void freeSerialList(serialList_t *s);

void setDevicesVerbosity(serialList_t *s, const bool verbose);

// reallocate serialList by removing tty_name device
int removeSerialAddress(serialList_t *s, const char *tty_name);

// open serial ports, perform first initialization
int initializeSensors(serialList_t *s, bool startTimer);

// Open the serial ports
int open_devices(serialList_t *s, const unsigned int baudRate);
// Close the serial ports
int close_devices(serialList_t *s);

int sensorThreadStart(const int id, const serialList_t *s); // start thread for id board
int sensorsThreadsStart(serialList_t *s);                   // start sensors threads for all FDC2x14EVM boards
void sensorThreadTerminate(const int id, serialList_t *s);  // stop  thread for id board
void sensorsThreadsTerminate(serialList_t *s);              // stop  sensors threads for all FDC2x14EVM boards

int startStreaming(const serialList_t *s);
int stopStreaming(const serialList_t *s);
int getStreamingData(const serialList_t *s);

#endif /* __SENSORS_THREAD_H_ */
