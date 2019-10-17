/*
 * File Name : discover.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Mon 18 Mar 2019 02:09:34 PM CET
 * Modified  : Wed May 15 18:17:10 2019
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-46-lowlatency x86_64 x86_64
 *
 * Purpose   : FDC2x14EVM hotplug USB discover
 *
 * LINUX note: Useful monitoring utils:
 *             udevadm monitor --udev --property       -- Print udev events with all properties
 *             udevadm info --name DEVNAME             -- Query sysfs or the udev database
 *             hwinfo --usb [--only DEVNAME]           -- Probe for usb
 * MACOS note: Useful monitoring utils:
 *             ioreg -rc IOSerialBSDClient
 *             ioreg -Src IOUSBDevice
 *             system_profiler SPUSBDataType
 */

#include <limits.h>   // implementation-defined constants (e.g., PATH_MAX)
#include <dirent.h>   // format of directory entries
#include <sys/stat.h> // structure of the data returned by the function [f,l]stat() about the files attributes
#include <libgen.h>   // pattern matching functions

#include "errors.h"   // error handling
#include "timer.h"    // profiling functions

#include "parser.h"

#include "discover.h"

static uint16_t VID = 0x2047; // vendor ID:  Texas Instruments
static uint16_t PID = 0x08F8; // product ID: MSP430-USB Example

#if defined(__linux__)
	#define DEV_REGISTRATION_TIME 18  // pause time (in secs) to get the system to register the hotplugged device
#elif defined(__APPLE__) && defined(__MACH__)
	#define DEV_REGISTRATION_TIME 1 

	#include <CoreFoundation/CoreFoundation.h>
	#include <IOKit/IOKitLib.h>
	#include <IOKit/usb/IOUSBLib.h>
	#include <IOKit/serial/IOSerialKeys.h>
	#include <IOKit/IOBSD.h>
#endif

static bool libusb_verbose = false;

// -- LIBUSB INFO PRINTING (forward declaration)
static void print_configuration(struct libusb_config_descriptor *config) __attribute__((unused));
static void print_interface(const struct libusb_interface *interface);
static void print_altsetting(const struct libusb_interface_descriptor *alt);
static void print_endpoint(const struct libusb_endpoint_descriptor *endpoint);
static void print_endpoint_comp(const struct libusb_ss_endpoint_companion_descriptor *ep_comp);

static libusb_context *ctx = NULL; // libusb session
static libusb_hotplug_callback_handle hotplug_callback_handle = 0;

pthread_t event_thread;            // thread for libusb
static void *libUSB_event_thread_func(void *ctx);
static void libUSB_threadCleanup(void *arg); // automatically executed when a thread is canceled
static int libUSB_event_thread_run = 1;

int libUSB_threadStart(void) {
	int status = pthread_create(&event_thread, NULL, libUSB_event_thread_func, NULL);
	if (status) {
		err_print(status, "libusb: Return code from pthread_create()");
		return status;
	}
	return 0;
}

void *libUSB_event_thread_func(void *arg) {
	// thread is cancelable (default)
	pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
	// keep the cancellation request pending until the next cancellation point (default)
	//pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, NULL);
	// push Cleanup routine onto the top of the stack of clean-up handlers
	pthread_cleanup_push(libUSB_threadCleanup, NULL);

	int status;
	while (libUSB_event_thread_run) {
		pthread_testcancel();        // a cancellation point
		status = libusb_handle_events_completed(ctx, NULL);
		if (status != LIBUSB_SUCCESS)
			errno_abort("libusb: handle_events_completed error");
	}

	// remove Cleanup routine at the top of the stack of clean-up handlers
	pthread_cleanup_pop(0);

	return NULL;
}

static void libUSB_threadCleanup(void *arg) {
	libUSB_exit();
	printf("libusb: Cleaning up the thread\n");
}

static int LIBUSB_CALL hotplug_callback(libusb_context *ctx, libusb_device *dev,
                     libusb_hotplug_event event, void *user_data) {
	(void)ctx;
	serialList_t *s = (serialList_t*)user_data;

	int status
		__attribute__((unused));
	if (event == LIBUSB_HOTPLUG_EVENT_DEVICE_ARRIVED) {
		printf("libusb [hotplug event]: ==> register new device (it takes about %u secs)\n", DEV_REGISTRATION_TIME);
		sleep(DEV_REGISTRATION_TIME); // let OS register device first
		status = registerDevice(s, dev, libusb_verbose);
		if (status >= 0) {
			printf("libusb [hotplug]: %s registered\n", s->tty[s->num_tty-1]->dev->name);
			// open new attached device
			s->tty[s->num_tty-1]->dev->fd = open_device(s->tty[s->num_tty-1]->dev, BAUDRATE);
			// start the device data streaming thread
			if (s->isThreadsStarted)
				sensorThreadStart(s->num_tty-1, s);
		} else
			err_print(status, "libusb [hotplug error]: registerDevice");
	} else if (event == LIBUSB_HOTPLUG_EVENT_DEVICE_LEFT) {
		status = removeDevice(s, dev, libusb_verbose);
		if (status >= 0) {
			printf("libusb [hotplug event]: ==> device removed\n");
		} else
			err_print(status, "libusb [hotplug error]: removeDevice");
	} else {
		fprintf(stderr, "libusb [hotplug error]: Unhandled event %d\n", event);
	}

	return 0;
}

