################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Each subdirectory must supply rules for building sources it contributes
host_interface.obj: ../host_interface.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="host_interface.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

host_menu.obj: ../host_menu.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="host_menu.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

init.obj: ../init.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="init.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

main.obj: ../main.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="main.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

scheduler.obj: ../scheduler.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="scheduler.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

usbConstructs.obj: ../usbConstructs.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="usbConstructs.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

usbEventHandling.obj: ../usbEventHandling.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="usbEventHandling.pp" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '


