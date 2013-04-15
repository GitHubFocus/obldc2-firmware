#
# Open-BLDC - Open BrushLess DC Motor Controller
# Copyright (c) 2009-2010 Piotr Esden-Tempski <piotr@esden.net>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

################################################################################
# Please edit the Makefile.targets file when adding targets not this one here
# You will hurt yourself doing that. :)
################################################################################

NAME		?= open-bldc
VERSION          = 0.1-beta
COPYRIGHT        = 'Copyright (C) 2010-2011 Piotr Esden-Tempski <piotr@esden.net>'
LICENSE          = 'License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>'
PREFIX		?= arm-none-eabi
OOCD_INTERFACE	?= flossjtag
OOCD_TARGET	?= open-bldc
OOCD_SERIAL	?=

# Black magic probe specific variables
# Set the BMP_PORT to a serial port and then BMP is used for flashing
BMP_PORT	?=
# Set to 1 to get plain gdb terminal without text user interface.
DEBUG_PLAIN     ?= 0

# Set to 1 to go into verbose mode
VERBOSE		?= 0

# Use 'make VERBOSE=1' for more debug output.
ifneq ($(VERBOSE),1)
Q := @
else
LDFLAGS += -Wl,--print-gc-sections
endif

TOPDIR = $(shell pwd)

CC		= $(PREFIX)-gcc
LD		= $(PREFIX)-gcc
AR		= $(PREFIX)-ar
AS		= $(PREFIX)-as
CP		= $(PREFIX)-objcopy
OD		= $(PREFIX)-objdump
SIZE		= $(PREFIX)-size
GDB		= $(PREFIX)-gdb
OOCD		= openocd
LINT		= $(TOPDIR)/scripts/cpplint.py
OLCONFGEN	= $(shell which olconfgen > /dev/null && echo olconfgen || echo $(TOPDIR)/../var/stage/bin/olconfgen)

COMPILER = $(shell which $(CC))
TOOLCHAIN_DIR = $(shell dirname $(COMPILER))/..
TOOLCHAIN_LIB_DIR = $(TOOLCHAIN_DIR)/$(PREFIX)/lib
TOOLCHAIN_INC_DIR = $(TOOLCHAIN_DIR)/$(PREFIX)/include
GOVERNOR_LIB_DIR = $(TOOLCHAIN_DIR)/lib
GOVERNOR_INC_DIR = $(TOOLCHAIN_DIR)/include
STAGE_LIB_DIR = $(TOPDIR)/../var/stage/arm-none-eabi/lib
STAGE_INC_DIR = $(TOPDIR)/../var/stage/arm-none-eabi/include
ifdef CAN_ADDR
CAN_PARAM = -DCAN_ADDR=$(CAN_ADDR)
else
CAN_PARAM =
endif
VERSION_SUFFIX = `$(TOPDIR)/scripts/setlocalversion`
BUILDDATE = `date +"%Y%m%d"`

BUILDDIR	= build/$(TARGET)
BINDIR		= $(BUILDDIR)/bin
OBJDIR		= $(BUILDDIR)/obj
INCDIR		= $(BUILDDIR)/include
DEPDIR		= build/dep

INCDIRS		= \
	-I. \
	-Isrc \
	-Itest \
	-Iext/libopencm3/include \
	-I$(GOVERNOR_INC_DIR) \
	-I$(INCDIR) \
	-I$(STAGE_INC_DIR)

ARCH_FLAGS      = -mthumb -mcpu=cortex-m3 -msoft-float

CFLAGS          += $(INCDIRS) \
		   $(ARCH_FLAGS) \
		   -Wall -Wextra -ansi -std=c99 -c \
		   -fno-common -Os -g -ffunction-sections \
		   -fdata-sections -DSTM32F1
CFLAGS          += $(CAN_PARAM)
CFLAGS          += -DVERSION=\"$(VERSION)\"
CFLAGS          += -DVERSION_SUFFIX=\"$(VERSION_SUFFIX)\"
CFLAGS          += -DBUILDDATE=\"$(BUILDDATE)\"
CFLAGS          += -DPROJECT_NAME=\"$(NAME)\"
CFLAGS          += -DCOPYRIGHT=\"$(COPYRIGHT)\"
CFLAGS          += -DLICENSE=\"$(LICENSE)\"
LDFLAGS         += -Tsrc/stm32.ld -nostartfiles -L$(TOOLCHAIN_LIB_DIR) -Os \
		                    -L$(GOVERNOR_LIB_DIR) -Wl,--gc-sections \
				    -L$(STAGE_LIB_DIR)
