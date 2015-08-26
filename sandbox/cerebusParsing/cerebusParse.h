#ifndef __CEREBUS_PARSE_H__
#define __CEREBUS_PARSE_H__

#ifdef MATLAB_MEX_FILE
#include <tmwtypes.h>
#else
#include "rtwtypes.h"
#endif

/*
% Generic cbPKT data format
%
% values are little endian
%
% uint32 time  // cerebus 30kHz clock
% uint16 chid  // channel id (must be < 0x8000)
% uint8  type
% uint8  dlen  // number of 32-bit (4 byte) data chunks that follows
% *****  data

% -------------------------------------------------------
% cbPKT spike data format - Version 6.0300 of the firmware
%
% header info: 20 bytes
% spike waveform, max of 128 points (256 bytes)
% internal lab convention of 48 points (96 bytes) results in 1.2 ms data snippet
%
% uint32 time        // cerebus 30kHz clock
% uint16 chid        // channel id (must be 0 < chid < 145)
% uint8  unit        // unit classification (1-5 = sorted unit num, 0 = unclassified, 31 = artifact, 30 = background)
% uint8  dlen        // length of 32-bit (4 byte) data chunks that follows (should be  for our lab)
% float  fPattern[3] // used for automatic spike sorting
% int16  nPeak       // highest value in spike
% int16  nValley     // lowest values in spike
% int16  wave[48]    // spike waveform
%
% End documentation about function Here.
% ------------------------------------------------------
*/

// below is copied from cbhwlib.h
#define cbVERSION_MAJOR  3
#define cbVERSION_MINOR	 8

#define cbNUM_ANALOG_CHANS    144

// Generic Cerebus packet data structure (1024 bytes total)
typedef struct {
    UINT32_T time;        // system clock timestamp
    UINT16_T chid;        // channel identifier
    UINT8_T  type;        // packet type
    UINT8_T  dlen;        // length of data field in 32-bit chunks
    UINT32_T data[254];   // data buffer (up to 1016 bytes)
} cbPKT_GENERIC;

#define cbPKT_HEADER_SIZE 8  // define the size of the packet header in bytes

// Sample Group data packet
typedef struct {
    UINT32_T  time;       // system clock timestamp
    UINT16_T  chid;       // 0x0000
    UINT8_T   type;       // sample group ID (1-127)
    UINT8_T   dlen;       // packet length equal
    INT16_T   data[252];  // variable length address list
} cbPKT_GROUP;

// AINP spike waveform data
// cbMAX_PNTS must be an even number
#define cbMAX_PNTS  128 // make large enough to track longest possible - spike width in samples

typedef struct {
    UINT32_T time;                // system clock timestamp
    UINT16_T chid;                // channel identifier
    UINT8_T  unit;                // unit identification (0=unclassified, 31=artifact, 30=background)
    UINT8_T  dlen;                // length of what follows ... always  cbPKTDLEN_SPK
    REAL32_T fPattern[3];         // values of the pattern space (Normal uses only 2, PCA uses third)
    INT16_T  nPeak;
    INT16_T  nValley;
    // wave must be the last item in the structure because it can be variable length to a max of cbMAX_PNTS
    INT16_T  wave[cbMAX_PNTS];    // Room for all possible points collected
} cbPKT_SPK;

#define cbPKTDLEN_SPK   ((sizeof(cbPKT_SPK)/4)-2)
#define cbPKTDLEN_SPKSHORT (cbPKTDLEN_SPK - ((sizeof(INT16)*cbMAX_PNTS)/4))

// Replacements for NB Extract block
cbPKT_GENERIC* cb_nbExtractPacketData(uint32_T* nbInput, uint32_T* pDataLen);
bool cb_nbFree(uint32_T* nbInput);

UINT32_T cb_getTime(cbPKT_GENERIC* pp);
UINT16_T cb_getChannel(cbPKT_GENERIC* pp);
UINT8_T cb_getSpikeUnit(cbPKT_GENERIC* pp);
bool cb_isSpikePacket(cbPKT_GENERIC* pp);
bool cb_isContinuousPacketForGroup(cbPKT_GENERIC* pp, UINT8_T group);
UINT8_T cb_getContinuousGroup(cbPKT_GENERIC* pp);
cbPKT_GENERIC* cb_getPointer(cbPKT_GENERIC* pp);
cbPKT_GENERIC* cb_getNext(cbPKT_GENERIC* pp);
void cb_copySpikeWaveform(cbPKT_GENERIC* pp, INT16_T* buffer, int maxSamples);
void cb_copyContinuousSamples(cbPKT_GENERIC* pp, INT16_T* buffer, int maxChannels);
#endif // #ifndef __CEREBUS_PARSE_H__
