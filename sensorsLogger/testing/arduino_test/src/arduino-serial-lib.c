/*
 * File Name : arduino-serial-lib.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Tue 29 Jan 2019 08:25:02 PM CET
 * Modified  : Wed 30 Jan 2019 07:21:42 PM CET
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-43-lowlatency x86_64 x86_64
 *
 * Purpose   : communication with Arduino board. Works on any POSIX system (Mac/Unix/PC).
 */

#include "arduino-serial-lib.h"

#include <stdio.h>    // Standard input/output definitions 
#include <unistd.h>   // UNIX standard function definitions 
#include <fcntl.h>    // File control definitions 
#include <errno.h>    // Error number definitions 
#include <termios.h>  // POSIX terminal control definitions 
#include <string.h>   // String function definitions 
#include <sys/ioctl.h>

#ifdef DEBUG  
	#define SERIALPORTDEBUG 
#endif

// Takes the string name of the serial port (e.g. "/dev/tty.usbserial", "COM1", ...)
// and a baud rate (bps) and connects to that port at that speed and 8N1.
// Opens the port in fully raw mode so you can send binary data.
// Returns valid fd, or -1 on error.
int serialPort_init(const char* serialPort, int baud) {
	struct termios tOptions;
	int fd;

	fd = open(serialPort, O_RDWR | O_NOCTTY);              // open in blocking mode with no terminal control
	//fd = open(serialPort, O_RDWR | O_NOCTTY | O_NDELAY); // open in non-blocking mode with no terminal control
	//fd = open(serialPort, O_RDWR | O_NONBLOCK);          // open in non-blocking mode

	if (fd == -1) {
		perror("serialPort_init: Unable to open port");
		return -1;
	}

	//int iflags = TIOCM_DTR;
	//ioctl(fd, TIOCMBIS, &iflags);    // turn on DTR
	//ioctl(fd, TIOCMBIC, &iflags);    // turn off DTR

	if (tcgetattr(fd, &tOptions) < 0) {
		perror("serialPort_init: Couldn't get term attributes");
		return -1;
	}

	speed_t brate = baud; // let you override switch below if needed

	switch (baud) {
		case 4800:    brate = B4800;    break;
		case 9600:    brate = B9600;    break;
#ifdef B14400
		case 14400:   brate = B14400;   break;
#endif
		case 19200:   brate = B19200;   break;
#ifdef B28800
		case 28800:   brate = B28800;   break;
#endif
		case 38400:   brate = B38400;   break;
		case 57600:   brate = B57600;   break;
	 	case 115200:  brate = B115200;  break;
	 	case 230400:  brate = B230400;  break;
	 	case 460800:  brate = B460800;  break;
	 	case 500000:  brate = B500000;  break;
	 	case 576000:  brate = B576000;  break;
	 	case 921600:  brate = B921600;  break;
	 	case 1000000: brate = B1000000; break;
	 	case 1152000: brate = B1152000; break;
	 	case 1500000: brate = B1500000; break;
	 	case 2000000: brate = B2000000; break;
	 	case 2500000: brate = B2500000; break;
	 	case 3000000: brate = B3000000; break;
	 	case 3500000: brate = B3500000; break;
	 	case 4000000: brate = B4000000; break;
	}

	cfsetispeed(&tOptions, brate);
	cfsetospeed(&tOptions, brate);

	// 8N1
	tOptions.c_cflag &= ~PARENB; /* disables the parity enable bit (PARENB), so no parity   */
	tOptions.c_cflag &= ~CSTOPB; /* CSTOPB = 2 stop bits, here it is cleared so 1 stop bit  */
	tOptions.c_cflag &= ~CSIZE;  /* clears the mask for setting the data size               */
	tOptions.c_cflag |= CS8;     /* set the data bits = 8                                   */

	tOptions.c_cflag &= ~CRTSCTS; /* no hardware flow control                               */

	//tOptions.c_cflag &= ~HUPCL; // disable hang-up-on-close to avoid reset

	tOptions.c_cflag |= CREAD | CLOCAL;  // turn on READ & ignore ctrl lines

	/* Input mode flags. Setup for non-canonical mode */
	tOptions.c_iflag &= ~(IXON | IXOFF | IXANY); // turn off s/w flow ctrl
	tOptions.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG); // make raw - Non-Cannonical mode

	/* Output mode flags. Setup for non-canonical mode */
	tOptions.c_oflag &= ~OPOST; /* no output processing */

	// see: http://unixwiz.net/techtips/termios-vmin-vtime.html
	tOptions.c_cc[VMIN]  = 0;
	tOptions.c_cc[VTIME] = 0; // wait indefinetly
	//tOptions.c_cc[VTIME] = 20; // wait 2 seconds

	/* apply the configuration */
	tcsetattr(fd, TCSANOW, &tOptions);

	if (tcsetattr(fd, TCSAFLUSH, &tOptions) < 0) {
		perror("init_serialport: Couldn't set term attributes");
		return -1;
	}

	return fd;
}

//
int serialPort_close(int fd) {
	serialPort_flush(fd);
	return close(fd);
}

//
int serialPort_writeByte(int fd, uint8_t b) {
	if (write(fd, &b, 1) != 1)
		return -1;
	return 0;
}

//
int serialPort_write(int fd, const char* str) {
	int len = strlen(str);
	if (write(fd, str, len) != len) {
		perror("serialPort_write: couldn't write whole string\n");
		return -1;
	}
	return 0;
}

//
int serialPort_readByte(int fd, int timeOut) {
	uint8_t byte;
	int nBytes = -1, counter = 0, timeOutLocal = timeOut*10;
	do {
		nBytes = read(fd, &byte, 1);
		if (nBytes == -1)             // couldn't read
      return -1;
		if (nBytes != 1) {
      usleep(0.1 * 1000); // sleep 0.1 ms
      timeOutLocal--;
      if (timeOutLocal == 0)
				return -2;
      continue;
    }
#ifdef SERIALPORTDEBUG  
		printf("serialPort_readByte: counter = %d, nBytes = %d --> n = %d\n", counter, nBytes, byte); // debug
#endif
    counter++;
  } while (nBytes != 1 && timeOutLocal > 0);
	return (int)byte;
}

//
int serialPort_read_until(int fd, char* buf, char until, int buf_max, int timeOut) {
	char ch[1];  // read expects an array, so we give it a 1-byte array

	int nBytes = -1, counter = 0, timeOutLocal = timeOut*10;
	do {
		nBytes = read(fd, ch, 1);  // read a char at a time
		if (nBytes == -1)             // couldn't read
			return -1;
		if (nBytes == 0) {
			usleep(0.1 * 1000);      // wait 0.1 msec try again
			timeOutLocal--;
			if (timeOutLocal == 0)
				return -2;
			continue;
		}
#ifdef SERIALPORTDEBUG  
		printf("serialPort_read_until: counter = %d, nBytes = %d ch = '%c'\n", counter, nBytes, ch[0]); // debug
#endif
		buf[counter] = ch[0];
		counter++;
	} while ( ch[0] != until && counter < buf_max && timeOutLocal > 0 );

	buf[counter] = 0;  // null terminate the string
	return 0;
}

/* discards the data in the Rx buffer */
int serialPort_flush(int fd) {
	sleep(2); // required to make flush work, for some reason
	return tcflush(fd, TCIOFLUSH);
}
