/* Copyright (C) 2015 Texas Instruments Incorporated - http://www.ti.com/  ALL RIGHTS RESERVED  */

#include <intrinsics.h>
#include <string.h>

#include <stdint.h>
#include <cstring>
#include <stdio.h>

#include "LDC13xx16xx_cmd.h"
#include "LDC13xx16xx_evm.h"

#include "scheduler.h"
#include "host_interface.h"
#include "host_packet.h"

#include "USB_API/USB_Common/device.h"
#include "USB_API/USB_Common/types.h"               //Basic Type declarations
#include "USB_API/USB_Common/usb.h"                 //USB-specific functions

#include "F5xx_F6xx_Core_Lib/HAL_UCS.h"
#include "F5xx_F6xx_Core_Lib/HAL_PMM.h"

#include "USB_API/USB_CDC_API/UsbCdc.h"
#include "usbConstructs.h"
#include "USB_config/descriptors.h"

// prototypes
void InitMCU(void);
void Init_Clock(void);
void USBCommunicationTask(void);

void LDC16_13_Evm_Test_Routine();
uint16_t L_Noise(uint16_t * t_buf, uint8_t ch_num);
uint8_t L_Sample(uint16_t * t_buf, uint8_t ch_num);

volatile uint8_t bCDCDataReceived_event = FALSE;   //Indicates data has been received without an open rcv operation

volatile uint16_t usbEvents = (kUSB_VbusOnEvent + kUSB_VbusOffEvent + kUSB_receiveCompletedEvent
        + kUSB_dataReceivedEvent + kUSB_UsbSuspendEvent + kUSB_UsbResumeEvent +
        kUSB_UsbResetEvent);

// used as an edge-trigger for USB connect/disconnect
uint8_t usb_led_flag;

void main(void)
{
  WDTCTL = WDTPW + WDTHOLD;                                                  //Stop watchdog timer
  
  // hardware bootloader entry
  EVM_SHUTDOWN_SEL &= ~EVM_SHUTDOWN_BIT; // gpio
  EVM_SHUTDOWN_DIR &= ~EVM_SHUTDOWN_BIT; // input
  EVM_SHUTDOWN_REN |= EVM_SHUTDOWN_BIT; // enable pull-down
  EVM_SHUTDOWN_OUT &= ~EVM_SHUTDOWN_BIT; // pull low
  __delay_cycles(36000);
  if (EVM_SHUTDOWN_IN & EVM_SHUTDOWN_BIT) {
	  _disable_interrupts();
	  ((void (*)())0x1000)();
  }
  EVM_SHUTDOWN_REN &= ~EVM_SHUTDOWN_BIT; // disable pull-down



 // InitMCU(); //included in evm init
  evm_init();
  LDC16_13_Evm_Test_Routine();
  _enable_interrupts();
  initHostInterface();

  usb_led_flag = 0;
  
  while (1)
  {
    // USB Comms
    USBCommunicationTask();
  }
}

/** Initialze MCU
Initializes the MSP430 peripherals and modules.
*/
void InitMCU(void)
{
    __disable_interrupt();      // Disable global interrupts
    SetVCore(3);
    Init_Clock();               //Init clocks
    USB_init();                 //Init USB

    USB_setEnabledEvents((WORD)usbEvents);

    //Check if we're already physically attached to USB, and if so, connect to it
    //This is the same function that gets called automatically when VBUS gets attached.
    if (USB_connectionInfo() & kUSB_vbusPresent){
        USB_handleVbusOnEvent();
    }
  __enable_interrupt();                                                        // enable global interrupts

}

/** USB Communication
Handles USB Comms
*/
void USBCommunicationTask(void)
{
  uint16_t bytesSent, bytesReceived;
  uint8_t error=0, status;
  
        switch (USB_connectionState())
        {
            case ST_ENUM_ACTIVE:
            	if (!usb_led_flag) {
//            		evm_LED_Set(GREEN); // green on only
            		usb_led_flag = 1;
            	}
            	status = USBCDC_intfStatus(CDC0_INTFNUM,&bytesSent, &bytesReceived);
                if (status & kUSBCDC_waitingForSend) {
                	error = 1;
                }
                if(bCDCDataReceived_event || (status & kUSBCDC_dataWaiting))
                {
                    bCDCDataReceived_event = FALSE;
                    processCmdPacket ();
                }
                else {
                	evm_processDRDY(); // process DRDY added here for speed (not scheduler-assigned)
                	executeTasks();
                }
                break;

            case ST_USB_DISCONNECTED: case ST_USB_CONNECTED_NO_ENUM:
            case ST_ENUM_IN_PROGRESS: case ST_NOENUM_SUSPENDED: case ST_ERROR:
            	if (usb_led_flag) {
//            		evm_LED_Set(RED); // red on only
            		usb_led_flag = 0;
            	}
            	removeAllTasks();
            	break;
            default:;
        }                                                                            //end of switch-case sentence
        if(error)
        { 
        	error = 0;
        	_nop();
            //TO DO: User can place code here to handle error
        }        
}

