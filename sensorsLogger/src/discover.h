#ifndef __DISCOVER_H_
#define __DISCOVER_H_

#include <libusb-1.0/libusb.h>

#include "sensorsThread.h"

// deal with changes in libusb API:
#ifdef LIBUSB_API_VERSION
	#if LIBUSB_API_VERSION >= 0x01000106
		// since 1.0.22, libusb_set_option replaces libusb_set_debug
		#define HAVE_LIBUSB_SET_OPTION
		#define libusb_set_debug(context, level) libusb_set_option(context, LIBUSB_OPTION_LOG_LEVEL, level)
	#endif
#endif

static const char* const speed_name[5] = {
	"USB_SPEED_UNKNOWN",
	"1.5Mbit/s (USB_SPEED_LOW)",
	"12Mbit/s (USB_SPEED_FULL)",
	"480Mbit/s (USB_SPEED_HIGH)",
	"5000Mbit/s (USB_SPEED_SUPER)"
};

#define libusb_err_print(code, text) \
	fprintf (stderr, "%s (%d) at \"%s\":%d : %s\n", \
			text, code, __FILE__, __LINE__, libusb_strerror(code))
#define libusb_errno_print(text) \
	fprintf (stderr, "%s (%d) at \"%s\":%d : %s\n", \
			text, errno, __FILE__, __LINE__, libusb_strerror(errno))
#define libusb_err_abort(code, text) do { \
	libusb_err_print(code, text); \
	abort (); \
	} while (0)
#define libusb_errno_abort(text) do { \
	libusb_errno_print(text); \
	abort (); \
	} while (0)

// initialize libusb session, debugging and hotpluging
int libUSB_init(serialList_t *s, const bool verbose);
// terminate libusb hotplug thread, close libusb session
void libUSB_exit(void);
// set libusb verbosity
bool set_libUSBverbosity(const bool verbose);
// register device within serialList
int registerDevice(serialList_t *s, libusb_device *dev, const bool verbose);
// remove device from serialList
int removeDevice(serialList_t *s, libusb_device *dev, const bool verbose);
// scan for FDC2x14EVM devices and put them into serialList
int discoverDevices(serialList_t *s, const bool verbose);

int libUSB_threadStart(void);

#endif /* __DISCOVER_H_ */
