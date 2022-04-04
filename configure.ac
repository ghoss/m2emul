#=====================================================
# Lilith M-Code Emulator
#
# Guido Hoss, 12.03.2022
#
# Published by Guido Hoss under GNU Public License V3.
#=====================================================

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.71])
AC_INIT([mule], [0.1-alpha], [Guido Hoss])
AM_INIT_AUTOMAKE([-Werror foreign subdir-objects])
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_CC

# Checks for libraries.
AC_CHECK_LIB(ncurses, initscr, ,
  [AC_MSG_ERROR([ncurses not found])])

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([
	src/Makefile
	Makefile
])

AC_OUTPUT
