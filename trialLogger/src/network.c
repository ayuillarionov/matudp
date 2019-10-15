/*
 * File Name : network.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Wed 13 Sep 2017 03:47:38 PM CEST
 * Modified  : Tue 23 Jul 2019 05:00:05 PM CEST
 * Computer  : ZVPIXX
 * System    : Linux 4.4.0-93-lowlatency x86_64 x86_64
 *
 * Purpose   : receive BusSerialized data off the network
 * Note      : LINUX/MACOS specific implementation
 *
 * Network Check : sudo tcpdump -vv -i eno4 -n udp port 29001 -X
 */

#include <pthread.h>               // unix POSIX multi-threaded

#include <stdio.h>                 // C library to perform Input/Output operations
#include <stdlib.h>                // malloc, atoi
#include <unistd.h>                // standard symbolic constants and types, e.g. NULL
#include <string.h>                /* For strcmp(), strchr(), strncpy() and memset */
#include <time.h>                  // date and time information

// WINDOWS specific stuff (build with Ws2_32.lib)
#ifdef _WIN32
	#pragma comment(lib,"ws2_32.lib")  // link with Winsock Library
	#include <Winsock2.h>              // most of the Winsock functions, structures, and definitions
	#include <WS2tcpip.h>              // new WinSock2 Protocol-Specific Annex document for TCP/IP
	#define close(s) closesocket(s)
	#define s_errno WSAGetLastError()  // error status for the last Windows Sockets operation that failed
	#define EWOULDBLOCK WSAEWOULDBLOCK // resource temporarily unavailable (10035)
	#define usleep(a) Sleep((a)/1000)  // in microsecond
	#define MSG_NOSIGNAL 0
	#define nonblockingsocket(s) {unsigned long ctl = 1;ioctlsocket( s, FIONBIO, &ctl );}
	typedef int socklen_t;
// end WINDOWS stuff
#else
	#include <inttypes.h>              // fixed size integer types, includes stdint.h
	#include <sys/types.h>             // data types
	#include <sys/ioctl.h>             // Generic I/O Control operations
	#include <fcntl.h>                 // manipulate file descriptor
	#include <sys/socket.h>            // Internet Protocol family (number of definitions of structures needed for sockets)
	#include <netinet/in.h>            // Internet Address family (constants and structures needed for internet domain addresses, e.g. sockaddr_in)
	#include <netinet/ip.h>            // declarations for ip header
	#include <netinet/udp.h>           // declarations for udp header
	#include <netdb.h>                 // definitions for network database operations
	#include <arpa/inet.h>             // for inet_pton(), inet_ntop(), inet_ntoa(), INET_ADDRSTRLEN
	#include <net/if.h>                // sockets local interfaces (ifreq structure)
	#define nonblockingsocket(s)  fcntl(s, F_SETFL, O_NONBLOCK) // nonblocking I/O on socket
	#define Sleep(a) usleep(a*1000)    // in milliseconds
#endif

// local includes
#include "errors.h"
#include "utils.h"
#include "parser.h"
#include "signal.h"

#include "network.h"

#define NET_INTERVAL_USEC 1*1000 // 1msec

// bind port for broadcast UDP send if not defined ETHERNET_INTERFACE:HOST_IP:PORT
#define RTM_IP "100.1.1.255" // real-time machine IP
#define RTM_PORT 10005       // real-time machine port

#define USE_SOCK_RAW 0 // NOTE: 1(true) requires the root access

static void *networkThread(void *arg);
static void networkThreadCleanup(void *arg); // automatically executed when a thread is canceled

// Internal structure describing a local server network configuration and states
typedef struct network_tag {
	pthread_t thread;           // thread for socket

	int sock;                   // local server (recv) socket
	bool sockOpen;              // true if socket is open
	int sockSend;               // send socket
	bool sockSendOpen;          // true if sockSend is open

	int serverFilterInterface;  // filter by the type of local network card (interface index)

	struct sockaddr_in si_send; // address for writing responses

} network_t, *network_p;

