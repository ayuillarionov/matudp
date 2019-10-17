/*
 * File Name : parser.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Thu 14 Mar 2019 04:37:28 PM CET
 * Modified  : Sat 25 May 2019 10:52:29 AM CEST
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-46-lowlatency x86_64 x86_64
 *
 * Purpose   : This are the callback functions called by the network thread
 *             -- to receive packet data placed into a PacketData struct
 *             -- to send sensors data placed into a serialDevice struct
 */

#include "errors.h"  // include stdio, stdlib, errno, string, unistd
#include "parser.h"

// private declarations
int convertSensorsDataToBytestream(uint8_t*, uint16_t, const serialDevice*);
bool addHeader(uint8_t*, uint16_t);

void processRecvPacketData(const PacketData *p) {
}

void sendSensorsData(const serialDevice *dev) {
	uint8_t sendBuffer[MAX_PACKET_LENGTH];
	int totalBytesSend;

	// convert sensors data to bytes to send
	totalBytesSend = convertSensorsDataToBytestream(sendBuffer, MAX_PACKET_LENGTH, dev);
	if (totalBytesSend < 0) {
		fprintf(stderr, "Parser at \"%s\":%d : Cannot fit data into one packet!", __FILE__, __LINE__);
		return;
	}

	// add the header: 2 bytes uint16 data length, followed by 2 byte uint16 checksum.
	addHeader(sendBuffer, (uint16_t)totalBytesSend);

	if (!networkSend((char*)sendBuffer, (uint16_t)totalBytesSend)) {
		fprintf(stderr, "Parser at \"%s\":%d : Sendto error", __FILE__, __LINE__);
		return;
	}
}

// serialize sensors data
int convertSensorsDataToBytestream(uint8_t *buf, uint16_t sizebuf, const serialDevice *dev) {
	uint8_t *p = buf + 4; // reserve 4 bytes for header
	int bytes;

	memset(buf, 0, sizebuf);

	// name, serialNumber, manufacturer_id, device_id
	bytes = sprintf((char*)p,
		 	"#SensorsUDP\nPort = %s, Serial number = %s, Manufacturer ID = %d, Device ID = %d\n",
			dev->name, dev->serialNumber, dev->manufacturer_id, dev->device_id);
	p += bytes;

	// sampling rate
	memcpy(p, &dev->sampleTime, sizeof(double)); p += sizeof(double);

	// channelsData
	memcpy(p, &dev->data, sizeof(dev->data)); p += sizeof(dev->data);

	// registers values
	memcpy(p, &dev->registers, sizeof(dev->registers)); p += sizeof(dev->registers);
	
	// printing..
	//for(int i=0; i<p-buf; i++)
	//	printf("%02X ", buf[i]);
	//printf("\n");

	return p-buf;
}

// add the header: 2 bytes uint16 data length, followed by 2 byte uint16 checksum.
bool addHeader(uint8_t *buf, uint16_t sizebuf) {
	if (sizebuf < 15) // 4 bytes header + 11 bytes "#SensorsUDP"
		return false;

	uint8_t *p = buf;

	// length
	memcpy(p, &sizebuf, sizeof(uint16_t)); p += sizeof(uint16_t);
	// checksum
	uint32_t accum = 0;
	for (uint16_t i=4; i < sizebuf; i++)
		accum += buf[i];
	uint16_t accum16 = accum % 65536;
	memcpy(p, &accum16, sizeof(uint16_t)); p += sizeof(uint16_t);

	return true;
}

// read a file or pipe; return a linked list of lines
// NOTE: start_line is zero-based; lines == 0 -> read all lines
str_list_t *read_file(char *file_name, unsigned start_line, unsigned lines) {
	FILE *f;
	char buf[0x10000];
	int pipe = 0;

	str_list_t *sl_start = NULL, *sl_end = NULL, *sl;

	if (*file_name == '|') {                // pipe stream from a process
		file_name++;
		if ( !(f = popen(file_name, "r")) ) {
			errno_print("read_file: Error opening pipe");
			return NULL;
		}
		pipe = 1;
	} else {
		if ( !(f = fopen(file_name, "r")) ) { // open the regular file
			errno_print("read_file: Error opening file");
			return NULL;
		}
	}

	while ( fgets(buf, sizeof buf, f) ) {
		if (start_line) {
			start_line--;
			continue;
		}

		sl = calloc(1, sizeof *sl);
		if (sl == NULL)
			errno_abort("read_file: memory calloc error");
    sl->str = strdup(buf); // malloc and duplicate the string
		if (sl->str == NULL)
			errno_abort("read_file: strdup error");

		if (sl_start)
			sl_end->next = sl;
		else
			sl_start = sl;
		sl_end = sl;

		if (lines == 1)
			break;

		lines--;
	}

	if (pipe)
		pclose(f);
	else
		fclose(f);

	return sl_start;
}

// free the memory allocated by a string list
str_list_t *free_str_list(str_list_t *list) {
	str_list_t *l;

	for (; list; list = (l = list)->next, free(l))
		free(list->str);

	return NULL;
}
