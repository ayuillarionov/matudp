/*
 * File Name : arduino-FDC-loop.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Wed 30 Jan 2019 03:21:52 PM CET
 * Modified  : Wed 20 Feb 2019 02:51:22 PM CET
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-43-lowlatency x86_64 x86_64
 *
 * Purpose   : Time lag estimate in arduino-FDC2x14EVM loop
 */

#define samplingSteps 1E7  // loop size
#define samplingPause 0    // sampling pause (in msec)

#define arduinoPulse 50    // arduino switch pulse
#define arduinoPause 0     // after-switch pause (in msec)

#define STREAM_DATA 1

#include "errors.h"
#include "timer.h"
#include "arduino-serial-lib.h"

#include <math.h> 

#include "serialList.h"

static bool verbose = false;

//static const double arduino_rw = 0.4997; // [ms]

static void datastats(const char *name, const double *data, const unsigned long n);
double find_median(const double *array, const unsigned long n);

int main(int argc, char *argv[]) {
	double tStart, time0;

	struct serialList s;
	s.tty = NULL; s.num_tty = 0; // init
	static const char *FDCPort = "/dev/ttyACM0";     // Ubuntu
	parseSerialAddress(&s, FDCPort, verbose);

	// -- Open FDC serial port
  open_devices(&s, BAUDRATE);

	static const int arduinoBaudRate = 1000000;
	static const char *arduinoPort = "/dev/ttyUSB0"; // Ubuntu

	// -- Open Arduino serial port
	int fd = serialPort_init(arduinoPort, arduinoBaudRate);
	if (fd == -1)
		errno_abort("Unable to open arduino port");
	serialPort_flush(fd);

	double *t = (double *)calloc(samplingSteps,  sizeof(double));
	double (*data)[4][4]; data = calloc(samplingSteps, sizeof(*data));
	double *samplingTime = (double *)calloc(samplingSteps, sizeof(double));
	unsigned *arduinoState = (unsigned *)calloc(samplingSteps, sizeof(unsigned));
	double *arduinoTime = (double *)calloc(floor(samplingSteps/arduinoPulse), sizeof(double));
	double *switchTime = (double *)calloc(floor(samplingSteps/arduinoPulse), sizeof(double));

	int pinStatus, timeOut = 10; // [ms]

	int iSwitch = 0, switchTolerance = 5;
	double switchStart, data0 = 0;

	if (STREAM_DATA) { // start streaming
		printf("startStreaming status = %d\n", startStreaming(&s));
		sleep(0.5); // pause 0.5 sec
	}

  // start stopwatch timer
	tStart = restartTimer();

  for (int i = 0; i < samplingSteps; ++i) {
		if (i > 0 && i%arduinoPulse == 0) {
			time0 = getTime()*1e-6;

			if (arduinoState[i-1] == 0) {
				if (serialPort_writeByte(fd, (uint8_t)1) == -1) // pin HIGH
					errno_abort("Arduino error writing 1");
				arduinoState[i] = 1;
			} else {
				if (serialPort_writeByte(fd, (uint8_t)0) == -1) // pin LOW
					errno_abort("Arduino error writing 0");
				arduinoState[i] = 0;
			}

			pinStatus = serialPort_readByte(fd, timeOut);
			DPRINTF(("Arduino pin status: %d (time = %f [ms])\n", pinStatus, (getTime()-time0)*1e-6));

			switchStart = getTime()*1e-6;
			arduinoTime[iSwitch] = switchStart-time0;
			data0 = data[i-1][1][0]; // total capacitance on first channel at arduino switch time
      iSwitch += 1;

			usleep(arduinoPause * 1000); // sleep arduinoPause msec
		} else {
			if (i == 0)
				arduinoState[i] = 0;
      else
        arduinoState[i] = arduinoState[i-1];
		}

		time0 = getTime()*1e-6;
		if (STREAM_DATA) {
			//getStreamingData(&s);
			getDeviceStreamingData(s.tty[0]);
		} else {
			scanChannels(s.tty[0], sampleTimeMinDelay);
		}
		samplingTime[i] = getTime()*1e-6 - time0;

		for (int iChannel = 0; iChannel < 4; iChannel++) {
			data[i][0][iChannel] = s.tty[0]->data.frequency[iChannel];
			data[i][1][iChannel] = s.tty[0]->data.totalCapacitance[iChannel];
			data[i][2][iChannel] = s.tty[0]->data.sensorCapacitance[iChannel];
			data[i][3][iChannel] = s.tty[0]->data.rawData[iChannel];
		}

		if (iSwitch > 0 && switchTime[iSwitch-1] == 0 && fabs(data[i][1][0] - data0) > switchTolerance) {
			switchTime[iSwitch-1] = getTime()*1e-6 - switchStart;
			printf("%d: respond time =  %6f [msec]\n", iSwitch-1, switchTime[iSwitch-1]);
		}

		t[i] = (getTime()-tStart)*1e-6;

		printf("%7d %12.6f %12.6f %8f %8d\n", i, t[i], samplingTime[i], data[i][1][0], arduinoState[i]);

    usleep(samplingPause * 1000);
  }

	if (STREAM_DATA)
		printf("stopStreaming status = %d\n", stopStreaming(&s));

	// Statistics
	
	datastats("switchTime", switchTime, iSwitch);
	datastats("arduinoTime", arduinoTime, iSwitch);

	// Close Arduino serial port
	serialPort_close(fd);

  // -- Close FDC serial port
  close_devices(&s);

	free(t); free(data); free(samplingTime); free(arduinoState); free(arduinoTime); free(switchTime);

	freeSerialList(&s);
	exit(EXIT_SUCCESS);
}

// statistics
void datastats(const char *name, const double *data, const unsigned long n) {
	double min, max, mean, median, range, std;
	unsigned long iMin = 0, iMax = 0;

	min = max = mean = median = data[0];

	for (unsigned long i = 1; i < n; i++) {
		if (data[i] < min) {
			min = data[i];
			iMin = i;
		}
		if (data[i] > max) {
			max = data[i];
			iMax = i;
		}
		mean += data[i];
	}
	range = max-min;
	mean = mean/n;

	std = 0;
	for (unsigned long i = 0; i < n; i++) {
		std += pow(data[i] - mean, 2);
	}
	std = sqrt(std/n);

	median = find_median(data, n);

	printf("--> %s statistics: nPoints = %ld <--\n", name, n);
	printf("       min(iMin)        max(iMax)         mean       median        range          std\n");
	printf("%12.6f(%ld) %12.6f(%ld) %12.6f %12.6f %12.6f %12.6f\n", min, iMin, max, iMax, mean, median, range, std);
}

// function to sort the array of doubles in ascending order
void array_sort(double *array, unsigned long n) {
	double temp = 0;
	for (unsigned long i = 0; i < n; i++)
		for (unsigned long j = 0; j < n-1; j++)
			if (array[j] > array[j+1]) {
				temp = array[j];
				array[j] = array[j+1];
				array[j+1] = temp;
			}
}

// function to calculate the median of the array
double find_median(const double *array, const unsigned long n) {
	size_t size = n * sizeof(double);
	double *buf = malloc(size);
	memcpy(buf, array, size);

	// sort the array in ascending order
	array_sort(buf, n);

	double median = 0;
	if (n%2 == 0) // if number of elements is even
		median = (array[(n-1)/2] + array[n/2])/2.0;
	else          // if number of elements is odd
		median = array[n/2];

	free(buf);
	return median;
}