static network_t netThread;

// used to pass data to the processing functions
static PacketData packetData;

// handle to callback
static void (*packetRecvCallbackFn)(const PacketData*);   // parse incoming data from XPC
//static void (*packetSendCallbackFn)(const void*); // send sensor data to XPC

bool parseNetworkAddress(const char* str, NetworkAddress* addr) {
	char *ptr1 = NULL, *ptr2 = NULL;
	char interface[MAX_INTERFACE_LENGTH];
	char host[MAX_HOST_LENGTH];

	DPRINTF(("parsing %s\n", str));

	// find first colon
	ptr1 = strchr(str, ':');
	if (ptr1 != NULL) {   // find second colon
		ptr2 = strchr(ptr1+1, ':');
	}

	if (ptr2 == NULL) {
		// no interface specified
		if (ptr1 == NULL) { // no host specified, just port
			setNetworkAddress(addr, "", "", atoi(str));
		} else {
			int len = ptr1 - str;
			strncpy(host, str, len);
			host[len] = '\0'; // null character

			if ( isValidIpAddress(host) )
				setNetworkAddress(addr, "", host, atoi(ptr1+1));
		}
	} else {
		// interface and host specified
		int len = ptr1 - str;
		if (len > MAX_INTERFACE_LENGTH-1) {
			fprintf(stderr, "Network interface name is limited to %i characters\n", MAX_INTERFACE_LENGTH-1);
			return false;
		}
		strncpy(interface, str, len);
		interface[len] = '\0'; // null character

		len = ptr2 - (ptr1+1);
		if (len <= 0)          // no host specified
			strcpy(host, "");
		else {
			strncpy(host, ptr1+1, len);
			host[len] = '\0';    // null character
		}

		if ( isValidIpAddress(host) )
			setNetworkAddress(addr, interface, host, atoi(ptr2+1));
	}

	return (addr->port > 0);
}

bool isValidIpAddress(const char *ipAddress) {
	if ( strcmp(ipAddress, "localhost") == 0 )
		return true;

	struct sockaddr_in sa; // structure for handling internet address. defined in netinet/in.h
	// convert an Internet address in its standard IPv4 dotted-decimal text format into its numeric binary form
	int result = inet_pton(AF_INET, ipAddress, &(sa.sin_addr));
	return result == 1;
}

void setNetworkAddress(NetworkAddress* addr, const char *interface, const char* host, unsigned int port) {
	strncpy(addr->interface, interface, MAX_INTERFACE_LENGTH-1);
	addr->interface[MAX_INTERFACE_LENGTH-1] = '\0';
	strncpy(addr->host, host, MAX_HOST_LENGTH-1);
	addr->host[MAX_HOST_LENGTH-1] = '\0';
	addr->port = port;
}

char netStrBuf[MAX_INTERFACE_LENGTH + MAX_HOST_LENGTH + 10];
const char * getNetworkAddressAsString(const NetworkAddress *addr) {
	char *bufPtr = netStrBuf;

	if ( strlen(addr->interface) == 0 )
		strcpy(bufPtr, "");
	else {
		// write formatted output to sized buffer
		snprintf(bufPtr, MAX_INTERFACE_LENGTH+1, "%s:", addr->interface);
		bufPtr[MAX_INTERFACE_LENGTH+1] = '\0';
		bufPtr += strlen(bufPtr);
	}

	if (strcmp(addr->host, "") == 0)
		snprintf(bufPtr, MAX_HOST_LENGTH+10, "0.0.0.0:%u", addr->port);
	else
		snprintf(bufPtr, MAX_HOST_LENGTH+10, "%s:%u", addr->host, addr->port);

	return (const char*) netStrBuf;
}

