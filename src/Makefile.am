#=====================================================
# Lilith M-Code Emulator
#
# Guido Hoss, 12.03.2022
#
# Published by Guido Hoss under GNU Public License V3.
#=====================================================

AM_CFLAGS = -Wall -DVERSION_BUILD_DATE=\""$(shell date +'%F')"\"

bin_PROGRAMS = mule

mule_SOURCES = \
	le_main.c \
	le_mcode.c le_mcode.h \
	le_stack.c le_stack.h \
	le_io.c le_io.h \
	le_usage.c le_usage.h \
	le_loader.c le_loader.h \
	le_syscall.c le_syscall.h \
	le_trace.c le_trace.h \
	le_heap.c le_heap.h \
	le_mach.c le_mach.h