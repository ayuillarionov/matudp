/*
 * File Name :
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Wed 20 Feb 2019 12:28:05 PM CET
 * Modified  : Wed 20 Feb 2019 01:39:17 PM CET
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-45-lowlatency x86_64 x86_64
 *
 * Purpose   : serial communication with a number of FDC2x14EVMs (MSP430 microcontroller)
 */

#include "errors.h"
#include "timer.h"

#include <termios.h> /* POSIX Terminal Control Definitions (man termios to get more info) */
                     /* https://en.wikibooks.org/wiki/Serial_Programming/termios          */

#include "serialList.h"

int open_devices(const serialList *s, unsigned int baudRate) {
	for (int i = 0; i < s->num_tty; i++) {
		s->tty[i]->fd = open_device(s->tty[i], baudRate);
	}

	// start timer
	if (restartTimer() == -1)
		exit( EXIT_FAILURE );

	return 0;
}

// Close the serial ports
int close_devices(const serialList *s) {
	for (int i = 0; i < s->num_tty; i++) {
		close_device(s->tty[i]);
	}

	printf("\nRunning for %f msec\n", getTime()*1e-6);

	return 0;
}

int startStreaming(const serialList *s) {
	int status = 0;
	double tcom;

	for (int i = 0; i < s->num_tty; i++) {
		tcom = startDeviceStreaming(s->tty[i]);
		if (tcom >= 0)
			status++;
	}

	return (status > 0) ? status : -1;
}

int stopStreaming(const serialList *s) {
	int status = 0;
	double tcom;

	for (int i = 0; i < s->num_tty; i++) {
		tcom = stopDeviceStreaming(s->tty[i]);
		if (tcom >= 0)
			status++;
	}

	return (status > 0) ? status : -1;
}

int getStreamingData(const serialList *s) {
	for (int i = 0; i < s->num_tty; i++) {
		getDeviceStreamingData(s->tty[i]);
	}
	return 0;
}

int parseSerialAddress(struct serialList *s, const char *tty_name, const bool verbose) {
	if ( strncmp(tty_name, "/dev/tty", 8) != 0 ) {
		fprintf(stderr, "\tError: %s is not a serial port\n", tty_name);
		return -1;
	} else {
		int id = (s->num_tty)++;

		if (s->tty == NULL)
			s->tty = malloc(sizeof(*s->tty));
		else
			s->tty = realloc(s->tty, id*sizeof(*s->tty));

		s->tty[id] = calloc(1, sizeof(serialDevice));
		if (s->tty[id] == NULL)
			return -1;

		size_t len = strlen(tty_name) + 1;
		s->tty[id]->name = calloc(len, sizeof(char));
		if (s->tty[id]->name == NULL) {
			free(s->tty[id]);
			return -1;
		}
		strncpy(s->tty[id]->name, tty_name, len);

		// FDC2x14EVM initialization
		for (int i = 0; i < 4; i++) {
			s->tty[id]->sensorsUsed[i] = sensorsUsed[i];
			s->tty[id]->iDrive[i] = iDrive;                      // drive current per channel
		}

		s->tty[id]->beVerbose = verbose;
		s->tty[id]->isOpen = false;
		s->tty[id]->isSleeping = false;
		s->tty[id]->isStreaming = false;

		s->tty[id]->parallelInductance = parallelInductance;
		s->tty[id]->parallelCapacitance = parallelCapacitance; // surface mount capacitance
		s->tty[id]->fCLK = fCLK;                               // (external) frequency measurement master clock
	}

	return 0;
}

void freeSerialList(struct serialList *s) {
	for (int i = 0; i < s->num_tty; i++) {
		free(s->tty[i]->name);
		free(s->tty[i]);
	}
	free(s->tty);
}
