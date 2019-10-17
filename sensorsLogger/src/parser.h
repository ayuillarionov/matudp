#ifndef __PARSER_H_
#define __PARSER_H_

#include "network.h"
#include "sensorsThread.h"

// String list type. Used whenever we create a list of strings (e.g. file read).
typedef struct str_list {
	struct str_list *next;  // link to next member
	char *str;              // some string data
} str_list_t;

// Read a file or pipe stream; return a linked list of lines.
// NOTE: start_line is zero-based; lines == 0 -> read all lines
str_list_t *read_file(char *file_name, unsigned start_line, unsigned lines);
// free the memory allocated by a string list
str_list_t *free_str_list(str_list_t *list);

void processRecvPacketData(const PacketData*); // process incoming packets from XPC
void sendSensorsData(const serialDevice*);     // process sensors data and send it to XPC

#endif // ifndef __PARSER_H_
