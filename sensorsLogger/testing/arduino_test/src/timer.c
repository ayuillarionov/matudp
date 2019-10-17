
#include <stdio.h>  /* perror */
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

	long accum; // nanoseconds
	if (startTime.tv_sec == 0 && startTime.tv_nsec == 0) {
		startTime = currentTime; // start timer
		accum = 0;
	} else {
		accum = (currentTime.tv_sec - startTime.tv_sec) * 1E9
			+ (currentTime.tv_nsec - startTime.tv_nsec);
	}

	return accum;
}

double getTime_msec() { // in msec
	return getTime()*1E-6;
}
