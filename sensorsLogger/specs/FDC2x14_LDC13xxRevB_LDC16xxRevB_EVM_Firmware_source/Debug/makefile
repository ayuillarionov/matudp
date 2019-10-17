################################################################################
# Automatically-generated file. Do not edit!
################################################################################

SHELL = cmd.exe

CG_TOOL_ROOT := C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3

ORDERED_OBJS += \
"./host_interface.obj" \
"./host_menu.obj" \
"./init.obj" \
"./main.obj" \
"./scheduler.obj" \
"./usbConstructs.obj" \
"./usbEventHandling.obj" \
"./library/LDC13xx16xx_evm.obj" \
"./library/crc8.obj" \
"./library/i2c.obj" \
"./library/pll.obj" \
"./library/spi_1p1.obj" \
"./USB_config/UsbIsr.obj" \
"./USB_config/descriptors.obj" \
"./USB_API/USB_PHDC_API/UsbPHDC.obj" \
"./USB_API/USB_MSC_API/UsbMscReq.obj" \
"./USB_API/USB_MSC_API/UsbMscScsi.obj" \
"./USB_API/USB_MSC_API/UsbMscStateMachine.obj" \
"./USB_API/USB_HID_API/UsbHid.obj" \
"./USB_API/USB_HID_API/UsbHidReq.obj" \
"./USB_API/USB_Common/dma.obj" \
"./USB_API/USB_Common/usb.obj" \
"./USB_API/USB_CDC_API/UsbCdc.obj" \
"./F5xx_F6xx_Core_Lib/HAL_FLASH.obj" \
"./F5xx_F6xx_Core_Lib/HAL_PMAP.obj" \
"./F5xx_F6xx_Core_Lib/HAL_PMM.obj" \
"./F5xx_F6xx_Core_Lib/HAL_TLV.obj" \
"./F5xx_F6xx_Core_Lib/HAL_UCS.obj" \
"../lnk_msp430f5528.cmd" \
"../msp430USB.cmd" \
$(GEN_CMDS__FLAG) \
-l"libc.a" \
-l"C:\ti\ccsv6\ccs_base\msp430\lib\5xx_6xx_FRxx\libmath.a" \
-l"libmath.a" \

-include ../makefile.init

RM := DEL /F
RMDIR := RMDIR /S/Q