int libUSB_init(serialList_t *s, const bool verbose) {
#ifdef DEBUG
	const struct libusb_version *v = LIBUSB_CALL libusb_get_version();
	if (strlen(v->rc) > 0)
		printf("==> Using libusb v%u.%u.%u.%u-%s (%s)\n", v->major, v->minor, v->micro, v->nano, v->rc, v->describe);
	else
		printf("==> Using libusb v%u.%u.%u.%u (%s)\n", v->major, v->minor, v->micro, v->nano, v->describe);
#endif // DEBUG

	// initialize the USB library session
	int status = LIBUSB_CALL libusb_init(&ctx);
	if (status != LIBUSB_SUCCESS) {
		fprintf(stderr, "libusb: Failed to initialise libusb: %s\n", libusb_error_name(status));
		return EXIT_FAILURE;
	}

	// check for hotplug support
	if ( !libusb_has_capability(LIBUSB_CAP_HAS_HOTPLUG) ) {
		errno_print("libusb: Hotplug support is NOT available on this platform");
		LIBUSB_CALL libusb_exit(NULL);
		return LIBUSB_ERROR_NOT_SUPPORTED;
	}

	// set debug level
	//libusb_verbose = set_libUSBverbosity(verbose);
	libusb_verbose = set_libUSBverbosity(true);

	// Register a hotplug_callback function listening both, arrived & left, events.
	// The callback will fire when a matching event occurs on a matching device.
	status = libusb_hotplug_register_callback(ctx,
			LIBUSB_HOTPLUG_EVENT_DEVICE_ARRIVED | LIBUSB_HOTPLUG_EVENT_DEVICE_LEFT,
			LIBUSB_HOTPLUG_NO_FLAGS,   // Don't parse the currently atatched devs, use discoverDevices at initialization
			//LIBUSB_HOTPLUG_ENUMERATE, // Arm the callback and fire it for all matching currently attached devices
			VID, PID, LIBUSB_HOTPLUG_MATCH_ANY,
			hotplug_callback, (void*)s, &hotplug_callback_handle);
	if (status != LIBUSB_SUCCESS) {
		fprintf (stderr, "Error registering hotplug_callback_arrived: %s\n", libusb_error_name(status));
		LIBUSB_CALL libusb_exit(NULL);
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}

void libUSB_exit(void) {
	if (libUSB_event_thread_run == 0)
		return;

	libUSB_event_thread_run = 0;

	if (hotplug_callback_handle != 0)   // this wakes up libusb_handle_events()
		LIBUSB_CALL libusb_hotplug_deregister_callback(ctx, hotplug_callback_handle);

	void *res = NULL;
	//pthread_cancel(event_thread);     // send a cancellation request to a thread
	pthread_join(event_thread, &res); // wait for thread termination
	if (res == PTHREAD_CANCELED)
		printf("libusb: Thread was canceled\n");
	else
		printf("libusb: Thread was terminated normally\n");

	if (ctx != NULL)
		LIBUSB_CALL libusb_exit(ctx);  // close the section
}

bool set_libUSBverbosity(const bool verbose) {
#ifdef DEBUG
	libusb_verbose = true;
	#ifdef HAVE_LIBUSB_SET_OPTION
		LIBUSB_CALL libusb_set_option(ctx, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_DEBUG);
	#else  // HAVE_LIBUSB_SET_OPTION
		LIBUSB_CALL libusb_set_debug(ctx, LIBUSB_LOG_LEVEL_DEBUG);
	#endif // HAVE_LIBUSB_SET_OPTION
#else  // DEBUG
	libusb_verbose = verbose;
	#ifdef HAVE_LIBUSB_SET_OPTION
		if (libusb_verbose)
			LIBUSB_CALL libusb_set_option(ctx, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_INFO);
		else
			LIBUSB_CALL libusb_set_option(ctx, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_NONE);
	#else  // HAVE_LIBUSB_SET_OPTION
		if (libusb_verbose)
			LIBUSB_CALL libusb_set_debug(ctx, LIBUSB_LOG_LEVEL_INFO);
		else
			LIBUSB_CALL libusb_set_debug(ctx, LIBUSB_LOG_LEVEL_NONE);
	#endif // HAVE_LIBUSB_SET_OPTION
#endif // DEBUG
	return libusb_verbose;
}

#if defined(__linux__)
__attribute__((unused))
static char *find_tty_name(char *devName, const char *sysPath) {
	struct dirent *ep;

	char ttyPath[PATH_MAX];
	snprintf(ttyPath, strlen(sysPath)+9, "%s:1.0/tty", sysPath); 

	DIR *dp = opendir(ttyPath);
	if (dp != NULL) {
		while ( (ep = readdir(dp)) != NULL )
			if ( strstr(ep->d_name, "tty") != NULL) {
				snprintf(devName, strlen(ep->d_name)+6, "/dev/%s", ep->d_name);
				break;
			}
		(void) closedir (dp);
	} else
		errno_abort("libusb: Couldn't open the directory");

	return devName;
}
#endif

#if defined(__APPLE__)
// creating a USB matching dictionary for the IOUSBDevice class and its subclasses
CFMutableDictionaryRef CreateUSBMatchingDictionary(SInt32 idVendor, SInt32 idProduct) {
	CFMutableDictionaryRef matchingDict = NULL;
	CFNumberRef	numberRef;

	// Create a matching dictionary for IOUSBDevice
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	if (matchingDict == NULL)
		goto bail;

	// Add the USB Vendor ID to the matching dictionary
	numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &idVendor);
	if (numberRef == NULL)
		goto bail;
	CFDictionaryAddValue(matchingDict, CFSTR(kUSBVendorID), numberRef);
	CFRelease(numberRef);

	// Add the USB Product ID to the matching dictionary
	numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &idProduct);
	if (numberRef == NULL)
		goto bail;
	CFDictionaryAddValue(matchingDict, CFSTR(kUSBProductID), numberRef);
	CFRelease(numberRef);

	// Success - return the dictionary to the caller
	return matchingDict;

