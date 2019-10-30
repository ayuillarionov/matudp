// see build_udpMexReceiver for mex build call
// Authors: Dan O'Shea, Vikash Gilja
//
// This class binds to a UDP socket and receives data in a particular format.
// Packets arrive and are identified as members of PacketSets, which are a way of
// splitting large data across multiple packets. Once the entire PacketSet has arrived,
// it is parsed into Groups of Signals, where Signals are named, typed Matlab variables.
// Network I/O, parsing, and grouping all occur asynchronously in a background thread.
// When the mex function is called, any groups on the buffer are converted into mxArrays
// and returned to Matlab, which happens very quickly.
//
// Raw bytes may also be sent through the UDP port as well.
//

// Windows Instructions:
//      For mex compilation: mex -lrt udpFileWriter.cpp -Ic:\users\gilja\desktop\Pre-built.2\include ws2_32.lib -lpthreadVC2 -Lc:\users\gilja\desktop\Pre-built.2\lib\x64\ -DWIN32
//      To run and compile we need the win32-pthread library, specifically pthreadVC2 if we're using Visual Studio to compile.  To run, we copy the DLL to c:\windows\system32

#include <pthread.h> // unix POSIX multi-threaded

#include <stdio.h>   // C library to perform Input/Output operations
#include <stdint.h>  // exact-width integer types
#include <stdlib.h>  // EXIT_FAILURE, EXIT_SUCCESS, malloc etc.

#include "math.h"    // various mathematical functions (e.g. floor) and macro HUGE_VAL
#include <string.h>  // for strcmp(), strchr(), strncpy() and memset 
#include <ctype.h>   // functions testing and mapping characters (e.g. toupper)
#include <unistd.h>  // UNIX standard symbolic constants and types, e.g. NULL
#include <time.h>    // date and time information

#include "mex.h"     //--This one is required

// DATA LOGGER PARSING HEADERS
#include "../trialLogger/src/utils.h"
#include "../trialLogger/src/signal.h"
#include "../trialLogger/src/writer.h"
#include "../trialLogger/src/parser.h"
#include "../trialLogger/src/network.h"

///////////// GLOBALS /////////////

pthread_t dataFlushThread;
int mex_call_counter = 0;

// PRIVATE DECLARATIONS
static bool startUdpMexServer();
static void stopUdpMexServer();
static void cleanupAtExit();
int strcmpi(const char*, const char*); // case insensitive string compare
int convertInputArgsToBytestream(uint8_t*, unsigned, int, const mxArray**);

void dataFlushThreadStart();
void dataFlushThreadTerminate();
static void *dataFlushThreadWorker(void*);

static NetworkAddress recv;
static NetworkAddress send;

// LOCAL DEFINITIONS
void cleanupAtExit() {
	if (mexIsLocked()) {
		mexPrintf("udpMexReceiver: Cleaning ...\n");
		stopUdpMexServer();
		mexUnlock();
	}
}

static bool startUdpMexServer() {
	char errMsg[MAX_HOST_LENGTH + 50];
	bool success = false;

	logInfo("udpMexReceiver: Starting server...\n");
	mexLock(); // prohibit clearing a MEX file from memory, when clear MATLAB workspace

	// initialize signal processing buffers and group lookup trie
	// true means wait until next trial is received to start buffering
	// false means start buffering immediately, even if next trial hasn't been received
	controlInitialize(true);

	// install the callback function to process incoming packet data
	networkSetPacketRecvCallbackFn(&processReceivedPacketData);

	success = networkThreadStart(&recv, &send) == 0;

	if (!success) {
		controlTerminate();   // freeDataLoggerStatus
		mexUnlock();          // allowed to clear MEX file from memory
		snprintf_nowarn(errMsg, MAX_HOST_LENGTH + 50, "Could not start network receiver at %s",
				getNetworkAddressAsString(&recv));
		mexWarnMsgIdAndTxt("MATLAB:udpMexReceiver:networkThreadStart",
				errMsg); // display error message and return to MATLAB prompt
		return false;
	}


	//networkOpenSendSocket(&send); // NOTE: already created by networkThreadStart
	
	//dataFlushThreadStart();

	return true;
}

static void stopUdpMexServer() {
	logInfo("udpMexReceiver: Stopping server\n");
	//dataFlushThreadTerminate();
	networkThreadTerminate();
	controlTerminate();
}

// Compare strings without case sensitivity
int strcmpi(const char *s1,const char *s2) {
	int val;
	while( (val = toupper(*s1) - toupper(*s2))==0 ) {
		if (*s1==0 || *s2==0)
			return 0;
		s1++;
		s2++;
		//while(*s1=='_') s1++;
		//while(*s2=='_') s2++;
	}
	return val;
}

//void *p;

