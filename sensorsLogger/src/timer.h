#ifndef __TIMER_H_
#define __TIMER_H_

// (re)start timer
int restartTimer();

// get time since timer start in nanoseconds
long getTime();
// get time since timer start in milliseconds
double getTime_msec();

// --- PERFORMANCE PROFILING FUNCTIONS (in seconds)
void   tic();       // reset, start timer
void   ticPause();  // pause timer
void   ticResume(); // resume timer
double tocCheck();  // update and get the current elapsed time
double toc();       // stop timer, get the elapsed time since the tic command

#endif /* __TIMER_H_ */