bail: // Failure - release resources and return NULL
	if (matchingDict != NULL)
		CFRelease(matchingDict);

	return NULL;
}

// convert from a CFString to a C (NUL-terminated). NOTE: free it!
static char *CFStringToString(CFStringRef string) {
	if (!string)
		return NULL;

#ifdef DEBUG
	CFShow( CFCopyDescription(string) );
#endif // DEBUG

	CFIndex len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), CFStringGetSystemEncoding()) + sizeof('\0');
	char *buf = calloc(len, sizeof(char));
	if ( buf && CFStringGetCString(string, buf, len, CFStringGetSystemEncoding()) )
		return buf;
	else if (buf)
		free(buf);
	else
		errno_print("CFStringToString calloc error");

	return NULL;
}

// device's class name
__attribute__((unused))
static char *getDeviceClass(io_object_t device) {
	io_name_t name;
	if (IOObjectGetClass(device, name) == KERN_SUCCESS) {
		char *buf = calloc(strlen(name)+1, sizeof(char));
		strncpy(buf, name, strlen(name));
		return buf;
	}
	return NULL;
}

// device's name. For USB disks the default name is "USB DISK",
// but many manufacturers will substitute in their own brand name here.
__attribute__((unused))
static char *getDeviceName(io_object_t device) {
	io_name_t name;
	if (IORegistryEntryGetName(device, name) == KERN_SUCCESS) {
		char *buf = calloc(strlen(name)+1, sizeof(char));
		strncpy(buf, name, strlen(name));
		return buf;
	}
	return NULL;
}

static char *getStringDataForDeviceKey(io_object_t device, CFStringRef key) {
	CFTypeRef resultAsCFString = IORegistryEntrySearchCFProperty(
			device,	kIOServicePlane, key, kCFAllocatorDefault, kIORegistryIterateRecursively);
	return CFStringToString((CFStringRef)resultAsCFString);
}

static char *getPropertyString(io_object_t device, const char* key) {
	CFStringRef propertyName = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
	if (propertyName == NULL)
		return NULL;
	CFTypeRef propertyValue = IORegistryEntryCreateCFProperty(device, propertyName, kCFAllocatorDefault, 0);
	CFRelease(propertyName);
	if (propertyValue == NULL) {
		fprintf(stderr, "getPropertyString error: property %s does not exist\n", key);
		return NULL;
	}
	if ( CFGetTypeID(propertyValue) == CFStringGetTypeID() )
		return CFStringToString((CFStringRef)propertyValue);
	return NULL;
}

static unsigned int getPropertyInt(io_object_t device, const char* key) {
	CFStringRef propertyName = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
	if (propertyName == NULL)
		return 0;
	CFTypeRef propertyValue = IORegistryEntryCreateCFProperty(device, propertyName, kCFAllocatorDefault, 0);
	CFRelease(propertyName);
	if (propertyValue == NULL) {
		fprintf(stderr, "getPropertyInt error: property %s does not exist\n", key);
		return 0;
	}
	if ( CFGetTypeID(propertyValue) == CFNumberGetTypeID() ) {
		unsigned int result = 0;
#ifdef DEBUG
		CFShow(propertyValue);
#endif // DEBUG
		CFNumberGetValue((CFNumberRef)propertyValue, kCFNumberSInt32Type, &result);
		return result;
	}
	return 0;
}

