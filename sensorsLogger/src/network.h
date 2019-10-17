#ifndef __NETWORK_H_
#define __NETWORK_H_

#include <stdbool.h>  // boolean type and values true(1) and false(0)
#include <inttypes.h> // fixed size integer types, includes stdint.h

#include "sensorsThread.h"

#define MAX_HOST_LENGTH 46      // INET6_ADDRSTRLEN @ netinet/in.h
#define MAX_INTERFACE_LENGTH 16 // IFNAMSIZ @ if.h
typedef struct NetworkAddress {
    char interface[MAX_INTERFACE_LENGTH];
    char host[MAX_HOST_LENGTH];           // IPv4 dotted decimal notation
    unsigned int port;
} NetworkAddress;

// Packet data contents
#define PACKET_HEADER_STRING "#udp"
#define MAX_DATA_SIZE 65535
#define MAX_PACKET_LENGTH 65535
typedef struct PacketData {
    uint16_t checksum; // checksum for data
    uint8_t data[MAX_DATA_SIZE];
    uint16_t length;
} PacketData;

#define NETWORK_ERROR_SETUP 1
#define NETWORK_ERROR_SEND  2
#define NETWORK_ERROR_RECV  3

bool parseNetworkAddress(const char *str, NetworkAddress *addr);
bool isValidIpAddress(const char *ipAddress);
void setNetworkAddress(NetworkAddress *addr, const char *interface, const char *host, unsigned int port);
const char * getNetworkAddressAsString(const NetworkAddress *addr);

// configurate and start UDP server (bind recv_addr to the socket)
int startServer(const NetworkAddress *recv_addr);
// stop UDP server
void stopServer(const int sock);
// Setting the attributes of the network socket
int set_network_socket_attribs(const int sock, const char *interface);

// recv/send, parse, buffering thread
int networkThreadStart(const NetworkAddress *recv_addr, const NetworkAddress *send_addr, const serialList_t *s);
void networkThreadTerminate();
int networkRecv(PacketData *p, int bytesRecv, int flags);
void networkSetPacketRecvCallbackFn(void (*fn)(const PacketData*));

// send utilities
int networkOpenSendSocket(const NetworkAddress *send_addr);
void networkCloseSendSocket();
bool networkSend(const char *sendBuffer, unsigned int bytesSend);
void networkSetPacketSendCallbackFn(void (*fn)(const serialDevice *dev));

bool processRawPacket(uint8_t *rawPacket, int bytesRecv, PacketData *p);

#endif // ifndef __NETWORK_H_
