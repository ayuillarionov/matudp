#ifndef __TIMER_H_
#define __TIMER_H_

// (re)start timer
int restartTimer();

// get time since timer start in nanoseconds
long getTime();
// get time since timer start in milliseconds
double getTime_msec();

#endif /* __TIMER_H_ */