__attribute__((unused))
static int get_OSX_info(hw_info_t *osxSPInfo, uint8_t libusb_addr) {
	// set up a matching dictionary for the IOUSBDevice class and its subclasses
	CFMutableDictionaryRef matchingDict = CreateUSBMatchingDictionary(VID, PID);

	// now we have a dictionary, get an iterator over all kernel objects that match the dictionary
	io_iterator_t iter;
	if (IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter) == KERN_SUCCESS) {
		// iterate over all matching kernel objects
		io_service_t usbDevice;
		while ( (usbDevice = IOIteratorNext(iter)) ) {
			if (getPropertyInt(usbDevice, "USB Address") != libusb_addr)
				continue;

#ifdef DEBUG
			// extract path in IOService and IOUSB planes as unique key
			io_string_t pathName;
			IORegistryEntryGetPath(usbDevice, kIOServicePlane, pathName);
			printf("Device's path in IOService plane: %s\n", pathName);
			IORegistryEntryGetPath(usbDevice, kIOUSBPlane, pathName);
			printf("Device's path in IOUSB plane: %s\n", pathName);
#endif // DEBUG

			// get the USB device's name == Product name (= MSP430-USB_Example)
			osxSPInfo->product = getDeviceName(usbDevice);
			// get the Vendor name (= Texas_Instruments)
			osxSPInfo->manufact = getPropertyString(usbDevice, "USB Vendor Name");
			// vid = 0x2047, pid = 0x08f8, rev = ?
			osxSPInfo->vid = getPropertyInt(usbDevice, "idVendor");
			osxSPInfo->pid = getPropertyInt(usbDevice, "idProduct");

			// get the callout device file path (/dev/cu.xxxxx).
			osxSPInfo->name = getStringDataForDeviceKey(usbDevice, CFSTR(kIOCalloutDeviceKey));
			// get the USB serial number
			osxSPInfo->serialNumber = getStringDataForDeviceKey(usbDevice, CFSTR(kUSBSerialNumberString));
			// kIOTTYBaseNameKey
			osxSPInfo->IOTTYBaseName = getStringDataForDeviceKey(usbDevice, CFSTR(kIOTTYBaseNameKey));
			// IOTTYSuffix
			char *IOTTYSuffix = getStringDataForDeviceKey(usbDevice, CFSTR(kIOTTYSuffixKey));
			sscanf(IOTTYSuffix, "%u", &osxSPInfo->IOTTYSuffix);
			free(IOTTYSuffix);

			// free the reference taken before continuing to the next item
			IOObjectRelease(usbDevice);
		}
	}

	// done, release the iterator
	IOObjectRelease(iter);

	return 0;
}
#endif // __APPLE__

#if defined(__APPLE__)
__attribute__((unused))
static int get_system_profiler_info(hw_info_t *osxSPInfo, uint8_t libusb_addr) {
	char cmd[44] = "| system_profiler SPUSBDataType 2>/dev/null";

	str_list_t *sl, *SPInfo;
	if ( (SPInfo = read_file(cmd, 0, 0)) == NULL )
		return -1;

	bool found = false;
	char buf[256];
	for (sl = SPInfo; sl; sl = sl->next) {
		char *product = strstr(sl->str, "MSP430-USB Example:");
		if (product != NULL) {
			found = true;
			product[strlen(product)-1] = '\0';
      osxSPInfo->product = strdup(strtok(product,":"));
			continue;
		}
		if (found) {
			if ( strstr(sl->str, "Product ID:") != 0 ) {
				sscanf(strstr(sl->str, "0x"), "%x", &osxSPInfo->pid);
				if (osxSPInfo->pid != PID) {
					free_hwInfo(osxSPInfo);
					found = false;
				}
				continue;
			}
			if ( strstr(sl->str, "Vendor ID:") != 0 ) {
				sscanf(strstr(sl->str, "0x"), "%x", &osxSPInfo->vid);
				if (osxSPInfo->vid != VID) {
					free_hwInfo(osxSPInfo);
					found = false;
				}
				continue;
			}
			if ( strstr(sl->str, "Version:") != 0 ) {
				char *version = strstr(sl->str, ": ");
				sscanf(&version[2], "%u", &osxSPInfo->rev);
				continue;
			}
			if ( strstr(sl->str, "Serial Number:") != 0 ) {
				char *sn = strstr(sl->str, ": ");
				sn[strlen(sn)-1] = '\0';
				osxSPInfo->serialNumber = strdup(&sn[2]);
				continue;
			}
			if ( strstr(sl->str, "Manufacturer:") != 0 ) {
				char *manufact = strstr(sl->str, ": ");
				manufact[strlen(manufact)-1] = '\0';
				osxSPInfo->manufact = strdup(&manufact[2]);
				continue;
			}
			if ( strstr(sl->str, "Location ID:") != 0 ) {
				char *addr = strstr(sl->str, "/ ");
				if ( (uint8_t)atoi(&addr[2]) == libusb_addr ) {
					osxSPInfo->IOTTYBaseName = strdup("usbmodem");
					char *cu_id = strstr(strtok(sl->str, "/"), "0x");
					cu_id[5] = '\0';
					osxSPInfo->IOTTYSuffix = atoi(&cu_id[2]);
					// IOCalloutDevice
					snprintf(buf, 9+strlen(osxSPInfo->IOTTYBaseName)+5, "/dev/cu.%s%u01",
							osxSPInfo->IOTTYBaseName, osxSPInfo->IOTTYSuffix);
					osxSPInfo->name = strdup(buf);
				} else {
					free_hwInfo(osxSPInfo);
					found = false;
				}
				continue;
			}
			if ( strstr(sl->str, "Current Required (mA):") != 0 ) {
				char *current_required = strstr(sl->str, ": ");
				sscanf(&current_required[2], "%u", &osxSPInfo->current_required);
				found = false; // last entry to process
				continue;
			}
		}
	}

	// free memory
	free_str_list(SPInfo);
	free_str_list(sl);

	return 0;
}
#endif