void mexFunction(
		int           nlhs,           // Number of expected mxArray output arguments, specified as an integer.
		mxArray       *plhs[],        // Array of pointers to the expected mxArray output arguments.
		int           nrhs,           // Number of input mxArrays, specified as an integer.
		const mxArray *prhs[]         // Array of pointers to the mxArray input arguments.
		) {
	//unsigned nValidCommands = 4;
	//char * validCommands[] = {"start", "stop", "retrieveGroups", "pollGroups"};

	char fun[80 + 1];
	char tempAddressString[MAX_HOST_LENGTH];
	double tempPort;

	bool success = false;

	uint8_t sendBuffer[MAX_PACKET_LENGTH];
	int totalBytesSend;

	// Register cleanup function to call when MEX function clears or MATLAB terminates
	mexAtExit(cleanupAtExit);

	if (mex_call_counter == 0) {
		// first call
		mex_call_counter++;
	}

	/*
	logInfo("UdpMexReceiver: sleeping a bit\n");
	struct timespec req;
	req.tv_sec = 0;
	req.tv_nsec = 10000000; // sleep for 10 ms
	nanosleep(&req, &req);
	*/

	if ( (nrhs >= 1) && mxIsChar(prhs[0]) ) {
		// GET FIRST ARGUMENT -- The "function" name
		mxGetString(prhs[0], fun, 80);

		if (strcmpi(fun, "start") == 0) {
			if (mexIsLocked()) {
				mexWarnMsgIdAndTxt("MATLAB:udpMexReceiver",
						"udpMexReceiver: already started");
				return;
			}

			if (nrhs != 3) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:usage",
						"Usage: udpMexReceiver('start', receiveIPAndPort, sendIPAndPort)");
				return;
			}

			// parse receive ip address
			success = false;
			if (mxIsChar(prhs[1])) {
				mxGetString(prhs[1], tempAddressString, MAX_HOST_LENGTH);
				success = parseNetworkAddress(tempAddressString, &recv);
			} else if (mxIsNumeric(prhs[1])) {
				// parse directly as port number with no interface or host
				tempPort = mxGetScalar(prhs[1]);
				snprintf(tempAddressString, MAX_HOST_LENGTH, "%d", (int)floor(tempPort));
				setNetworkAddress(&recv, "", "", tempPort);
				success = true;
			}
			if (!success) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:parseReceiveNetworkAddress",
						"udpMexReceiver: receiveIPAndPort must be 'ip:port' or numeric port");
				return;
			}

			// parse send ip address
			success = false;
			if (mxIsChar(prhs[2])) {
				mxGetString(prhs[2], tempAddressString, MAX_HOST_LENGTH);
				success = parseNetworkAddress(tempAddressString, &send);
			} else if (mxIsNumeric(prhs[1])) {
				// parse directly as port number with no interface or host
				tempPort = mxGetScalar(prhs[2]);
				snprintf(tempAddressString, MAX_HOST_LENGTH, "%d", (int)floor(tempPort));
				setNetworkAddress(&send, "", "", tempPort);
				success = true;
			}
			if (!success) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:parseSendNetworkAddress",
						"udpMexReceiver: sendIPAndPort must be 'interface:host:port', 'host:port' or numeric port");
				return;
			}

			// bind socket
			mexPrintf("udpMexReceiver: Starting server at %s\n", getNetworkAddressAsString(&recv));
			success = startUdpMexServer();
			if (!success)
				mexUnlock();

			return;
		} else if (strcmpi(fun, "stop") == 0) {
			if (mexIsLocked()) {
				mexPrintf("udpMexReceiver: Stopping server\n");
				stopUdpMexServer();
				mexUnlock();
				return;
			} else { 
				mexPrintf("udpMexReceiver: already stopped\n");
			}
		} else if (strcmpi(fun, "send") == 0) {
			if (!mexIsLocked()) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:send",
						"udpMexReceiver: call with 'start' to bind socket first.");
				return;
			}

			// send data back, prepended with prefix, theni loop through input arguments and byte pack them
			if (nrhs < 2) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:send",
						"udpMexReceiver: call with subsequent arguments to send");
				return;
			}

			// convert input arguments to bytes to send
			totalBytesSend = convertInputArgsToBytestream(sendBuffer, MAX_PACKET_LENGTH, nrhs, prhs);

			if (totalBytesSend == -1) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:send",
						"udpMexReceiver: Cannot fit data into one packet!");
				return;
			}

			if (!networkSend((char*)sendBuffer, (unsigned)totalBytesSend)) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:send",
						"udpMexReceiver: Sendto error");
				return;
			}
		} else if (strcmpi(fun, "retrieveGroups") == 0) {
			if (!mexIsLocked()) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:retrieveGroups",
						"udpMexReceiver: call with 'start' to bind socket first.");
				return;
			}

			// retrieve groups(i) array from current trial, flush data
			if (nlhs != 1) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:retrieveGroups",
						"udpMexReceiver: no output arguments");
				return;
			}

			// send groups on buffer out
			plhs[0] = buildGroupsArrayForCurrentTrial(true);
		} else if (strcmpi(fun, "pollGroups") == 0) {
			if (!mexIsLocked()) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:pollGroups",
						"udpMexReceiver: call with 'start' to bind socket first.");
				return;
			}

			if (nlhs != 1) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:pollGroups",
						"udpMexReceiver: no output arguments");
				return;
			}

			// send groups on buffer out
			plhs[0] = buildGroupsArrayForCurrentTrial(false);
		} else if (strcmpi(fun, "retrieveCompleteTrial") == 0) {
			if (!mexIsLocked()) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:retrieveCompleteTrial",
						"udpMexReceiver: call with 'start' to bind socket first.");
				return;
			}

			if (nlhs != 2) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:retrieveCompleteTrial",
						"udpMexReceiver: two outputs required: [trial, meta]");
				return;
			}

			// send groups on buffer out
			buildTrialStructForLastCompleteTrial(&(plhs[0]), &(plhs[1]));
		} else if (strcmpi(fun, "pollCurrentTrial") == 0) {
			if (!mexIsLocked()) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:pollCurrentTrial",
						"udpMexReceiver: call with 'start' to bind socket first.");
				return;
			}

			if (nlhs != 2) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:pollCurrentTrial",
						"udpMexReceiver: two outputs required: [trial, meta]");
				return;
			}

			// send groups on buffer out
			buildTrialStructForCurrentTrial(&(plhs[0]), &(plhs[1]));
		} else if (strcmpi(fun, "getCurrentControlStatus") == 0) {
			if (!mexIsLocked()) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:getCurrentControlStatus",
						"udpMexReceiver: call with 'start' to bind socket first.");
				return;
			}

			if (nrhs != 1) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:maxrhs",
						"udpMexReceiver: No additional input arguments required.");
			}
			if (nlhs > 1) {
				mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:maxlhs",
						"Too many output arguments.");
			}

			plhs[0] = buildControlStatusStructForCurrentTrial();
		} else {
			mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:invalidCommandSyntax",
					"udpMexReceiver: invalid command syntax!");
			return;
		}
	} else {
		mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:commandArgumentUsage",
				"udpMexReceiver: please call with command argument "
				"('start', 'stop', 'receiveGroups', 'pollGroups', "
				"'retrieveCompleteTrial', 'pollCurrentTrial', 'getCurrentControlStatus')");
	}

	return;
}

