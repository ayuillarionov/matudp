/*
 * File Name : sensorsLogger.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Fri 25 Jan 2019 11:15:11 AM CET
 * Modified  : Tue 23 Apr 2019 05:36:22 PM CEST
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-43-lowlatency x86_64 x86_64
 *
 * Purpose   : FDC2x14EVM (MSP430 microcontroller) serial communication
 *             The MSP430 microcontroller is used to interface the FDC to a host computer through USB interface.
 *             http://e2e.ti.com/support/sensor/inductive-sensing/f/938/t/295036#Q41
 */

#include "errors.h"  // include stdio, stdlib, errno, string, unistd
#include "timer.h"   // profiling
#include <argp.h>    // interface for parsing unix-style argument vectors

#include <signal.h>  // ANSI C signal handling (man signal)

#include "discover.h"
#include "parser.h"
#include "network.h"

static NetworkAddress recv_addr; // server (local, recv) address
static NetworkAddress send_addr; // real-time machine (remote) address

static serialList_t s;           // list of FDC2x14EVM boards

static bool verbose = false;

pthread_once_t once_control = PTHREAD_ONCE_INIT;

/* COMMAND-LINE ARGUMENT PARSER */
const char *argp_program_version = "sensorLogger 1.2\n"
	"Copyright (C) 2019 Institute of Neuroinformatics, University of Zurich";
const char *argp_program_bug_address = "<ayuillarionov@ini.uzh.ch>";
/* A description of the arguments we accept. */
#if defined(__linux__)
	static char args_doc[] = "[/dev/ttyACMx [/dev/ttyACMy ...]]";
#elif defined(__APPLE__) && defined(__MACH__)
	static char args_doc[] = "[/dev/cu.usbmodemxxxxx [/dev/cu.usbmodemyyyyyy ...]]";
#endif
/* Program documentation. */
static char doc[] = "\nThe program provides direct FDC2x14EVM (MSP430 microcontroller) devices register access, "
	"configuration, and network data streaming."
#if defined(__linux__)
	"\vFind USB ACM devices: dmesg | grep tty.\n"
	"Change and print terminal line settings: stty [--all] < /dev/ttyACMx.\n"
	"Monitor hotplug events: udevadm monitor --udev --property.";
#elif defined(__APPLE__) && defined(__MACH__)
	"\vFind USB devices: system_profiler SPUSBDataType.";
#endif

/* parse a single option */
static error_t parse_opt(int key, char *arg, struct argp_state *state) {
	serialList_t *s = state->input;
	switch (key) {
		case 'v':
			verbose = true;
			set_libUSBverbosity(verbose);
			setDevicesVerbosity(s, verbose);
			break;
		case 'p':
			//setDataRoot(arg);
			break;
		case 'r':
			parseNetworkAddress(arg, &recv_addr);
			break;
		case 's':
			parseNetworkAddress(arg, &send_addr);
			break;
		case ARGP_KEY_INIT: // passed before any parsing happenes
			setNetworkAddress(&recv_addr, "", "", 29005);            // default network configuration for local server
			setNetworkAddress(&send_addr, "", "100.1.1.255", 10005); // default network configuration for remote RTM

			initializeSerialList(s);

			// initialize libusb session, debugging and hotpluging, default verbosity
			libUSB_init(s, false); // NOTE: it addes FDC2x14EVM devices if they are already attached

			break;
		case ARGP_KEY_ARG:
			parseSerialAddress(s, arg, verbose);
			break;
		case ARGP_KEY_END:
			//if (s->num_tty < 1)
			//	argp_failure(state, 1, 0, "at least one serial port should be provided");
			//else if (s->num_tty > 2)
			//	argp_failure(state, 1, 0, "too many serial ports");
			break;
		default:
			return ARGP_ERR_UNKNOWN;
	}
	return 0;
}

void once_init_routine(void) {
	// discover already attached devices
	discoverDevices(&s, verbose);

	// initialize sensor devices, start timer
	initializeSensors(&s, true);

	// install the callback function to process incoming packets -> parser.c
	networkSetPacketRecvCallbackFn(&processRecvPacketData);
	// install the callback function to process outgoing packets -> network.c
	networkSetPacketSendCallbackFn(&sendSensorsData);
}

void abortFromMain(int sig) {
	printf("\n\t ==> Sensor logger terminating <==\n\n");

	// -- Stop streaming
	sensorsThreadsTerminate(&s);
	// -- Close all serial ports
	close_devices(&s);
	// -- Close network connection
	networkThreadTerminate();
	// -- Terminate libusb hotplug thread
	libUSB_exit();

	// -- Free allocated memory
	freeSerialList(&s);

	exit(EXIT_SUCCESS);
}

int main(int argc, char** argv) {
	// parse startup options using argp
	static struct argp_option options[] = {
		{"verbose",  'v', 0,      0, "Produce verbose output" },
		{"dataroot", 'p', "PATH", 0, "Specify data root folder"},
		{"recv", 'r', "INTERFACE:IP:PORT, IP:PORT or PORT", 0,
		 	"Specify (local) IP address and port of recv server (default is localhost:29005)"},
		{"send", 's', "IP:PORT or PORT", 0,
			"Specify (remote) IP address and port to send sensor data packets (default is 100.1.1.255:10005)"},
		{ 0 }
	};
	static struct argp argp = { options, parse_opt, args_doc, doc };
	int status = argp_parse(&argp, argc, argv, 0, 0, &s);
	if (status != 0) {
		fprintf(stderr, "\tError parsing serial list\n");
		freeSerialList(&s);
		return EXIT_FAILURE;
	}

	// Register <C-c> handler
	signal(SIGINT, abortFromMain); // Terminal interrupt signal <C-c>: SIGINT = 2

	// one-time initialization
	status = pthread_once(&once_control, once_init_routine);

	printf("\n\t ==> Sensor logger starting <==\n\n");

	// start network thread
	status = networkThreadStart(&recv_addr, &send_addr, &s);
	if (status != 0) {
		abortFromMain(0);
		exit(EXIT_FAILURE);
	}

	// start libusb hotplug thread
	status = libUSB_threadStart();
	if (status != 0) {
		abortFromMain(0);
		exit(EXIT_FAILURE);
	}

	// start sensors thread
	sensorsThreadsStart(&s);

	while(1) { // a long wait so that we can easily issue a signal to this process
		sleep(1);
	}

	abortFromMain(0);
	return EXIT_SUCCESS;
}