#if defined(__linux__)
__attribute__((unused))
static int get_udevinfo(serialDevice *dev, char *dev_name, const bool verbose) {
	size_t len = strlen(dev_name);
	char *cmd = calloc(35+len, sizeof(char));
	snprintf(cmd, 35+len, "| udevadm info --name %s 2>/dev/null", dev_name);

	str_list_t *sl, *udevinfo;
	if ( (udevinfo = read_file(cmd, 0, 0)) == NULL ) {
		free(cmd);
		return -1;
	}

#ifndef DEBUG
	if (verbose) {
#endif
		printf("----- udevadm info: %s ------\n", dev_name);
		for (sl = udevinfo; sl; sl = sl->next) {
			printf("  %s", sl->str);
		}
		printf("----- udevadm info end ------\n");
#ifndef DEBUG
	}
#endif

	char buf[256];
	for (sl = udevinfo; sl; sl = sl->next) {
		if (sscanf(sl->str, "E: DEVNAME=%255s", buf) == 1) {
			dev->hwInfo.name = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "E: DEVPATH=%255s", buf) == 1) {
			buf[strlen(buf) - strlen(dev->hwInfo.name)] = 0;
			dev->hwInfo.sysfs = strdup(buf);

			// store sysfs bus
			char *tmp = basename(buf);
			size_t len = strlen(tmp) + 1;
			dev->hwInfo.sysfs_bus = calloc(len, sizeof(char));
			if (dev->hwInfo.sysfs_bus == NULL)
				errno_print("libusb: hwInfo.sysfs_bus calloc error");
			else if (dev->hwInfo.sysfs_bus != NULL)
				strncpy(dev->hwInfo.sysfs_bus, tmp, len);

			continue;
		}
		if (sscanf(sl->str, "E: DEVLINKS=%255[^\n]", buf) == 1) {
			dev->hwInfo.sysfs_links = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "E: ID_MODEL_ID=%x", &dev->hwInfo.pid) == 1) {
			continue;
		}
		if (sscanf(sl->str, "E: ID_MODEL=%255[^\n]", buf) == 1) {
			dev->hwInfo.product = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "E: ID_VENDOR_ID=%x", &dev->hwInfo.vid) == 1) {
			continue;
		}
		if (sscanf(sl->str, "E: ID_VENDOR=%255[^\n]", buf) == 1) {
			dev->hwInfo.manufact = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "E: ID_REVISION=%u", &dev->hwInfo.rev) == 1) {
			continue;
		}
		if (sscanf(sl->str, "E: ID_SERIAL_SHORT=%255[^\n]", buf) == 1) {
			dev->hwInfo.serialNumber = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "E: ID_USB_DRIVER=%255[^\n]", buf) == 1) {
			dev->hwInfo.driver = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "E: MAJOR=%u", &dev->hwInfo.major) == 1) {
			continue;
		}
		if (sscanf(sl->str, "E: MINOR=%u", &dev->hwInfo.major) == 1) {
			continue;
		}
  }

	// free memory
	free_str_list(udevinfo);
	free_str_list(sl);
	free(cmd);

	return 0;
}
#endif // __linux__

#if defined(__linux__)
__attribute__((unused))
static int get_hwinfo(serialDevice *dev, char *dev_name, const bool verbose) {
	size_t len = strlen(dev_name);
	char *cmd = calloc(35+len, sizeof(char));
	snprintf(cmd, 35+len, "| hwinfo --usb --only %s 2>/dev/null", dev_name);

	str_list_t *sl, *hwinfo;
	if ( (hwinfo = read_file(cmd, 0, 0)) == NULL ) {
	 	free(cmd);
		return -1;
	}

#ifndef DEBUG
	if (verbose) {
#endif
		printf("----- hwinfo: %s ------\n", dev_name);
		for (sl = hwinfo; sl; sl = sl->next) {
			printf("  %s", sl->str);
		}
		printf("----- hwinfo end ------\n");
#ifndef DEBUG
	}
#endif

	float speed = 0;
	char buf[256];
	for (sl = hwinfo; sl; sl = sl->next) {
		if (sscanf(sl->str, "  Device File: %255s", buf) == 1) {
			dev->hwInfo.name = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  SysFS ID: %255s", buf) == 1) {
			dev->hwInfo.sysfs = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  SysFS BusID: %255s", buf) == 1) {
			dev->hwInfo.sysfs_bus = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  Device Files: %255[^\n]", buf) == 1) {
			dev->hwInfo.sysfs_links = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  Vendor: usb %x \"%255[^\n\"]\"", &dev->hwInfo.vid, buf) == 2) {
			dev->hwInfo.manufact = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  Device: usb %x \"%255[^\n\"]\"", &dev->hwInfo.pid, buf) == 2) {
			dev->hwInfo.product = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  Revision: \"%u\"", &dev->hwInfo.rev) == 1) {
			continue;
		}
		if (sscanf(sl->str, "  Serial ID: \"%255[^\"]\"", buf) == 1) {
			dev->hwInfo.serialNumber = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  Driver: \"%255[^\"]\"", buf) == 1) {
			dev->hwInfo.driver = strdup(buf);
			continue;
		}
		if (sscanf(sl->str, "  Speed: %f", &speed) == 1) {
			if (speed == 1.5)        // 1.5Mbit/s (USB_SPEED_LOW)
				dev->hwInfo.speed = 1;
			else if (speed == 12.)   // 12Mbit/s (USB_SPEED_FULL)
				dev->hwInfo.speed = 2;
			else if (speed == 400.)  // 480Mbit/s (USB_SPEED_HIGH)
				dev->hwInfo.speed = 3;
			else if (speed == 5000.) // 5000Mbit/s (USB_SPEED_SUPER)
				dev->hwInfo.speed = 4;
			else
				dev->hwInfo.speed = 0; // USB_SPEED_UNKNOWN
			continue;
		}
  }

	// free memory
	free_str_list(hwinfo);
	free_str_list(sl);
	free(cmd);

	return 0;
}
#endif // __linux__

