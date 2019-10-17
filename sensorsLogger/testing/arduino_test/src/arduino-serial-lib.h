#ifndef __ARDUINO_SERIAL_LIB_H_
#define __ARDUINO_SERIAL_LIB_H_

#include <stdint.h>   // Standard types 

int serialPort_init(const char* serialPort, int baud);
int serialPort_close(int fd);
int serialPort_writeByte(int fd, uint8_t b);
int serialPort_write(int fd, const char* str);
int serialPort_readByte(int fd, int timeOut);
int serialPort_read_until(int fd, char* buf, char until, int buf_max, int timeOut);
int serialPort_flush(int fd);

#endif /* __ARDUINO_SERIAL_LIB_H_ */
