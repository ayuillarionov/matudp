/*
 * File Name : sensorsThread.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Wed 20 Feb 2019 07:29:50 PM CET
 * Modified  : Tue 23 Apr 2019 05:09:54 PM CEST
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-45-lowlatency x86_64 x86_64
 *
 * Purpose   :
 */

#include <sys/stat.h>

#include "errors.h"
#include "timer.h"

#include "discover.h"
#include "sensorsThread.h"

#define READ_INTERVAL_USEC 1*1000 // 1 msec

static void *sensorThread(void *arg);
static void sensorThreadCleanup(void *arg); // automatically executed when a thread is canceled

static int PTHREAD_MUTEX_LOCK(pthread_mutex_t *mutex) {
	tic();
	int status = 1;
	while (status != 0) {
		status = pthread_mutex_trylock(mutex);   // non-blocking
		if (status == EINVAL) {
			err_abort(status, "Sensors: The value specified by mutex is not valid!!!");
		}

		if (tocCheck() > 1) { // in sec
			fprintf(stderr, "Sensors: Hanging waiting for mutex! ");
			tic();
		}
	}

	/*
	int status = pthread_mutex_lock(mutex);   // blocking
	if (status != 0)
		err_abort(status, "Sensors: Lock mutex");
	*/

	return status;
}

static int PTHREAD_MUTEX_UNLOCK(pthread_mutex_t *mutex) {
	int status = pthread_mutex_unlock(mutex);
	if (status != 0)
		err_abort(status, "Sensors: Unlock mutex");
	return status;
}

// This function is run as a separate thread for each FDC2x14EVM board from the main() derived thread.
// It reads sensors data and prepare for networking
static void *sensorThread(void *arg) {
	pthread_t idThread = pthread_self();

	serialList_t *s = (serialList_t*)arg;
	int id;                     // thread identification
	for (id = 0; id < s->num_tty; id++) {
		if (pthread_equal(s->tty[id]->thread, idThread)) {
			break;
		}
	}
	// thread is cancelable (default)
	pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
	// keep the cancellation request pending until the next cancellation point (default)
	//pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, NULL);
	// push Cleanup routine onto the top of the stack of clean-up handlers
	pthread_cleanup_push(sensorThreadCleanup, (void*)(s->tty[id]));

	serialDevice *dev = s->tty[id]->dev;

	int status;
	while(1) {
		pthread_testcancel();        // a cancellation point
		getDeviceStreamingData(dev);

		PTHREAD_MUTEX_LOCK(&s->mutex);
		s->signaledThread = pthread_self(); // set predicate
		s->flag = true;                     // signal data availability
		status = pthread_cond_signal(&s->cond);
		if (status != 0)
			err_abort(status, "Sensors: Signal condition");
		PTHREAD_MUTEX_UNLOCK(&s->mutex);

		usleep(READ_INTERVAL_USEC);
	}

	// remove Cleanup routine at the top of the stack of clean-up handlers
	pthread_cleanup_pop(0);

	return NULL;
}

static void sensorThreadCleanup(void *arg) {
	device_t *tty = (device_t*)arg;
	stopDeviceStreaming(tty->dev);
	printf("Sensors: Cleaning up the thread %d [%s]\n", tty->index, tty->dev->name);
}

int sensorThreadStart(const int id, const serialList_t *s) {
	s->tty[id]->index = id; // register thread's index

	int recv = pthread_create(&(s->tty[id]->thread), NULL, sensorThread, (void*)s);
	if (recv) {
		fprintf(stderr, "\tError: Return code from pthread_create() is %d [%s serial port]\n",
				recv, s->tty[id]->dev->name);
		exit( EXIT_FAILURE );
	}

	printf("Sensors: Staring thread %d for %s\n", id, s->tty[id]->dev->name);

	return recv;
}

// start sensors threads for all FDC2x14EVM boards
int sensorsThreadsStart(serialList_t *s) {
	for (int id = 0; id < s->num_tty; id++)
		if (s->tty[id]->dev->isOpen)
			sensorThreadStart(id, s);
		else
			fprintf(stderr, "Sensors: sensorsThreadsStart error: Open device %s first\n", s->tty[id]->dev->name);
	s->isThreadsStarted = true;
	return 0;
}

void sensorThreadTerminate(const int id, serialList_t *s) {
	void *res = NULL;
	pthread_cancel(s->tty[id]->thread);     // send a cancellation request to a thread
	pthread_join(s->tty[id]->thread, &res); // wait for thread termination
	if (res == PTHREAD_CANCELED)
		printf("Sensors: Thread for %s was canceled\n", s->tty[id]->dev->name);
	else
		printf("Sensors: Thread for %s terminated normally\n", s->tty[id]->dev->name);

	s->tty[id]->index = -1;
	s->flag = false;
}