__attribute__((unused))
int getSerialNumber(char * restrict serialNumber, uint8_t desc_iSerialNumber, libusb_device *dev) {
	libusb_device_handle *handle = NULL; // handle for USB device
	int status                           // return codes from libusb functions
		__attribute__((unused));
	int kernelDriverDetached             // set to 1 if kernel driver detached
		__attribute__((unused));
	unsigned char strBuf[50];

	status = LIBUSB_CALL libusb_open(dev, &handle); // open the device
	if (status == LIBUSB_SUCCESS) {
		// As we are dealing with a CDC-ACM device, it's highly probable that Linux already attached
		// the cdc-acm driver to this device. We need to detach the drivers from all the USB interfaces.
		// The CDC-ACM Class defines two interfaces: the Control interface and the Data interface.
		/*
		for (int if_num = 0; if_num < 2; if_num++) {
			kernelDriverDetached = libusb_kernel_driver_active(handle, if_num);
			if (kernelDriverDetached == 1) {
				status = libusb_detach_kernel_driver(handle, if_num);
				if (status != 0)
					libusb_err_print(status, "libusb: libusb_detach_kernel_driver error");
			}
			//status = libusb_claim_interface(handle, if_num);
			//if (status != 0)
			//	libusb_err_print(status, "libusb: libusb_claim_interface error");
		}
		*/

		// get string associated with iSerialNumber index
		if (desc_iSerialNumber) {
			status = LIBUSB_CALL libusb_get_string_descriptor_ascii(handle, desc_iSerialNumber, strBuf, sizeof(strBuf));
			if (status > 0) {
				strncpy(serialNumber, (const char*)strBuf, sizeof(strBuf));
			} else {
				libusb_err_print(status, "libusb: Failed to get device serial number");
			}
		}

		/*
		for (int if_num = 0; if_num < 2; if_num++) {
			//status = libusb_release_interface(handle, if_num);
			//if (status != 0)
			//	libusb_err_print(status, "libusb: libusb_release_interface error");

			kernelDriverDetached = libusb_kernel_driver_active(handle, if_num);
			if (kernelDriverDetached == 0) {
				status = libusb_attach_kernel_driver(handle, if_num);
				if (status != 0)
					libusb_err_print(status, "libusb: libusb_attach_kernel_driver error");
			}
		}
		*/
	}

	if (handle) { // close the device
		LIBUSB_CALL libusb_close(handle);
		handle = NULL;
	}

	return 0;
}

