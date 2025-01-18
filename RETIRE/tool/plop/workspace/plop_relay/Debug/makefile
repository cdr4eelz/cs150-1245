################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include src/subdir.mk
-include subdir.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
ifneq ($(strip $(S_UPPER_DEPS)),)
-include $(S_UPPER_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 
ELFSIZE += \
plop_relay.elf.size \

ELFCHECK += \
plop_relay.elf.elfcheck \


# All Target
all: plop_relay.elf secondary-outputs

# Tool invocations
plop_relay.elf: $(OBJS) ../src/lscript.ld $(USER_OBJS)
	@echo 'Building target: $@'
	@echo 'Invoking: MicroBlaze gcc linker'
	mb-gcc -Wl,-T -Wl,../src/lscript.ld -L../../plop505top_bsp/microblaze_0/lib -mxl-barrel-shift -mxl-pattern-compare -mno-xl-soft-div -mcpu=v8.50.b -mno-xl-soft-mul -mhard-float -Wl,--no-relax -Wl,--gc-sections -o "plop_relay.elf" $(OBJS) $(USER_OBJS) $(LIBS)
	@echo 'Finished building target: $@'
	@echo ' '

plop_relay.elf.size: plop_relay.elf
	@echo 'Invoking: MicroBlaze Print Size'
	mb-size plop_relay.elf  |tee "plop_relay.elf.size"
	@echo 'Finished building: $@'
	@echo ' '

plop_relay.elf.elfcheck: plop_relay.elf
	@echo 'Invoking: Xilinx ELF Check'
	elfcheck plop_relay.elf -hw ../../plop505top_hw/system.xml -pe microblaze_0  |tee "plop_relay.elf.elfcheck"
	@echo 'Finished building: $@'
	@echo ' '

# Other Targets
clean:
	-$(RM) $(OBJS)$(C_DEPS)$(EXECUTABLES)$(ELFSIZE)$(ELFCHECK)$(S_UPPER_DEPS) plop_relay.elf
	-@echo ' '

secondary-outputs: $(ELFSIZE) $(ELFCHECK)

.PHONY: all clean dependents
.SECONDARY:

-include ../makefile.targets