/** Initialize Clock
Initializes all clocks: ACLK, MCLK, SMCLK.
*/
void Init_Clock(void)
{
    //Initialization of clock module
    if (USB_PLL_XT == 2){
		#if defined (__MSP430F552x) || defined (__MSP430F550x)
			P5SEL |= 0x0C;                                      //enable XT2 pins for F5529
		#elif defined (__MSP430F563x_F663x)
			P7SEL |= 0x0C;
		#endif

#if 0                        
        //use REFO for FLL and ACLK
        UCSCTL3 = (UCSCTL3 & ~(SELREF_7)) | (SELREF__REFOCLK);
        UCSCTL4 = (UCSCTL4 & ~(SELA_7)) | (SELA__REFOCLK);

        //MCLK will be driven by the FLL (not by XT2), referenced to the REFO
        Init_FLL_Settle(USB_MCLK_FREQ / 1000, USB_MCLK_FREQ / 32768);   //Start the FLL, at the freq indicated by the config
                                                                        //constant USB_MCLK_FREQ
        XT2_Start(XT2DRIVE_0);                                          //Start the "USB crystal"
#endif        
        // for USB2ANY which has XT2 crytstal = 24MHz
        UCSCTL4  = SELA_5 + SELS_5 + SELM_5;      // ACLK=XT2  SMCLK=XT2   MCLK=XT2  
        XT2_Start(XT2DRIVE_3);        
    }
	else {
		#if defined (__MSP430F552x) || defined (__MSP430F550x)
			P5SEL |= 0x10;                                      //enable XT1 pins
		#endif
        //Use the REFO oscillator to source the FLL and ACLK
        UCSCTL3 = SELREF__REFOCLK;
        UCSCTL4 = (UCSCTL4 & ~(SELA_7)) | (SELA__REFOCLK);

        //MCLK will be driven by the FLL (not by XT2), referenced to the REFO
        Init_FLL_Settle(USB_MCLK_FREQ / 1000, USB_MCLK_FREQ / 32768);   //set FLL (DCOCLK)

        XT1_Start(XT1DRIVE_0);                                          //Start the "USB crystal"
    }
}


// L noise measurement
// take 16 sampling averages of size 1024
// returns noise measurement
uint16_t L_Noise(uint16_t * t_buf, uint8_t ch_num) {
	uint8_t i;
	uint32_t j,sample,min,max;
	uint16_t avg = 0;
	// if L noise is out of range after tuning return FALSE
	for (i = 0; i < 4; i++) {
//		evm_LED_Set(ALLTOGGLE);
		min = 0xFFFFFFFF; //min
		max = 0; //max
		// measure L noise

		for (j = 0; j < 1024; j++) {

			if(evm_device_series == 16){
				smbus_readWord(0x2A, ch_num, &t_buf[0]);
				smbus_readWord(0x2A, ch_num+1, &t_buf[1]);
				sample = ((uint32_t) t_buf[1]) | (((uint32_t) t_buf[0]) << 16);
			}
			else if(evm_device_series == 13){
				smbus_readWord(0x2A, ch_num, &t_buf[0]);
				sample = ((uint32_t) t_buf[0]);
			}

			if (sample < min)
				min = sample;
			if (sample > max)
				max = sample;
		}
		if (max > min) {
			avg += (max - min);
		}
		else if (min > max) {
			return 0xFFFF;
		}
	}
	avg /= 4; // should compile to right shift by 4
	return avg;
}

// L sample range measurement
// take 64 sampling windows of size 16
// FALSE if no errors, TRUE otherwise
uint8_t L_Sample(uint16_t * t_buf, uint8_t ch_num) {
	uint8_t i,j;
	uint32_t avg;

	uint32_t min = EVM_SENSOR_FREE_AIR_MSB_REVA_MIN;
	uint32_t max = EVM_SENSOR_FREE_AIR_MSB_REVA_MAX;

	if(evm_rev == EVM_REV_B){
		min = EVM_SENSOR_FREE_AIR_MSB_REVB_MIN;
		max = EVM_SENSOR_FREE_AIR_MSB_REVB_MAX;
	}
	else if(evm_rev == EVM_FDC21xx22){
		min = EVM_SENSOR_FREE_AIR_MSB_FDC21xx22_MIN;
		max = EVM_SENSOR_FREE_AIR_MSB_FDC21xx22_MAX;
	}

	for (i = 0; i < 16; i++) {
		avg = 0;
		for (j = 0; j < 16; j++) {
			smbus_readWord(0x2A,ch_num, &t_buf[0]);
			avg += t_buf[0];
		}
		avg = avg / 16;

		if((avg < min)||(avg > max)){
			return TRUE;
		}
	}

	return FALSE;
}

//LDC1000 Test Routine

void LDC16_13_Evm_Test_Routine() {

	uint16_t t_buf[2] = { 0x00, 0x00 };
	uint16_t i;

	for (i = 0; i < 10; i++) {
		__delay_cycles(65000);
	}

	if (L_Sample(&t_buf[0], LDC13xx16xx_CMD_DATA_MSB_CH0)) {
		evm_LED_Set(RED);
	}
	else if (L_Sample(&t_buf[0], LDC13xx16xx_CMD_DATA_MSB_CH1)) {
		evm_LED_Set(RED);
	}
	else {
		evm_LED_Set(GREEN);
	}
}




/** Oscillator
Disables USB if there is a problem with the oscillator
*/
#pragma vector = UNMI_VECTOR
__interrupt VOID UNMI_ISR (VOID)
{
    switch (__even_in_range(SYSUNIV, SYSUNIV_BUSIFG ))
    {
        case SYSUNIV_NONE:
            __no_operation();
            break;
        case SYSUNIV_NMIIFG:
            __no_operation();
            break;
        case SYSUNIV_OFIFG:
            UCSCTL7 &= ~(DCOFFG + XT1LFOFFG + XT2OFFG); //Clear OSC flaut Flags fault flags
            SFRIFG1 &= ~OFIFG;                          //Clear OFIFG fault flag
            break;
        case SYSUNIV_ACCVIFG:
            __no_operation();
            break;
        case SYSUNIV_BUSIFG:
            SYSBERRIV = 0;                                      //clear bus error flag
            USB_disable();                                      //Disable
    }
}
