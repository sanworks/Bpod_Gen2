/*
 *
 *  Copyright (c) 2015 Warren J. Jasper <wjasper@tx.ncsu.edu>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <ctype.h>
#include <math.h>
#include <unistd.h>

#include "pmd.h"
#include "usb-1608G.h"

#define MAX_COUNT     (0xffff)
#define FALSE 0
#define TRUE 1

struct parsed_options
{
	char *filename;
	double value;
	int subdevice;
	int channel;
	int aref;
	int range;
	int physical;
	int verbose;
	int n_chan;
	int n_scan;
	double freq;
};


/* Test Program */
int toContinue()
{
  int answer;
  answer = 0; //answer = getchar();
  printf("Continue [yY]? ");
  while((answer = getchar()) == '\0' ||
    answer == '\n');
  return ( answer == 'y' || answer == 'Y');
}

int main (int argc, char **argv)
{
  libusb_device_handle *udev = NULL;

  double frequency;
  float table_AIN[NGAINS_1608G][2];
  ScanList list[NCHAN_1608G];  // scan list used to configure the A/D channels.

  int i, j, k, nchan;
  int nScans = 0;
  int ret;

  uint16_t data;
  uint16_t sdataIn[100000]; //holds 16 bit unsigned analog input data

  uint8_t gain, channel;

  struct parsed_options options;
  options.n_chan = atoi(argv[1]);
  options.n_scan = atoi(argv[2]);
  options.range = atoi(argv[3]);
  options.freq = atof(argv[4]);

  udev = NULL;

  ret = libusb_init(NULL);
  if (ret < 0) {
    perror("libusb_init: Failed to initialize libusb");
    exit(1);
  }
  if ((udev = usb_device_find_USB_MCC(USB1608G_PID, NULL))) {} else {
    printf("Failure, did not find a USB 1608G series device!\n");
    return 0;
  }

  // some initialization
  usbInit_1608G(udev);
 
  usbBuildGainTable_USB1608G(udev, table_AIN);

  usbAInScanStop_USB1608G(udev);
  usbAInScanClearFIFO_USB1608G(udev);

  nchan = options.n_chan;
  nScans = options.n_scan;
  frequency = options.freq;

  for (channel = 0; channel < nchan; channel++) {

	switch(options.range) {
	    case '10': gain = BP_10V; break;
	    case '5': gain = BP_5V; break;
	    case '2': gain = BP_2V; break;
	    case '1': gain = BP_1V; break;
	    default:  gain = BP_10V; break;
	}
  }
 
  list[channel].range = gain;  
  list[channel].mode = DIFFERENTIAL;
  list[channel].channel = channel;

  list[nchan-1].mode |= LAST_CHANNEL;
  usbAInConfig_USB1608G(udev, list);

  usbAInScanStart_USB1608G(udev, nScans, 0, frequency, 0x0);

 // printf("hello \n");

  ret = usbAInScanRead_USB1608G(udev, nScans, nchan, sdataIn);

  for (i = 0; i < nScans; i++) {
    for (j = 0; j < nchan; j++) {
      gain = list[j].range;
      k = i*nchan + j;
      data = rint(sdataIn[k]*table_AIN[gain][0] + table_AIN[gain][1]);
      printf("%8.4lf", volts_USB1608G(udev, gain, data));
    }
    printf("\n");
  }
  
  cleanup_USB1608G(udev);
  return 0;
}