// configurate and start UDP server (bind recv addr to the socket)
int startServer(const NetworkAddress *addr) {
	char ipstr[INET_ADDRSTRLEN]; // final IPv4 address as a character string

	// setup local address info
	struct addrinfo hints, *result = 0, *p;
	const char *host, *interface;
	char portString[20];
	snprintf(portString, 20, "%u", addr->port);

	if (addr->host[0] == '\0' || strlen(addr->host) == 0)
		host = NULL;
	else
		host = addr->host;

	if (addr->interface[0] == '\0' || strlen(addr->interface) == 0)
		interface = NULL;
	else
		interface = addr->interface;

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;      // IPv4
	hints.ai_socktype = SOCK_DGRAM; // UDP datagrams socket
	hints.ai_protocol = 0;          // left unspecified
	hints.ai_flags = AI_PASSIVE | AI_ADDRCONFIG; // fill my IP address for me if host is NULL (wildcard IP address)

	// get the list of address structures
	int status = 0;
	if ( (status = getaddrinfo(host, portString, &hints, &result)) != 0 ) {
		fprintf(stderr, "Network: getaddrinfo(%s) returned error: %s\n", host, gai_strerror(status));
		return NETWORK_ERROR_SETUP;
	}

	// loop through all results and bind the first we can
	int sock;
	for (p = result; p != NULL; p = p->ai_next) {
		// open socket
		if (USE_SOCK_RAW)
			sock = socket(AF_INET, SOCK_RAW, IPPROTO_UDP);
		else
			sock = socket(p->ai_family, p->ai_socktype, p->ai_protocol);

		if (sock == -1) {
			errno_print("Network: Creation of Socket(SOCK_DGRAM/IPPROTO_UDP) failed");
			continue;
		}

		if (set_network_socket_attribs(sock, interface) == NETWORK_ERROR_SETUP) {
			close(sock);
			continue;
		}

		// generate IP string by converting a numeric network address (binary) into a text string
		inet_ntop(AF_INET, &(((struct sockaddr_in*)p->ai_addr)->sin_addr), ipstr, sizeof(ipstr));

		// bind the socket to the address of the current host and port number on which the server will run
		if ( bind(sock, p->ai_addr, p->ai_addrlen) == -1 ) {
			fprintf(stderr, "Network: Bind could not bind address %s:%u\n", ipstr, addr->port);
			close(sock);
			continue;
		}

		break; // Success
	}

	if (p == NULL) { // none in the list worked
		fprintf(stderr, "Could not open server socket\n");
		freeaddrinfo(result); // done with the list of results
		return NETWORK_ERROR_SETUP;
	}

	logInfo("Network: UDP server started at %s:%u\n", ipstr, addr->port);

	// done with the list of results
	freeaddrinfo(result);

	netThread.sock = sock;
	netThread.sockOpen = true;

	return 0;
}

int set_network_socket_attribs(const int sock, const char *interface) {
	int status;
	const int yes = 1;

	// set socket buffer size big enough to avoid dropped packets
	int length = MAX_PACKET_LENGTH*50;
	status = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, (char*)&length, sizeof(int));
	if (status == -1) {
		errno_print("Network: Error setting socket receive buffer size");
		return NETWORK_ERROR_SETUP;
	}

	// allow socket to send broadcast packets (if .255 dest ip is provided) (SOCK_DGRAM sockets only)
	status = setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, sizeof(int));
	if (status == -1) {
		errno_print("Network: Error setting broadcast permissions!");
		return NETWORK_ERROR_SETUP;
	}

	int serverFilterInterface = -1;
	// optional
	if (interface != NULL) { // store the interface index so we can compare later
		struct ifreq ifr;
		memset(&ifr, 0, sizeof(ifr));
		strncpy(ifr.ifr_name, interface, sizeof(ifr.ifr_name));

		// retrieve the interface index of the interface into ifr_ifindex
#ifdef SIOCGIFINDEX
		if ( ioctl(sock, SIOCGIFINDEX, &ifr) < 0 ) {
			errno_print("Network: ioctl error");
			return NETWORK_ERROR_SETUP;
		}
		serverFilterInterface = ifr.ifr_ifindex;
#else
		serverFilterInterface = if_nametoindex(ifr.ifr_name);
		if (serverFilterInterface == 0) {
			errno_print("Network: if_nametoindex error");
			return NETWORK_ERROR_SETUP;
		}
#endif

		// attempt to bind device to this interface index
#ifdef __APPLE__
		status = setsockopt(sock, IPPROTO_TCP, IP_BOUND_IF, &serverFilterInterface, sizeof(serverFilterInterface) );
#else
		status = setsockopt(sock, SOL_SOCKET, SO_BINDTODEVICE, (void*)&ifr, sizeof(ifr));
#endif
		if (status == -1) {
			fprintf(stderr, "Network: Could not bind to device interface %s. Try as root?\n : %s\n",
				 	interface, strerror(errno));
			return NETWORK_ERROR_SETUP;
		}
	}

	netThread.serverFilterInterface = serverFilterInterface;

	// receive ancillary packet information at recvmsg()
	status = setsockopt(sock, IPPROTO_IP, IP_PKTINFO, &yes, sizeof(yes));
	if (status == -1) {
		errno_print("Network: Error setting option IPPROTO_IP");
		return NETWORK_ERROR_SETUP;
	}

	// allow socket reuse for listening
	status = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
	if (status == -1) {
		errno_print("Network: Could not enable SO_REUSEADDR");
		return NETWORK_ERROR_SETUP;
	}

	return 0;
}

void stopServer(const int sock) {
	logInfo("Network: Terminating UDP server\n");
	if (netThread.sockOpen)
		close(sock);
	netThread.sockOpen = false;
}

// install the callback function to process incoming packets
void networkSetPacketRecvCallbackFn(void (*fn)(const PacketData*)) {
	packetRecvCallbackFn = fn;
}

/*
// install the callback function to prepare outcoming packets
void networkSetPacketSendCallbackFn(void (*fn)(const void*)) {
	packetSendCallbackFn = fn;
}
*/

// automatically executed when a thread is canceled
static void networkThreadCleanup(void *arg) {
	logInfo("Network: ==> Terminating network thread\n");
	networkCloseSendSocket();
	stopServer(netThread.sock);
}

// Start Network Thread
//int networkThreadStart(const NetworkAddress* recv_addr, const NetworkAddress *send_addr, const (void*)arg) {
int networkThreadStart(const NetworkAddress* recv_addr, const NetworkAddress *send_addr) {
	// start local (recv) server
	if (startServer(recv_addr) == NETWORK_ERROR_SETUP) {
		fprintf(stderr, "Network: Could not start server\n");
		return NETWORK_ERROR_SETUP;
	}

	// start network send
	networkOpenSendSocket(send_addr);

	//int status = pthread_create(&(netThread.thread), NULL, networkThread, (void*)arg);
	int status = pthread_create(&(netThread.thread), NULL, networkThread, NULL);
	if (status) {
		err_print(status, "Network: Return code from pthread_create()");
		return NETWORK_ERROR_SETUP;
	}

	return 0;
}

void networkThreadTerminate() {
	void *res = NULL;
	int status;
	status = pthread_cancel(netThread.thread);     // send a cancellation request to the netTread
	if (status != 0)
		err_abort(status, "Network: Cancel thread");

	status = pthread_join(netThread.thread, &res); // wait for thread termination
	if (status != 0)
		err_abort(status, "Network: Join thread");

	if (res == PTHREAD_CANCELED)
		logInfo("Network: Network thread was canceled\n");
	else
		logInfo("Network: Network thread terminated normally\n");
}

