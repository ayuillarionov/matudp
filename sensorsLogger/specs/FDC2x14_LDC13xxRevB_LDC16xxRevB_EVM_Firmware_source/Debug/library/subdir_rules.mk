################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Each subdirectory must supply rules for building sources it contributes
library/LDC13xx16xx_evm.obj: ../library/LDC13xx16xx_evm.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="library/LDC13xx16xx_evm.pp" --obj_directory="library" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

library/crc8.obj: ../library/crc8.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="library/crc8.pp" --obj_directory="library" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

library/i2c.obj: ../library/i2c.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="library/i2c.pp" --obj_directory="library" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

library/pll.obj: ../library/pll.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="library/pll.pp" --obj_directory="library" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '

library/spi_1p1.obj: ../library/spi_1p1.c $(GEN_OPTS) $(GEN_HDRS)
	@echo 'Building file: $<'
	@echo 'Invoking: MSP430 Compiler'
	"C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/bin/cl430" -vmspx --abi=eabi -O0 --opt_for_speed=0 --use_hw_mpy=F5 --include_path="C:/ti/ccsv6/ccs_base/msp430/include" --include_path="C:/ti/ccsv6/tools/compiler/ti-cgt-msp430_4.4.3/include" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/F5xx_F6xx_Core_Lib" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/USB_config" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528" --include_path="C:/Users/a0221018/workspace_v6_0/FDC2x14_EVM_MSP430F5528/library" -g --define=__MSP430F5528__ --diag_warning=225 --silicon_errata=CPU21 --silicon_errata=CPU22 --silicon_errata=CPU23 --silicon_errata=CPU40 --printf_support=full --preproc_with_compile --preproc_dependency="library/spi_1p1.pp" --obj_directory="library" $(GEN_OPTS__FLAG) "$<"
	@echo 'Finished building: $<'
	@echo ' '