int convertInputArgsToBytestream(uint8_t *buffer, unsigned sizebuf, int nrhs, const mxArray **prhs) {
	uint8_t *pSendBufferWrite;
	size_t bytesThisArg;

	memset(buffer, 0, sizebuf);
	pSendBufferWrite = buffer;

	// loop through args and bytepack
	for (int iArg = 1; iArg < nrhs; iArg++) {
		// check for buffer overrun
		if (pSendBufferWrite > buffer + sizebuf)
			return -1;

		if (mxIsChar(prhs[iArg]))
			bytesThisArg = mxGetNumberOfElements(prhs[iArg]);
		else
			bytesThisArg = mxGetElementSize(prhs[iArg])*mxGetNumberOfElements(prhs[iArg]);

		if (pSendBufferWrite + bytesThisArg >= buffer + MAX_PACKET_LENGTH - 1) {
			mexErrMsgIdAndTxt("MATLAB:udpMexReceiver:convertInputArgsToBytestream",
					"iudpMexReceiver: data too large to fit into a packet");
			return -1;
		}

		if (mxIsChar(prhs[iArg])) {
			// copy string directly as ASCII since char in MATLAB is actually 2-byte unicode (UTF-16?)
			mxGetString(prhs[iArg], (char*)pSendBufferWrite,
					buffer + MAX_PACKET_LENGTH - pSendBufferWrite - 2);
		} else {
			memcpy(pSendBufferWrite, mxGetData(prhs[iArg]), bytesThisArg);
		}

		pSendBufferWrite += bytesThisArg;
	}

	return (int)(pSendBufferWrite - buffer);
}

void dataFlushThreadStart() {
	// Start Network Receive Thread
	int status = pthread_create(&dataFlushThread, NULL, dataFlushThreadWorker, NULL);
	if (status) {
		err_print(status, "udpMexReceiver: Return code from pthread_create()");
		exit(-1);
	}
}

void dataFlushThreadTerminate() {
	pthread_cancel(dataFlushThread);
	pthread_join(dataFlushThread, NULL);
}

static void *dataFlushThreadWorker(void *dummy) {
	unsigned nSecondsExpire = 10;
	struct timespec req;
	pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL); // thread is cancelable (default)

	while (1) {
		//logInfo("Cleaning old data\n");
		// flush retired data logger statuses
		controlFlushRetiredStatuses();

		// split the current trial into pieces if older than some threshold
		controlManualSplitCurrentTrialIfOlderThan(nSecondsExpire);

		// flush trials whose data are all older than some threshold
		controlFlushTrialsOlderThan(2*nSecondsExpire);

		// wait
		pthread_testcancel();
		req.tv_sec = 1;
		req.tv_nsec = 0;
		nanosleep(&req, &req);
	}

	return NULL;
}