// stop sensors threads for all FDC2x14EVM boards
void sensorsThreadsTerminate(serialList_t *s) {
	for (int id = 0; id < s->num_tty; id++)
		sensorThreadTerminate(id, s);
	s->flag = false;
}

int initializeSerialList(serialList_t *s) {
	if (s == NULL) return -1;

	int status;

	// -- initialize the serialList_t mutex as recursive
	status = pthread_mutexattr_init(&s->mutexAttr);
	if (status != 0)
		err_abort(status, "Sensors: Init mutexAttr");
	status = pthread_mutexattr_settype(&s->mutexAttr, PTHREAD_MUTEX_RECURSIVE);
	if (status != 0)
		err_abort(status, "Sensors: Set mutex type to recursive");
	status = pthread_mutex_init(&s->mutex, &s->mutexAttr);
	if (status != 0)
		err_abort(status, "Sensors: Init mutex");
	// -- init condition
	status = pthread_cond_init(&s->cond, NULL);
	if (status != 0)
		err_abort(status, "Sensors: Init condition");

	s->isThreadsStarted = false; // no sensors threads yet started
	s->flag = false;             // sensor data is unavailable
	s->tty = NULL;               // no FDC2x14EVM boards yet registered
	s->num_tty = 0;

	return 0;
}

int parseSerialAddress(serialList_t *s, const char *tty_name, const bool verbose) {
	if ( !isValidSerialAddress(s, tty_name) )
		return -1;

	PTHREAD_MUTEX_LOCK(&s->mutex);

	int id = (s->num_tty)++;

	// add device to the serialList_t
	if (s->tty == NULL)
		s->tty = malloc(sizeof(**s->tty));
	else {
		void *tmp = realloc(s->tty, id*sizeof(**s->tty));
		if (tmp == NULL) {
			fprintf(stderr, "\tError: Unable to realloc serialList for %s serial port\n", tty_name);
			return -1;
		}
		s->tty = tmp;
	}

	// allocate the thread for device
	s->tty[id] = calloc(1, sizeof(device_t));
	if (s->tty[id] == NULL) {
		fprintf(stderr, "\tError: Unable to allocate the thread for %s serial port\n", tty_name);
		return -1;
	}

	s->tty[id]->index = -1;                       // no thread yet started for this device

	// create serialDevice structure
	s->tty[id]->dev = calloc(1, sizeof(serialDevice));
	if (s->tty[id]->dev == NULL) {
		free(s->tty[id]);
		return -1;
	}

	serialDevice *dev = s->tty[id]->dev;

	size_t len = strlen(tty_name) + 1;
	dev->name = calloc(len, sizeof(char));
	if (dev->name == NULL) {
		free(s->tty[id]->dev);
		free(s->tty[id]);
		return -1;
	}
	strncpy(dev->name, tty_name, len);

	// FDC2x14EVM initialization
	for (int i = 0; i < 4; i++) {
		dev->sensorsUsed[i] = sensorsUsed[i];
		dev->iDrive[i] = iDrive;                      // drive current per channel
	}

	dev->beVerbose = verbose;
	dev->isOpen = false;
	dev->isSleeping = false;
	dev->isStreaming = false;

	dev->parallelInductance = parallelInductance;
	dev->parallelCapacitance = parallelCapacitance; // surface mount capacitance
	dev->fCLK = fCLK;                               // (external) frequency measurement master clock

	PTHREAD_MUTEX_UNLOCK(&s->mutex);

	return 0;
}

