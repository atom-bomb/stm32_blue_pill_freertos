TOOLCHAIN_PATH=/usr/local/gcc-arm-none-eabi-10-2020-q4-major/bin/
CROSS=arm-none-eabi-
ARCH=arm
CC=$(TOOLCHAIN_PATH)$(CROSS)gcc
AR=$(TOOLCHAIN_PATH)$(CROSS)ar
OBJCOPY=$(TOOLCHAIN_PATH)$(CROSS)objcopy

MAKEDEPEND?=$(CC) -M -MT$(OBJDIR)/$*.o $(CFLAGS) $(INCS) -o $(DEPDIR)/$*.d $<

STM32FLASH=stm32flash


