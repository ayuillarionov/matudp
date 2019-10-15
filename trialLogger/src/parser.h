#ifndef PARSER_H_INCLUDED
#define PARSER_H_INCLUDED

#include "network.h"
#include "signal.h"

// this is the callback function called by the network thread
// to receive packet data placed into a PacketData struct
//
// process the raw data stream and parse into signals,
// push these signals to the signal buffer
//
// returns true if parsing successful
void processReceivedPacketData(const PacketData*);

// given the bytestream buffer, read the next few bytes of buffer which
// are expected to constitute a serialized group info header, store the group info in pg,
// and return the advanced pointer into the buffer (i.e. to the next unread character)
//
// if group header parsing fails, returns NULL
//
// this will need to match +BusSerialize/serializeDataLoggerHeader.m
const uint8_t *parseGroupInfoHeader(const uint8_t*, GroupInfo*);

// parses a single signal sample off the bytestream buffer
// and stores the information and data in ps
//
// if parsing fails, returns NULL
// if parsing successful, returns a pointer to the next unread byte in the buffer
const uint8_t *parseSignalFromBuffer(const uint8_t*, SignalSample*);

#endif // ifndef PARSER_H_INCLUDED