int registerDevice(serialList_t *s, libusb_device *dev, const bool verbose) {
	struct libusb_device_descriptor desc;
	int status = LIBUSB_CALL libusb_get_device_descriptor(dev, &desc);
	if (status != LIBUSB_SUCCESS) {
		errno_print("libusb: Failed to get device descriptor");
		return -1;
	}

	if (desc.idVendor != VID && desc.idProduct != PID) // skip if not FDC2x14EVM
		return -1;

	// get the number of the bus that a device is connected to
	uint8_t bus = LIBUSB_CALL libusb_get_bus_number(dev);
	// get the address of the device on the bus it is connected to
	uint8_t addr = LIBUSB_CALL libusb_get_device_address(dev);

	// get the list of all port numbers from root for the device dev
	char sysPath[PATH_MAX] = "/sys/bus/usb/devices/"; // NOTE: linux specific
	uint8_t path[8];
	status = LIBUSB_CALL libusb_get_port_numbers(dev, path, sizeof(path));
	if (status > 0) {
		snprintf(sysPath + strlen(sysPath), sizeof(sysPath) - strlen(sysPath), "%d-%d", bus, path[0]);
		for (int j = 1; j < status; j++)
			snprintf(sysPath + strlen(sysPath), sizeof(sysPath) - strlen(sysPath), ".%d", path[j]);
	}

	// get tty_name of device
	char tty_name[PATH_MAX];
#if defined(__linux__)
	find_tty_name(tty_name, sysPath);
#elif defined(__APPLE__)
	hw_info_t osxSPInfo;
	// use IOKit to get the hardware info
	get_OSX_info(&osxSPInfo, addr);
	// use system profiler to get the hardware info
	//get_system_profiler_info(&osxSPInfo, addr);
	strcpy(tty_name, osxSPInfo.name);
	osxSPInfo.driver = NULL;
#endif

	/*
	// get serial number
	// PROBLEM: unloading the driver blocks POSIX open/r/w on LINUX. OSX works.
	char serialNumber[50];
	getSerialNumber(serialNumber, desc.iSerialNumber, dev); // PROBLEM: unloading the driver blocks POSIX open/r/w on LINUX
	*/

	printf("==> Found: Bus %03d Device %03d: ID %04x:%04x: Port = %s\n",
			bus, addr, desc.idVendor, desc.idProduct, tty_name);

	if ( isValidSerialAddress(s, tty_name) )
		parseSerialAddress(s, tty_name, verbose); // add device to serialList_t
	else
		return -1;

	serialDevice *sdev = s->tty[s->num_tty-1]->dev;

	// get the hardware info and store it in hw_info structure
#if defined(__linux__)
	/*
	// PROBLEM with hwinfo: it gets only first /dev/ttyACM[i]. use udev instead
	status = get_hwinfo(sdev, tty_name, verbose);
	if (status < 0)
		fprintf(stderr, "libusb: get_hwinfo error for %s (errorcode = %d) at \"%s\":%d\n", \
				tty_name, status,  __FILE__, __LINE__);
	*/
	status = get_udevinfo(sdev, tty_name, verbose);
	if (status < 0)
		fprintf(stderr, "libusb: get_udevinfo error for %s (errorcode = %d) at \"%s\":%d\n", \
				tty_name, status,  __FILE__, __LINE__);
#elif defined(__APPLE__)
	sdev->hwInfo.name = strdup(osxSPInfo.name);
	sdev->hwInfo.IOTTYBaseName = strdup(osxSPInfo.IOTTYBaseName);
	sdev->hwInfo.IOTTYSuffix = osxSPInfo.IOTTYSuffix;
	sdev->hwInfo.current_required = osxSPInfo.current_required;
	sdev->hwInfo.vid = osxSPInfo.vid;
	sdev->hwInfo.pid = osxSPInfo.pid;
	sdev->hwInfo.rev = osxSPInfo.rev;
	sdev->hwInfo.manufact = strdup(osxSPInfo.manufact);
	sdev->hwInfo.product = strdup(osxSPInfo.product);
	sdev->hwInfo.serialNumber = strdup(osxSPInfo.serialNumber);
	if (osxSPInfo.driver != NULL)
		sdev->hwInfo.driver = strdup(osxSPInfo.driver);
	// free memory
	free_hwInfo(&osxSPInfo);
#endif

	// store bus and address
	sdev->hwInfo.bus = (unsigned int)bus;
	sdev->hwInfo.addr = (unsigned int)addr;

	// store the sysPath
	size_t len = strlen(sysPath) + 1;
	sdev->sysPath = calloc(len, sizeof(char));
	if (sdev->sysPath == NULL)
		errno_print("libusb: sysPath calloc error");
	else
		strncpy(sdev->sysPath, sysPath, len);

	// store serialNumber
	len = strlen(sdev->hwInfo.serialNumber) + 1;
	sdev->serialNumber = calloc(len, sizeof(char));
	if (sdev->serialNumber == NULL)
		errno_print("libusb: S/N calloc error");
	else if (sdev->hwInfo.serialNumber != NULL)
		strncpy(sdev->serialNumber, sdev->hwInfo.serialNumber, len);

	// get and store the system time of device attachment
	struct stat st;
	if (stat(tty_name, &st) == -1)
		errno_print("libusb: stat error");
	else
		sdev->ctime = st.st_ctime;   // time of last status change

#ifndef DEBUG
	if (verbose) {
#endif // DEBUG
		printf(" Device path:  %s\n", sdev->name);
		printf(" Attached on %s", ctime(&sdev->ctime));
		printf(" S/N: %s\n", sdev->serialNumber);
#if defined(__linux__)
		printf(" Bus location: %s\n", sdev->sysPath);
#endif // __linux__
#ifndef DEBUG
	}
#endif // DEBUG

	status = LIBUSB_CALL libusb_get_device_speed(dev);
	if ( (status < 0) || (status > 4) )
		status = 0;
	sdev->hwInfo.speed = status;
#ifndef DEBUG
	if (verbose)
#endif
		printf(" Device speed: %s\n", speed_name[status]);

#ifdef DEBUG
	for (uint8_t i = 0; i < desc.bNumConfigurations; i++) {
		struct libusb_config_descriptor *config;
		status  = libusb_get_config_descriptor(dev, i, &config);
		if (status != LIBUSB_SUCCESS) {
			errno_print("libusb: Couldn't retrieve descriptors\n");
			continue;
		}

		print_configuration(config);

		LIBUSB_CALL libusb_free_config_descriptor(config);
	}
#endif

	return 0;
}

