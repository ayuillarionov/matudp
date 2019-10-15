/*
 * Serialized Data File Logger
 */

#include <stdio.h>
#include <string.h> /* For strcmp() */
#include <stdlib.h> /* For EXIT_FAILURE, EXIT_SUCCESS */

#include <math.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>
#include <inttypes.h>
#include <signal.h>  // ANSI C signal handling (man signal)

#include <argp.h>  // interface for parsing unix-style argument vectors

// local includes
#include "utils.h"
#include "signal.h"
#include "writer.h"
#include "parser.h"
#include "network.h"

#include "signalLogger.h"

static NetworkAddress recv_addr; // server (local, recv) address
static NetworkAddress send_addr; // real-time machine (remote) address

error_t parse_opt(int key, char *arg, struct argp_state *state) {
	switch(key) {
		case 'r':
			parseNetworkAddress(arg, &recv_addr);
			break;
		case 'd':
			setDataRoot(arg);
			break;
		case ARGP_KEY_INIT: // passed before any parsing happenes
			setNetworkAddress(&recv_addr, "", "", 29001);            // default network configuration for local server
			setNetworkAddress(&send_addr, "", "100.1.1.255", 10005); // default network configuration for remote RTM
			break;
		default:
			return ARGP_ERR_UNKNOWN;
	}
	return 0;
}

void abortFromMain(int sig) {
	logInfo("\n\t ==> Signal logger terminating <==\n\n");
	signalWriterThreadTerminate();
	// -- Close network connection
	networkThreadTerminate();
	controlTerminate();
	exit(EXIT_SUCCESS);
}

int main(int argc, char *argv[]) {
	// parse startup options
	struct argp_option options[] = {
		{ "recv", 'r', "IP:PORT or PORT", 0, "Specify IP address and port to receive packets"},
		{ "dataroot", 'd', "PATH", 0, "Specify data root folder"},
		{ 0 }
	};
	struct argp argp = { options, parse_opt, 0, 0 };
	int status = argp_parse(&argp, argc, argv, 0, 0, 0);
	if (status != 0) {
		fprintf(stderr, "\tInput parsing error\n");
		exit(EXIT_FAILURE);
	}

	// copy the default data root in, later make this an option?
	if ( !checkDataRootAccessible() ) {
		fprintf(stderr, "No read/write access to data root. Check writer permissions on %s", getDataRoot());
		exit(1);
	}
	logInfo("Info: signal data root at %s\n", getDataRoot());

	// Register <C-c> handler
	signal(SIGINT, abortFromMain); // Terminal interrupt signal <C-c>: SIGINT = 2

	// initialize signal processing buffers and lookup tries
	// true means wait until NextTrial is received before buffering anything
	controlInitialize(true);

	logInfo("\n\t ==> Signal logger starting <==\n\n");

	signalWriterThreadStart();

	// install the callback function to process incoming packets -> parser.c
	networkSetPacketRecvCallbackFn(&processReceivedPacketData);
	// install the callback function to process outgoing packets -> network.c
	//networkSetPacketSendCallbackFn(&sendSensorsData);
	
	// start network thread
	status = networkThreadStart(&recv_addr, &send_addr);
	if (status != 0) {
		abortFromMain(0);
		exit(EXIT_FAILURE);
	}

	while(1) { // a long wait so that we can easily issue a signal to this process
		sleep(1);
	}

	abortFromMain(0);
	return(EXIT_SUCCESS);
}
