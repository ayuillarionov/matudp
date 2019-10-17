/* Copyright (C) 2015 Texas Instruments Incorporated - http://www.ti.com/  ALL RIGHTS RESERVED  */

#include <msp430.h>

int _system_pre_init(void)
{
  // stop WDT
  WDTCTL = WDTPW + WDTHOLD;

  // Perform C/C++ global data initialization
  return 1;
}