int removeDevice(serialList_t *s, libusb_device *dev, const bool verbose) {
	struct libusb_device_descriptor desc;
	int status = LIBUSB_CALL libusb_get_device_descriptor(dev, &desc);
	if (status != LIBUSB_SUCCESS) {
		errno_print("libusb: Failed to get device descriptor");
		return -1;
	}

	if (desc.idVendor != VID && desc.idProduct != PID) // skip if not FDC2x14EVM
		return -1;

	// get the number of the bus that a device is connected to
	uint8_t bus = LIBUSB_CALL libusb_get_bus_number(dev);
	// get the address of the device on the bus it is connected to
	uint8_t addr = LIBUSB_CALL libusb_get_device_address(dev);

	/*
	// open the device
	libusb_device_handle *handle = NULL;
	status = LIBUSB_CALL libusb_open(dev, &handle);
	// close the device
	if (handle) { // close the device
		LIBUSB_CALL libusb_close(handle);
		handle = NULL;
	}
	*/

	for (int id = 0; id < s->num_tty; id++) { // find id by bus/address and remove it from serialList
		if ( (s->tty[id]->dev->hwInfo.bus == (unsigned int)bus) &&
			   (s->tty[id]->dev->hwInfo.addr == (unsigned int)addr) ) {
			status = removeSerialAddress(s, s->tty[id]->dev->name);
			return id;
		}
	}

	return 0;
}

int discoverDevices(serialList_t *s, const bool verbose) {
	if (ctx == NULL)
		libUSB_init(s, verbose);

	libusb_device **list;        // an array of pointers to connected devices
	libusb_device *dev = NULL;   // a pointer to device

	// get a list of connected devices
	ssize_t cnt = LIBUSB_CALL libusb_get_device_list(ctx, &list);
	if (cnt < 0) {
		errno_print("libusb: Unable to discover any USB device");
		LIBUSB_CALL libusb_exit(ctx);
		return (int)cnt;
	} else
		DPRINTF(("libusb: %lu USB devices found\n", cnt));

	int i = 0; // counter
	while ((dev = list[i++]) != NULL) {
		(void)registerDevice(s, dev, verbose);
	}

	LIBUSB_CALL libusb_free_device_list(list, 1); // free the list, unref the devices in it

	printf("\n");
	return 0;
}

// -- LIBUSB INFO PRINTING
static void print_endpoint_comp(const struct libusb_ss_endpoint_companion_descriptor *ep_comp) {
	printf("      USB 3.0 Endpoint Companion:\n");
	printf("        bMaxBurst:        %d\n", ep_comp->bMaxBurst);
	printf("        bmAttributes:     0x%02x\n", ep_comp->bmAttributes);
	printf("        wBytesPerInterval: %d\n", ep_comp->wBytesPerInterval);
}

static void print_endpoint(const struct libusb_endpoint_descriptor *endpoint) {
	printf("      Endpoint:\n");
	printf("        bEndpointAddress: %02xh\n", endpoint->bEndpointAddress);
	printf("        bmAttributes:     %02xh\n", endpoint->bmAttributes);
	printf("        wMaxPacketSize:   %d\n", endpoint->wMaxPacketSize);
	printf("        bInterval:        %d\n", endpoint->bInterval);
	printf("        bRefresh:         %d\n", endpoint->bRefresh);
	printf("        bSynchAddress:    %d\n", endpoint->bSynchAddress);

	for (uint8_t i = 0; i < endpoint->extra_length;) {
		if (LIBUSB_DT_SS_ENDPOINT_COMPANION == endpoint->extra[i + 1]) {
			struct libusb_ss_endpoint_companion_descriptor *ep_comp;

			int status = LIBUSB_CALL libusb_get_ss_endpoint_companion_descriptor(NULL, endpoint, &ep_comp);
			if (status != LIBUSB_SUCCESS)
				continue;

			print_endpoint_comp(ep_comp);

			LIBUSB_CALL libusb_free_ss_endpoint_companion_descriptor(ep_comp);
		}

		i += endpoint->extra[i];
	}
}

static void print_altsetting(const struct libusb_interface_descriptor *alt) {
	printf("    Interface:\n");
	printf("      bInterfaceNumber:   %d\n", alt->bInterfaceNumber);
	printf("      bAlternateSetting:  %d\n", alt->bAlternateSetting);
	printf("      bNumEndpoints:      %d\n", alt->bNumEndpoints);
	printf("      bInterfaceClass:    %d\n", alt->bInterfaceClass);
	printf("      bInterfaceSubClass: %d\n", alt->bInterfaceSubClass);
	printf("      bInterfaceProtocol: %d\n", alt->bInterfaceProtocol);
	printf("      iInterface:         %d\n", alt->iInterface);

	for (uint8_t i = 0; i < alt->bNumEndpoints; i++)
		print_endpoint(&alt->endpoint[i]);
}

static void print_interface(const struct libusb_interface *interface) {
	for (uint8_t i = 0; i < interface->num_altsetting; i++)
		print_altsetting(&interface->altsetting[i]);
}

static void print_configuration(struct libusb_config_descriptor *config) {
	printf("  Configuration:\n");
	printf("    wTotalLength:         %d\n", config->wTotalLength);
	printf("    bNumInterfaces:       %d\n", config->bNumInterfaces);
	printf("    bConfigurationValue:  %d\n", config->bConfigurationValue);
	printf("    iConfiguration:       %d\n", config->iConfiguration);
	printf("    bmAttributes:         %02xh\n", config->bmAttributes);
	printf("    MaxPower:             %d\n", config->MaxPower);

	for (uint8_t i = 0; i < config->bNumInterfaces; i++)
		print_interface(&config->interface[i]);
}