LDFLAGS         += $(ARCH_FLAGS)
LDLIBS          += -lopencm3_stm32f1 -lc -lnosys -lgcc
#LDLIBS          += -lgovernor 
CPFLAGS         += -j .isr_vector -j .text -j .data
ODFLAGS         += -S
SIZEFLAGS       += -A -x

LINTFLAGS	+= 

###############################################################################
# Edit after this point only when you really know what you are doing!!!
###############################################################################

-include Makefile.targets

.SUFFIXES: .elf .bin .hex .srec .lst
.SECONDEXPANSION:
.SECONDARY:

all: $(patsubst %,%.all,$(TARGETS))

lint: $(patsubst %,%.lint,$(TARGETS))

clean:
	@echo "Cleaning up everything"
	$(Q)rm -rf build

flash: $(DEFAULT_TARGET).flash
debug: $(DEFAULT_TARGET).debug

ifdef TARGET
%.all: $$(*).target_exists $(BINDIR)/$$(*).images $(BINDIR)/$$(*).size
	@echo "*** Finished building $* target ***"
else
%.all: $$(*).target_exists
	make TARGET=$(*) check_params
	make TARGET=$(*) CHECKED_PARAMS=true $(*).all
endif

$(BINDIR)/%.images: $(BINDIR)/%.bin $(BINDIR)/%.hex $(BINDIR)/%.srec $(BINDIR)/%.lst
	@echo "*** $* images generated ***"


%.clean: $$(*).target_exists
	@echo "Cleaning target $(*)"
	$(Q)rm -rf build/$(*)


ifdef TARGET
ifeq ($(BMP_PORT),)
ifeq ($(OOCD_SERIAL),)
%.flash: $$(*).target_exists $(BINDIR)/$$(*).hex
	@echo "  OOCD  $(*).hex"
	$(Q)$(OOCD) -f interface/$(OOCD_INTERFACE).cfg \
		    -f board/$(OOCD_TARGET).cfg \
		    -c init \
		    -c "reset init" \
		    -c "stm32x mass_erase 0" \
		    -c "flash write_image $(BINDIR)/$*.hex" \
		    -c reset \
		    -c shutdown
else
%.flash: $$(*).target_exists $(BINDIR)/$$(*).hex
	@echo "  OOCD  $(*).hex"
	$(Q)$(OOCD) -f interface/$(OOCD_INTERFACE).cfg \
		    -f board/$(OOCD_TARGET).cfg \
		    -c "ft2232_serial $(OOCD_SERIAL)" \
		    -c init \
		    -c "reset init" \
		    -c "stm32x mass_erase 0" \
		    -c "flash write_image $(BINDIR)/$*.hex" \
		    -c reset \
		    -c shutdown
endif
else
%.flash: $$(*).target_exists $(BINDIR)/$$(*).elf
	@echo "  GDB   $(*).elf (flash)"
	$(Q)$(GDB) --batch \
		   -ex 'target extended-remote $(BMP_PORT)' \
		   -x scripts/black_magic_probe_flash.scr \
		   $(BINDIR)/$*.elf

endif
else
%.flash: $$(*).target_exists
	make TARGET=$(*) check_params
	make TARGET=$(*) CHECKED_PARAMS=true $(*).flash
endif

ifdef TARGET
ifeq ($(BMP_PORT),)
%.debug: $$(*).target_exists $(BINDIR)/$$(*).elf
	@echo "Debug is only supported when using black magic probe. Pleas set BMP_PORT environment variable."
	@exit 1
else
ifeq ($(DEBUG_PLAIN), 0)
%.debug: $$(*).target_exists $(BINDIR)/$$(*).elf
	@echo "  GDB  $(*).elf"
	$(Q)$(GDB) --tui \
		   -ex 'target extended-remote $(BMP_PORT)' \
		   -x scripts/black_magic_probe_debug.scr \
		   $(BINDIR)/$(*).elf
else
%.debug: $$(*).target_exists $(BINDIR)/$$(*).elf
	@echo "  GDB  $(*).elf"
	$(Q)$(GDB) -ex 'target extended-remote $(BMP_PORT)' \
		   -x scripts/black_magic_probe_debug.scr \
		   $(BINDIR)/$(*).elf
endif
endif
else
%.debug: $$(*).target_exists
	make TARGET=$(*) check_params
	make TARGET=$(*) CHECKED_PARAMS=true $(*).debug
endif

ifdef TARGET
%.lint: $$(*).target_exists $(patsubst %.o,%.c,$(COMMON_OBJECTS)) $(patsubst %.o,%.c,$($(TARGET).OBJECTS))
	@echo " LINT  $(*)"
	$(Q)$(LINT) $(LINTFLAGS) $(patsubst %.o,%.c,$(COMMON_OBJECTS)) $(patsubst %.o,%.c,$($(TARGET).OBJECTS))