static void *networkThread(void *arg) {
	int status;
	// thread is cancelable (default)
	status = pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
	if (status != 0)
		err_abort(status, "Network: setcancelstate");
	// keep the cancellation request pending until the next cancellation point (default)
	//status = pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, NULL);
	//if (status != 0)
	//	err_abort(status, "Network: setcanceltype");
	// pushes routine networkReceiveThreadCleanup onto the top of the stack of clean-up handlers
	pthread_cleanup_push(networkThreadCleanup, arg);

	int bytesRecv = -1;
	while(1) {
		// -- listen to the network and parse the packetData if any
		status = networkRecv(&packetData, bytesRecv, MSG_DONTWAIT); // non-blocking recvmsg
		//if (status != 0)
		//	DPRINTF(("Network: networkRecv error\n"));
		pthread_testcancel(); // a cancellation point
	}

	// removes the routine networkReceiveThreadCleanup at the top of the stack of clean-up handlers
	pthread_cleanup_pop(0);

	return NULL;
}

// The recv call uses a msghdr structure which is defined in <sys/socket.h>. More info: man recvmsg
int networkRecv(PacketData *p, int bytesRecv, int flags) {
	uint8_t rawPacket[MAX_PACKET_LENGTH];

	struct msghdr msgh;
	struct iovec io;                // scatter/gather array items, as discussed in man readv
	struct sockaddr_in si_sender;   // source address
	char controlbuf[0x100];         // = 256
	struct cmsghdr *cmsg;           // control message sequence

	// prepare to receive packet info
	memset(&io, 0, sizeof(io));
	io.iov_base = rawPacket;                  // starting address
	io.iov_len = MAX_PACKET_LENGTH;           // number of bytes to transfer

	memset(&msgh, 0, sizeof(msgh));
	msgh.msg_iov = &io;                       // scatter/gather locations
	msgh.msg_iovlen = 1;                      // # elements in msg_iov
	msgh.msg_name = &si_sender;               // source (optional) address (NULL if no name)
	msgh.msg_namelen = sizeof(si_sender);     // size of address
	msgh.msg_control = controlbuf;            // control-related messages or miscellaneous ancillary data
	msgh.msg_controllen = sizeof(controlbuf); // ancillary data buffer length

	// read from the socket
	bytesRecv = recvmsg(netThread.sock, &msgh, flags);

	if (bytesRecv == -1) {
		//DPRINTF(("Network: recvmsg() at \"%s\":%d : %s\n", __FILE__, __LINE__, strerror (errno)));
		return NETWORK_ERROR_RECV;
	}

	// filter by interface index
	if (netThread.serverFilterInterface > 0) {
		// loop through control headers in msgh to get PKTINFO structure about the incoming packet
		for (cmsg = CMSG_FIRSTHDR(&msgh); cmsg != NULL; cmsg = CMSG_NXTHDR(&msgh, cmsg)) {
			if (cmsg->cmsg_level == IPPROTO_IP && cmsg->cmsg_type == IP_PKTINFO)
				break;
		}

		if (cmsg != NULL) {
			struct in_pktinfo *pi = (struct in_pktinfo*)CMSG_DATA(cmsg); // man 7 ip
			unsigned int ifindex = pi->ipi_ifindex; // get the index of the interface the packet was received on

			DPRINTF(("Network: Received packet from interface %u to %s (local %s)\n",
						ifindex, inet_ntoa(pi->ipi_addr), inet_ntoa(pi->ipi_spec_dst)));

			if (netThread.serverFilterInterface != (int)ifindex) {
				fprintf(stderr, "Network: Rejecting packet at interface %u (only accept at %u)\n",
						ifindex, netThread.serverFilterInterface);
				return NETWORK_ERROR_RECV;
			} else {
				DPRINTF(("Network: Accepting packet at interface %u\n", ifindex));
			}
		} else {
			fprintf(stderr, "Network: Could not access packet receipt message header\n");
			return NETWORK_ERROR_RECV;
		}
	}

	DPRINTF(("Network: Received %d bytes!\n", bytesRecv));

	// get IP and UDP headers of RAW packet if present
	int header_size = 0;
	if (USE_SOCK_RAW) {
		// get IP header of RAW packet
#ifdef __APPLE__
		struct ip *iph = (struct ip *)(rawPacket);
		unsigned short iphdrlen = iph->ip_hl*4;  // 20
		//unsigned short iphdrlen = sizeof(struct ip); // 20
#else
		struct iphdr *iph = (struct iphdr *)(rawPacket);
		unsigned short iphdrlen = iph->ihl*4;  // 20
		//unsigned short iphdrlen = sizeof(struct iphdr); // 20
#endif
		// get UDP header of RAW packet
		struct udphdr *udph = (struct udphdr*)(rawPacket + iphdrlen);
		header_size = iphdrlen + sizeof(udph); // 8
	}

	// read the raw packet and check its checksum
	bool validPacket = processRawPacket(rawPacket + header_size, bytesRecv - header_size, &packetData);

	// pass the packetData to the callback function
	if (validPacket) {
		if (packetRecvCallbackFn != NULL) {
			packetRecvCallbackFn(&packetData);
		} else {
			fprintf(stderr, "Network: No packetRecvCallbackFn specified!\n");
		}
	} else {
		fprintf(stderr, "Network: Invalid packet checksum\n");
	}

	return validPacket ? 0 : NETWORK_ERROR_RECV;
}

