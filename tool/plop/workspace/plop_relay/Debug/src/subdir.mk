################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/testperiph.c \
../src/xintc_tapp_example.c \
../src/xiomodule_intr_example.c \
../src/xiomodule_selftest_example.c \
../src/xuartlite_selftest_example.c 

LD_SRCS += \
../src/lscript.ld 

OBJS += \
./src/testperiph.o \
./src/xintc_tapp_example.o \
./src/xiomodule_intr_example.o \
./src/xiomodule_selftest_example.o \
./src/xuartlite_selftest_example.o 

C_DEPS += \
./src/testperiph.d \
./src/xintc_tapp_example.d \
./src/xiomodule_intr_example.d \
./src/xiomodule_selftest_example.d \
./src/xuartlite_selftest_example.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: MicroBlaze gcc compiler'
	mb-gcc -Wall -O0 -g3 -c -fmessage-length=0 -I../../plop505top_bsp/microblaze_0/include -mxl-barrel-shift -mxl-pattern-compare -mno-xl-soft-div -mcpu=v8.50.b -mno-xl-soft-mul -mhard-float -Wl,--no-relax -ffunction-sections -fdata-sections -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