else
%.lint: $$(*).target_exists
	make TARGET=$(*) check_params
	make TARGET=$(*) CHECKED_PARAMS=true $(*).lint
endif

halt:
	@echo " OOCD halt"
	$(Q)$(OOCD) -f interface/$(OOCD_INTERFACE).cfg \
		    -f board/$(OOCD_TARGET).cfg \
		    -c init \
		    -c "reset halt" \
		    -c shutdown

.PHONY: doc
doc:
	@mkdir -p doc
	@doxygen doxygen.conf > /dev/null
	@cp ../../art/open-bldc-logo.png doc/doxy/html/

%.size: %.elf
	@echo
	$(Q)$(SIZE) $(SIZEFLAGS) $<

%.elf: $(patsubst %.o,$(OBJDIR)/%.o,$(COMMON_OBJECTS)) $(patsubst %.o,$(OBJDIR)/%.o,$($(TARGET).OBJECTS)) $(INCDIR)/params.h
	@echo "  LD    $@"
	$(Q)mkdir -p $(@D)
	$(Q)$(LD) $(LDFLAGS) -o $@ $(patsubst %.o,$(OBJDIR)/%.o, $(COMMON_OBJECTS)) $(patsubst %.o,$(OBJDIR)/%.o,$($(TARGET).OBJECTS)) $(LDLIBS)


%.target_exists:
	@if [ "_$($(*).OBJECTS)" == "_" ] ; then \
		echo "*** Target $* does not exist ***"; \
		exit 1; \
	fi


check_params: check_params_exist $(patsubst %,%.check_param, $($(TARGET).PARAMS))

#$(INCDIR)/config.h

check_params_exist:
	@echo "checking if $(INCDIR)/params.h exists... \c"
	@mkdir -p $(INCDIR)
	@\
	if [ ! -f $(INCDIR)/params.h ] ; then \
		echo "no, I create it for you."; \
		touch $(INCDIR)/params.h; \
	else \
		echo "yes."; \
	fi; \

%.check_param:
	@echo "checking param \"$(*)\" for target \"$(TARGET)\"... \c"
	@\
	if ! grep "^#define $(*) PARAM_$($(*))$$" $(INCDIR)/params.h > /dev/null ; then \
		echo "changed/missing, updating/adding it for you."; \
		mv $(INCDIR)/params.h $(INCDIR)/params.h.tmp; \
		grep -v "^#define $(*) " $(INCDIR)/params.h.tmp > $(INCDIR)/params.h; \
		echo "#define $(*) PARAM_$($(*))" >> $(INCDIR)/params.h; \
		rm $(INCDIR)/params.h.tmp; \
	else \
		echo "exists and not missing."; \
	fi

$(INCDIR)/config.h: $(TOPDIR)/../conf/$(TARGET)-config.yaml
	@echo "  OC    $@"
	$(Q)$(OLCONFGEN) $< > $@

# Suffix rules

%.bin: %.elf
	@echo "  CP    $@"
	$(Q)$(CP) $(CPFLAGS) -Obinary $< $@

%.hex: %.elf
	@echo "  CP    $@"
	$(Q)$(CP) $(CPFLAGS) -Oihex $< $@

%.srec: %.elf
	@echo "  CP    $@"
	$(Q)$(CP) $(CPFLAGS) -Osrec $< $@

%.lst: %.elf
	@echo "  OD    $@"
	$(Q)$(OD) $(ODFLAGS) $< > $@

$(OBJDIR)/%.o: %.c
	@echo "  CC    $@"
	$(Q)mkdir -p $(@D)
	$(Q)$(CC) $(CFLAGS) -DTARGET=\"$(TARGET)\" -c $*.c -o $@

$(DEPDIR)/%.d: %.c
	@echo "  DEP   $@"
	$(Q)mkdir -p $(@D)
	$(Q)$(CC) -MM $(CFLAGS) $< -MF $@
	$(Q)cp -f $@ $@.tmp
	$(Q)sed -e 's|.*:|build/$$(TARGET)/obj/$*.o:|' < $@.tmp > $@
	$(Q)sed -e 's/.*://' -e 's/\\$$//' < $@.tmp | fmt -1 | \
	 sed -e 's/^ *//' -e 's/$$/:/' >> $@
	$(Q)rm -f $@.tmp

# include header dependency information
ifdef CHECKED_PARAMS
-include $(patsubst %.o,$(DEPDIR)/%.d,$(OBJECTS))
endif
