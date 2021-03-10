#!/usr/bin/make

ifeq ($(VERBOSE),true)
  V=
else
  V=@
endif

SERIAL_PORT?=/dev/ttyUSB0

PWD?=$(shell pwd)
BUILDROOT?=$(PWD)

include $(BUILDROOT)/config/default_tools.mk

CFLAGS?= -g -O2 -mlittle-endian -mcpu=cortex-m3 -mthumb -mfloat-abi=soft \
 -DHEAP3 -DSTM32F10X_MD -DUSE_STDPERIPH_DRIVER

LDFLAGS?=-Xlinker --gc-sections --specs=nosys.specs

ARCHIVE_DIR=archives/

FREERTOS_ARCHIVE_URL=https://github.com/FreeRTOS/FreeRTOS/releases/download/202012.00/FreeRTOSv202012.00.zip
FREERTOS_ARCHIVE_PATH=$(ARCHIVE_DIR)FreeRTOSv202012.00.zip
FREERTOS_DIR=freertos/
FREERTOS_BASE_PATH=$(FREERTOS_DIR)FreeRTOSv202012.00/FreeRTOS

FREERTOS_SOURCE_PATHS=\
  $(FREERTOS_BASE_PATH)/Source\
  $(FREERTOS_BASE_PATH)/Source/portable/GCC/ARM_CM3\
  $(FREERTOS_BASE_PATH)/Source/portable/MemMang

FREERTOS_INCLUDE_PATHS=\
  $(FREERTOS_BASE_PATH)/Source/include \
  $(FREERTOS_BASE_PATH)/Source/portable/GCC/ARM_CM3

FREERTOS_SOURCES=\
  port.c \
  tasks.c \
  list.c \
  queue.c \
  timers.c \
  event_groups.c \
  heap_3.c

STM32LIB_ARCHIVE_URL=https://cml.ibisek.com/stm32firmwares/en.stsw-stm32054.zip
STM32LIB_ARCHIVE_PATH=$(ARCHIVE_DIR)en.stsw-stm32054.zip
STM32LIB_DIR=stm32lib/
STM32LIB_BASE_PATH=$(STM32LIB_DIR)STM32F10x_StdPeriph_Lib_V3.5.0

STM32LIB_INCLUDE_PATHS=\
  $(STM32LIB_BASE_PATH)/Libraries/STM32F10x_StdPeriph_Driver/inc \
  $(STM32LIB_BASE_PATH)/Libraries/CMSIS/CM3/DeviceSupport/ST/STM32F10x \
  $(STM32LIB_BASE_PATH)/Libraries/CMSIS/CM3/CoreSupport

STM32LIB_SOURCE_PATHS=\
  $(STM32LIB_BASE_PATH)/Libraries/STM32F10x_StdPeriph_Driver/src \
  $(STM32LIB_BASE_PATH)/Libraries/CMSIS/CM3/DeviceSupport/ST/STM32F10x \
  $(STM32LIB_BASE_PATH)/Libraries/CMSIS/CM3/DeviceSupport/ST/STM32F10x/startup/TrueSTUDIO \
  $(STM32LIB_BASE_PATH)/Libraries/CMSIS/CM3/CoreSupport

STM32LIB_SOURCES=\
  core_cm3.c \
  startup_stm32f10x_md.s \
  system_stm32f10x.c \
  stm32f10x_gpio.c \
  stm32f10x_rcc.c \
  stm32f10x_usart.c \
  misc.c

TURDFILES=.stm32lib_patched .freertos_unzipped

LDSCRIPT=scripts/ldscript.ld

SOURCES =\
  $(FREERTOS_SOURCES) \
  $(STM32LIB_SOURCES) \
  hooks.c \
  stm32f10x_it.c\
  freertos_test.c 

OBJDIR := $(ARCH)/objs
DEPDIR := $(ARCH)/deps
BINDIR := $(ARCH)/bin
LIBDIR := $(ARCH)/lib

C_OBJECTS = $(addprefix $(OBJDIR)/, $(SOURCES:.c=.o))
OBJECTS = $(C_OBJECTS:.s=.o)

DEPS = $(addprefix $(DEPDIR)/, $(SOURCES:.c=.d))

VPATH =\
  $(FREERTOS_SOURCE_PATHS)\
  $(STM32LIB_SOURCE_PATHS)\
  src

INCS = $(addprefix -I,$(FREERTOS_INCLUDE_PATHS))\
       $(addprefix -I,$(STM32LIB_INCLUDE_PATHS))\
       -Iinc

