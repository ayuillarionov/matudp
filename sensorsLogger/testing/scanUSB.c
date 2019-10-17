/*
 * File Name : scanUSB.c
 * Author    : Alexey Yu. Illarionov, INI UZH Zurich
 *             <ayuillarionov@ini.uzh.ch>
 *
 * Created   : Wed 20 Feb 2019 03:25:54 PM CET
 * Modified  : Wed 20 Feb 2019 05:28:12 PM CET
 * Computer  : ZVPIXX
 * System    : Linux 4.15.0-45-lowlatency x86_64 x86_64
 *
 * Purpose   : scan ports for manufacturer, product and serial number
 * Compile   : gcc scanUSB.c -lusb-1.0
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <libusb-1.0/libusb.h>

int main (int argc, char *argv) {
	libusb_device          **devList = NULL;
	libusb_device          *devPtr = NULL;
	libusb_device_handle   *devHandle = NULL;
	struct libusb_device_descriptor  devDesc;

	unsigned char strDesc[256];
	ssize_t numUSBDevs = 0;      // pre-initialized scalars

	int retVal = libusb_init(NULL);

	// Get the list of USB devices visible to the system.
	numUSBDevs = libusb_get_device_list(NULL, &devList);

	for (ssize_t idx = 0; idx < numUSBDevs; idx++) {
		printf ("\n[%ld]\n", idx+1);

		// Get next device pointer out of the list, use it to open the device.
		devPtr = devList[idx];

		retVal = libusb_open(devPtr, &devHandle);
		if (retVal != LIBUSB_SUCCESS)
			continue;

		// Get the device descriptor for this device.
		retVal = libusb_get_device_descriptor(devPtr, &devDesc);
		if (retVal != LIBUSB_SUCCESS)
			continue;

		// Get the string associated with iManufacturer index.
		printf ("   iManufacturer = %d\n", devDesc.iManufacturer);
		if (devDesc.iManufacturer > 0) {
			retVal = libusb_get_string_descriptor_ascii(devHandle, devDesc.iManufacturer, strDesc, 256);
			if (retVal < 0)
				continue;

			printf ("   string = %s\n",  strDesc);
		}

		// Get string associated with iProduct index.
		printf ("   iProduct = %d\n", devDesc.iProduct);
		if (devDesc.iProduct > 0) {
			retVal = libusb_get_string_descriptor_ascii(devHandle, devDesc.iProduct, strDesc, 256);
			if (retVal < 0)
				continue;

			printf ("   string = %s\n",  strDesc);
		}

		// Get string associated with iSerialNumber index.
		printf ("   iSerialNumber = %d\n", devDesc.iSerialNumber);
		if (devDesc.iSerialNumber > 0) {
			retVal = libusb_get_string_descriptor_ascii(devHandle, devDesc.iSerialNumber, strDesc, 256);
			if (retVal < 0)
				continue;

			printf ("   string = %s\n",  strDesc);
		}

		// Close and try next one.
		libusb_close (devHandle);
		devHandle = NULL;
	}

	if (devHandle != NULL) {
		// Close device if left open due to break out of loop on error.
		libusb_close (devHandle);
	}

	libusb_exit(NULL);
	return 0;
}
