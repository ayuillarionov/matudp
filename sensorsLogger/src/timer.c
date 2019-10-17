
#include <stdio.h>  /* perror */
#include <stdlib.h> /* EXIT_FAILURE, EXIT_SUCCESS */
#include <time.h>   /* Time library */

#include "timer.h"

//#define CLOCK CLOCK_REALTIME // represents seconds and nanoseconds since the Epoch
#define CLOCK CLOCK_MONOTONIC // represents monotonic time since some unspecified starting point

static struct timespec startTime; // {time_t tv_sec; long tv_nsec;}

int restartTimer() {
	if ( clock_gettime(CLOCK, &startTime) == -1 ) {
		perror("Clock restartTimer error");
		return -1;
	}
	return 0;
}

long getTime() { // in nsec
	struct timespec currentTime; // {time_t tv_sec; long tv_nsec;}

	if ( clock_gettime(CLOCK, &currentTime) == -1 ) {
		perror("clock getTime error");
		return -1;
	}

	long elapsed; // nanoseconds
	if (startTime.tv_sec == 0 && startTime.tv_nsec == 0) {
		startTime = currentTime; // start timer
		elapsed = 0;
	} else {
		elapsed = (currentTime.tv_sec - startTime.tv_sec) * 1E9
			+ (currentTime.tv_nsec - startTime.tv_nsec);
	}

	return elapsed;
}

double getTime_msec() { // in msec
	return getTime()*1E-6;
}

// --- PERFORMANCE PROFILING FUNCTIONS
static struct timespec tStart, tStop;
static double totalElapsed; // in seconds

void tic() {          // reset, start timer
	totalElapsed = 0;
	if ( clock_gettime(CLOCK, &tStart) == -1 ) {
		perror("tic error");
		abort();
	}
}

void ticPause() {     // pause timer
	double elapsed;
	if ( clock_gettime(CLOCK, &tStop) == -1 ) {
		perror("ticPause error");
		abort();
	}
	elapsed = tStop.tv_sec - tStart.tv_sec;
	elapsed += (tStop.tv_nsec - tStart.tv_nsec) / 1.0E9;
	totalElapsed += elapsed;
}

void ticResume() {    // resume timer
	if ( clock_gettime(CLOCK, &tStart) == -1 ) {
		perror("ticResume error");
		abort();
	}
}

double tocCheck() {   // update and get the current elapsed time
	ticPause();
	ticResume();
	return totalElapsed;
}

double toc() {        // stop timer, get the elapsed time
	ticPause();
	return totalElapsed;
}