APP=freertos_test

ELF=$(APP).elf
BIN=$(APP).bin

all: $(APP)

$(APP): $(BINDIR)/$(BIN)

clean:
	$(V)echo Cleaning
	$(V)rm -rf $(OBJDIR) $(BINDIR) $(DEPDIR) $(LIBDIR)

clean-clear: clean
	$(V)echo Cleaning Clear
	$(V)rm -rf $(STM32LIB_DIR)
	$(V)rm -rf $(FREERTOS_DIR)
	$(V)rm -rf $(TURDFILES)

distclean: clean-clear
	$(V)echo Dist-cleaning
	$(V)rm -rf $(ARCH)
	$(V)rm -rf $(ARCHIVE_DIR)

flash: $(BINDIR)/$(BIN)
	$(V)echo Flashing $(notdir $<)
	$(V)$(STM32FLASH) $(SERIAL_PORT) -w $(BINDIR)/$(BIN)

$(STM32LIB_ARCHIVE_PATH):
	$(V)echo Downloading $(notdir $@)
	$(V)mkdir -p $(dir $@)
	$(V)curl -fSL -A "Mozilla/4.0" $(STM32LIB_ARCHIVE_URL) -o $@

$(STM32LIB_BASE_PATH): $(STM32LIB_ARCHIVE_PATH)
	$(V)if [ ! -d $(STM32LIB_BASE_PATH) ]; then\
          echo Decompressing $(notdir $@); \
	  mkdir -p $(STM32LIB_DIR);\
	  cd $(STM32LIB_DIR);\
          unzip $(BUILDROOT)/$(STM32LIB_ARCHIVE_PATH); \
        fi

.stm32lib_patched: patches/stm32lib_patch | $(STM32LIB_BASE_PATH)
	$(V)echo Patching stm32lib
	$(V)if [ -f $@ ]; then \
           rm -rf $(STM32LIB_BASE_PATH);\
           mkdir -p $(STM32LIB_DIR);\
           cd $(STM32LIB_DIR); \
           unzip $(BUILDROOT)/$(STM32LIB_ARCHIVE_PATH);\
         fi
	$(V)cd $(STM32LIB_BASE_PATH) ; patch -p1 < $(BUILDROOT)/$<
	$(V)touch $@

$(STM32LIB_SOURCES): | .stm32lib_patched

$(FREERTOS_ARCHIVE_PATH):
	$(V)echo Downloading $(notdir $@)
	$(V)mkdir -p $(dir $@)
	$(V)curl -fSL -A "Mozilla/4.0" $(FREERTOS_ARCHIVE_URL) -o $@

.freertos_unzipped: $(FREERTOS_ARCHIVE_PATH)
	$(V)echo Decompressing $(notdir $@)
	$(V)mkdir -p $(FREERTOS_DIR)
	$(V)cd $(FREERTOS_DIR);\
           unzip $(BUILDROOT)/$(FREERTOS_ARCHIVE_PATH)
	$(V)touch $@

$(FREERTOS_SOURCES): | .freertos_unzipped

$(OBJDIR):
	$(V)mkdir -p $(OBJDIR)

$(BINDIR):
	$(V)mkdir -p $(BINDIR)

$(DEPDIR):
	$(V)mkdir -p $(DEPDIR)

$(LIBDIR):
	$(V)mkdir -p $(LIBDIR)

$(OBJDIR)/%.o: %.c
	@echo Compiling $(notdir $<)
	$(V)if [ ! -f $< ]; then $(MAKE) $@; else \
	$(MAKEDEPEND) ; \
	$(CC) $(CFLAGS) $(INCS) -c $< -o $@ ; fi

$(OBJDIR)/%.o: %.s
	@echo Assembling $(notdir $<)
	$(V)if [ ! -f $< ]; then $(MAKE) $@; else \
	$(CC) $(CFLAGS) $(INCS) -c $< -o $@ ; fi

$(BINDIR)/$(ELF): $(LDSCRIPT) $(BINDIR) $(OBJDIR) $(DEPDIR) $(OBJECTS)
	@echo Linking $(notdir $@)
	$(V)$(CC) $(CFLAGS) $(LDFLAGS) -T$(LDSCRIPT) -o $@ $(OBJECTS)

$(BINDIR)/$(BIN): $(BINDIR)/$(ELF)
	@echo Making binary $(notdir $@)
	$(V)$(OBJCOPY) -O binary $< $@

.PHONY: $(APP)
.PHONY: all clean clean-clear distclean flash

-include $(DEPS)