// look at the raw data off the socket and convert that into a PacketData struct.
//
// packetData is the byte stream received directly off of the socket
// the raw data contains a 4 bit header, followed by 2 byte uint16 length, and a 2 byte uint16 checksum
bool processRawPacket(uint8_t *rawPacket, int bytesRead, PacketData *p) {
	// parse rawPacket into a PacketData struct
	memset(p, 0, sizeof(PacketData));

	const uint8_t* pBuf = rawPacket;

	if (bytesRead < 8)
		return false;

	int headerLength = 4;

	// store the length
	memcpy(&(p->length), pBuf, sizeof(uint16_t)); pBuf += sizeof(uint16_t);

	if (p->length > bytesRead - headerLength) {
		fprintf(stderr, "Invalid packet length!\n");
		return false;
	}

	// store the checksum
	memcpy(&(p->checksum), pBuf, sizeof(uint16_t)); pBuf += sizeof(uint16_t);

	// copy the raw data into the data buffer
	memcpy(p->data, pBuf, p->length*sizeof(uint8_t));

	// validate the checksum: sum(bytes as uint8) modulo 2^16
	uint32_t accum = 0;
	for (int i=0; i < p->length; i++)
		accum += p->data[i];
	accum = accum % 65536;

	// return true if checksum valid
	return accum == p->checksum;
}

// start network send
int networkOpenSendSocket(const NetworkAddress *send_addr) {
	const char *host; // in the standard IPv4 dotted decimal notation

	if (send_addr->host[0] == '\0' || strlen(send_addr->host) == 0)
		host = RTM_IP;
	else
		host = send_addr->host;

	memset((char *) &(netThread.si_send), 0, sizeof(struct sockaddr_in));
	netThread.si_send.sin_family = AF_INET;              // IPv4
	netThread.si_send.sin_addr.s_addr = inet_addr(host); // to an integer value suitable for use as an Internet address
	netThread.si_send.sin_port = htons(send_addr->port);      // convert from host byte order to network byte order

	netThread.sockSend = netThread.sock; // use the same socket for receiving and sending
	netThread.sockSendOpen = false;

	printf("Network: Ready to send to %s:%d\n", host, send_addr->port);

	return 0;
}

void networkCloseSendSocket() {
	netThread.sockSendOpen = false;
}

bool networkSend(const char *sendBuffer, unsigned bytesSend) {
	if ( sendto(netThread.sockSend, (char *)sendBuffer, bytesSend,
				0, (struct sockaddr *)&(netThread.si_send), sizeof(struct sockaddr_in)) == -1 ) {
		errno_print("Network: Sendto error");
		return false;
	}
	return true;
}