# All of the sources participating in the build are defined here
-include sources.mk
-include subdir_vars.mk
-include library/subdir_vars.mk
-include USB_config/subdir_vars.mk
-include USB_API/USB_PHDC_API/subdir_vars.mk
-include USB_API/USB_MSC_API/subdir_vars.mk
-include USB_API/USB_HID_API/subdir_vars.mk
-include USB_API/USB_Common/subdir_vars.mk
-include USB_API/USB_CDC_API/subdir_vars.mk
-include F5xx_F6xx_Core_Lib/subdir_vars.mk
-include subdir_rules.mk
-include library/subdir_rules.mk
-include USB_config/subdir_rules.mk
-include USB_API/USB_PHDC_API/subdir_rules.mk
-include USB_API/USB_MSC_API/subdir_rules.mk
-include USB_API/USB_HID_API/subdir_rules.mk
-include USB_API/USB_Common/subdir_rules.mk
-include USB_API/USB_CDC_API/subdir_rules.mk
-include F5xx_F6xx_Core_Lib/subdir_rules.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(S_DEPS)),)
-include $(S_DEPS)
endif
ifneq ($(strip $(S_UPPER_DEPS)),)
-include $(S_UPPER_DEPS)
endif
ifneq ($(strip $(S62_DEPS)),)
-include $(S62_DEPS)
endif
ifneq ($(strip $(C64_DEPS)),)
-include $(C64_DEPS)
endif
ifneq ($(strip $(ASM_DEPS)),)
-include $(ASM_DEPS)
endif
ifneq ($(strip $(CC_DEPS)),)
-include $(CC_DEPS)
endif
ifneq ($(strip $(S55_DEPS)),)
-include $(S55_DEPS)
endif
ifneq ($(strip $(C67_DEPS)),)
-include $(C67_DEPS)
endif
ifneq ($(strip $(CLA_DEPS)),)
-include $(CLA_DEPS)
endif
ifneq ($(strip $(C??_DEPS)),)
-include $(C??_DEPS)
endif
ifneq ($(strip $(CPP_DEPS)),)
-include $(CPP_DEPS)
endif
ifneq ($(strip $(S??_DEPS)),)
-include $(S??_DEPS)
endif
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
ifneq ($(strip $(C62_DEPS)),)
-include $(C62_DEPS)
endif
ifneq ($(strip $(CXX_DEPS)),)
-include $(CXX_DEPS)
endif
ifneq ($(strip $(C++_DEPS)),)
-include $(C++_DEPS)
endif
ifneq ($(strip $(ASM_UPPER_DEPS)),)
-include $(ASM_UPPER_DEPS)
endif
ifneq ($(strip $(K_DEPS)),)
-include $(K_DEPS)
endif
ifneq ($(strip $(C43_DEPS)),)
-include $(C43_DEPS)
endif
ifneq ($(strip $(INO_DEPS)),)
-include $(INO_DEPS)
endif
ifneq ($(strip $(S67_DEPS)),)
-include $(S67_DEPS)
endif
ifneq ($(strip $(SA_DEPS)),)
-include $(SA_DEPS)
endif
ifneq ($(strip $(S43_DEPS)),)
-include $(S43_DEPS)
endif
ifneq ($(strip $(OPT_DEPS)),)
-include $(OPT_DEPS)
endif
ifneq ($(strip $(PDE_DEPS)),)
-include $(PDE_DEPS)
endif
ifneq ($(strip $(S64_DEPS)),)
-include $(S64_DEPS)
endif
ifneq ($(strip $(C_UPPER_DEPS)),)
-include $(C_UPPER_DEPS)
endif
ifneq ($(strip $(C55_DEPS)),)
-include $(C55_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 
EXE_OUTPUTS += \
Firmware.out \

EXE_OUTPUTS__QUOTED += \
"Firmware.out" \

BIN_OUTPUTS += \
Firmware.txt \

BIN_OUTPUTS__QUOTED += \
"Firmware.txt" \


# All Target
all: Firmware.out secondary-outputs

# Tool invocations
Firmware.out: $(OBJS) $(CMD_SRCS) $(GEN_CMDS)
	@echo 'Building target: $@'
	@echo 'Invoking: MSP430 Linker'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full -z -m"Firmware.map" --heap_size=320 --stack_size=160 --cinit_hold_wdt=on -i"C:/ti/ccsv6/ccs_base/msp430/include" -i"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/lib" -i"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" -i"C:/ti/ccsv6/ccs_base/msp430/lib" -i"C:/ti/ccsv6/ccs_base/msp430/lib/5xx_6xx_FRxx" --reread_libs --warn_sections --xml_link_info="Firmware_linkInfo.xml" --use_hw_mpy=F5 --rom_model -o "Firmware.out" $(ORDERED_OBJS)
	@echo 'Finished building target: $@'
	@echo ' '
	@$(MAKE) --no-print-directory post-build

Firmware.txt: $(EXE_OUTPUTS)
	@echo 'Invoking: MSP430 Hex Utility'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/hex430" --memwidth=8 --romwidth=8 --ti_txt -o "Firmware.txt" $(EXE_OUTPUTS__QUOTED)
	@echo 'Finished building: $@'
	@echo ' '

# Other Targets
clean:
	-$(RM) $(EXE_OUTPUTS__QUOTED)$(BIN_OUTPUTS__QUOTED)
	-$(RM) "host_interface.pp" "host_menu.pp" "init.pp" "main.pp" "scheduler.pp" "usbConstructs.pp" "usbEventHandling.pp" "library\LDC13xx16xx_evm.pp" "library\crc8.pp" "library\i2c.pp" "library\pll.pp" "library\spi_1p1.pp" "USB_config\UsbIsr.pp" "USB_config\descriptors.pp" "USB_API\USB_PHDC_API\UsbPHDC.pp" "USB_API\USB_MSC_API\UsbMscReq.pp" "USB_API\USB_MSC_API\UsbMscScsi.pp" "USB_API\USB_MSC_API\UsbMscStateMachine.pp" "USB_API\USB_HID_API\UsbHid.pp" "USB_API\USB_HID_API\UsbHidReq.pp" "USB_API\USB_Common\dma.pp" "USB_API\USB_Common\usb.pp" "USB_API\USB_CDC_API\UsbCdc.pp" "F5xx_F6xx_Core_Lib\HAL_FLASH.pp" "F5xx_F6xx_Core_Lib\HAL_PMAP.pp" "F5xx_F6xx_Core_Lib\HAL_PMM.pp" "F5xx_F6xx_Core_Lib\HAL_TLV.pp" "F5xx_F6xx_Core_Lib\HAL_UCS.pp" 
	-$(RM) "host_interface.obj" "host_menu.obj" "init.obj" "main.obj" "scheduler.obj" "usbConstructs.obj" "usbEventHandling.obj" "library\LDC13xx16xx_evm.obj" "library\crc8.obj" "library\i2c.obj" "library\pll.obj" "library\spi_1p1.obj" "USB_config\UsbIsr.obj" "USB_config\descriptors.obj" "USB_API\USB_PHDC_API\UsbPHDC.obj" "USB_API\USB_MSC_API\UsbMscReq.obj" "USB_API\USB_MSC_API\UsbMscScsi.obj" "USB_API\USB_MSC_API\UsbMscStateMachine.obj" "USB_API\USB_HID_API\UsbHid.obj" "USB_API\USB_HID_API\UsbHidReq.obj" "USB_API\USB_Common\dma.obj" "USB_API\USB_Common\usb.obj" "USB_API\USB_CDC_API\UsbCdc.obj" "F5xx_F6xx_Core_Lib\HAL_FLASH.obj" "F5xx_F6xx_Core_Lib\HAL_PMAP.obj" "F5xx_F6xx_Core_Lib\HAL_PMM.obj" "F5xx_F6xx_Core_Lib\HAL_TLV.obj" "F5xx_F6xx_Core_Lib\HAL_UCS.obj" 
	-@echo 'Finished clean'
	-@echo ' '

post-build:
	-@echo 'Create flash image: TI-TXT'
	-"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/hex430" --ti_txt "Firmware.out" -o "Firmware.txt" -order MS -romwidth 16
	-@echo ' '

secondary-outputs: $(BIN_OUTPUTS)

.PHONY: all clean dependents
.SECONDARY: post-build

-include ../makefile.targets