bool isValidSerialAddress(serialList_t *s, const char *tty_name) {
#if defined(__linux__)
	if ( strncmp(tty_name, "/dev/tty", 8) != 0 ) {
#elif defined(__APPLE__)
	if ( strncmp(tty_name, "/dev/tty.usbmodem", 17) != 0 && strncmp(tty_name, "/dev/cu.usbmodem", 16) != 0 ) {
#endif
		fprintf(stderr, "\tSerial Error: %s is not a serial port\n", tty_name);
		return false;
	}

	if (s->num_tty == 0)
		return true;

	struct stat st;
	if (stat(tty_name, &st) == -1) {
		errno_print("Serial: stat error");
		return false;
	}

	if ( !S_ISCHR(st.st_mode) ) {
		errno_print("Serial: %s is not a character device");
    return false;
	}

	if ( findSerialID(s, tty_name) >= 0 ) // tty_name is already in the SerialList_t
		return false;

	return true;
}

int findSerialID(serialList_t *s, const char *tty_name) {
	if (s == NULL) return -1;

	for (int id = 0; id < s->num_tty; id++) {
		if ( strcmp(tty_name, s->tty[id]->dev->name) == 0 )
			return id;
	}
	return -1;
}

void freeSerialList(serialList_t *s) {
	if (s == NULL) return;

	int status;
	// -- destroy condition
	status = pthread_cond_destroy(&s->cond);
	if (status != 0)
		err_abort(status, "Sensors: Destroy condition");
	// -- destroy mutex
	status = pthread_mutexattr_destroy(&s->mutexAttr);
	if (status != 0)
		err_abort(status, "Sensors: Destroy mutexAttr");
	status = pthread_mutex_destroy(&s->mutex);
	if (status != 0)
		err_abort(status, "Sensors: Destroy mutex");

	// -- free memory
	for (int i = 0; i < s->num_tty; i++) {
		freeSerialDevice(s->tty[i]->dev);
		free(s->tty[i]);
	}
	free(s->tty);
}

void setDevicesVerbosity(serialList_t *s, const bool verbose) {
	PTHREAD_MUTEX_LOCK(&s->mutex);

	for (int id = 0; id < s->num_tty; id++)
		s->tty[id]->dev->beVerbose = verbose;

	PTHREAD_MUTEX_UNLOCK(&s->mutex);
}

// reallocate serialList by removing tty_name device
int removeSerialAddress(serialList_t *s, const char *tty_name) {
	int id = findSerialID(s, tty_name);
	if ( id < 0 ) // tty_name is not in the serialList_t
		return -1;

	PTHREAD_MUTEX_LOCK(&s->mutex);

	if (s->tty[id]->index >= 0)
		sensorThreadTerminate(id, s);
	if (s->tty[id]->dev->isOpen)
		close_device(s->tty[id]->dev);

	printf("Sensors: %s was removed from serialList\n", tty_name);

	// free memory for the ID device
	freeSerialDevice(s->tty[id]->dev);
	free(s->tty[id]);

	// start at the place where ID device was removed and iterate through the rest of devices
	for (int i = id; i < s->num_tty; i++) {
		if ( (i + 1) == s->num_tty ) // one device removed => last element becomes "empty"
			s->tty[i] = NULL;
		else
			s->tty[i] = s->tty[i+1];
	}

	(s->num_tty)--;

	// reallocate memory for serialList_t
	void *tmp = realloc(s->tty, s->num_tty*sizeof(**s->tty));
	if (s->num_tty != 0 && tmp == NULL)
		errno_abort("Error: Unable to realloc serialList");
	else
		s->tty = tmp; // success, assign for shortened memory

	PTHREAD_MUTEX_UNLOCK(&s->mutex);

	return s->num_tty;
}

int initializeSensors(serialList_t *s, bool startTimer) {
	s->flag = false; // sensor data is unavailanle

	// -- Opening the serial ports
	open_devices(s, BAUDRATE);

	// start timer
	if (startTimer && restartTimer() == -1)
			exit( EXIT_FAILURE );

	return 0;
}

// Open the serial ports
int open_devices(serialList_t *s, const unsigned int baudRate) {
	PTHREAD_MUTEX_LOCK(&s->mutex);

	for (int id = 0; id < s->num_tty; id++)
		s->tty[id]->dev->fd = open_device(s->tty[id]->dev, baudRate);

	PTHREAD_MUTEX_UNLOCK(&s->mutex);
	return 0;
}

// Close the serial ports
int close_devices(serialList_t *s) {
	if (s == NULL)
		return -1;

	PTHREAD_MUTEX_LOCK(&s->mutex);

	for (int id = 0; id < s->num_tty; id++) {
		if (s->tty[id]->index >= 0)
			sensorThreadTerminate(id, s);
		if (s->tty[id]->dev->isOpen)
			close_device(s->tty[id]->dev);
	}

	printf("Sensors: Running for %f msec\n", getTime()*1e-6);

	PTHREAD_MUTEX_UNLOCK(&s->mutex);

	return 0;
}

int startStreaming(const serialList_t *s) {
	int status = 0;
	double tcom;

	for (int id = 0; id < s->num_tty; id++) {
		tcom = startDeviceStreaming(s->tty[id]->dev);
		if (tcom >= 0)
			status++;
	}

	return (status > 0) ? status : -1;
}

int stopStreaming(const serialList_t *s) {
	int status = 0;
	double tcom;

	for (int id = 0; id < s->num_tty; id++) {
		tcom = stopDeviceStreaming(s->tty[id]->dev);
		if (tcom >= 0)
			status++;
	}

	return (status > 0) ? status : -1;
}

int getStreamingData(const serialList_t *s) {
	for (int id = 0; id < s->num_tty; id++) {
		getDeviceStreamingData(s->tty[id]->dev);
	}
	return 0;
}
