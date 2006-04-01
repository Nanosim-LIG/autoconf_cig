# -*- Autoconf -*-


## -------------------------- ##
## Autoconf macros for PETSc. ##
## -------------------------- ##


# CIT_PATH_PETSC([VERSION], [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND])
# -----------------------------------------------------------------------
# Check for the PETSc package.  Requires Python.
AC_DEFUN([CIT_PATH_PETSC], [
# $Id$
AC_REQUIRE([AM_PATH_PYTHON])
AC_ARG_VAR(PETSC_DIR, [location of PETSc installation])
AC_ARG_VAR(PETSC_ARCH, [PETSc configuration])
AC_MSG_CHECKING([for PETSc dir])
if test -z "$PETSC_DIR"; then
    AC_MSG_RESULT(no)
    m4_default([$3], [AC_MSG_ERROR([PETSc not found; set PETSC_DIR])])
elif test ! -d "$PETSC_DIR"; then
    AC_MSG_RESULT(no)
    m4_default([$3], [AC_MSG_ERROR([PETSc not found; PETSC_DIR=$PETSC_DIR is invalid])])
elif test ! -d "$PETSC_DIR/include"; then
    m4_default([$3], [AC_MSG_ERROR([PETSc include dir $PETSC_DIR/include not found; check PETSC_DIR])])
elif test ! -f "$PETSC_DIR/include/petscversion.h"; then
    m4_default([$3], [AC_MSG_ERROR([PETSc header file $PETSC_DIR/include/petscversion.h not found; check PETSC_DIR])])
elif test -z "$PETSC_ARCH" && test ! -f "$PETSC_DIR/bmake/petscconf"; then
    m4_default([$3], [AC_MSG_ERROR([PETSc file $PETSC_DIR/bmake/petscconf not found; check PETSC_DIR])])
else
    AC_MSG_RESULT([$PETSC_DIR])
    AC_MSG_CHECKING([for PETSc arch])
    if test -z "$PETSC_ARCH"; then
        cat >petsc.py <<END_OF_PYTHON
[from distutils.sysconfig import parse_makefile

vars = parse_makefile('$PETSC_DIR/bmake/petscconf')
print 'PETSC_ARCH="%s"' % vars['PETSC_ARCH']

]
END_OF_PYTHON
        eval `$PYTHON petsc.py 2>/dev/null`
        rm -f petsc.py
    fi
    AC_MSG_RESULT([$PETSC_ARCH])
    if test ! -d "$PETSC_DIR/bmake/$PETSC_ARCH"; then
        m4_default([$3], [AC_MSG_ERROR([PETSc config dir $PETSC_DIR/bmake/$PETSC_ARCH not found; check PETSC_ARCH])])
    elif test ! -f "$PETSC_DIR/bmake/$PETSC_ARCH/petscconf"; then
        m4_default([$3], [AC_MSG_ERROR([PETSc config file $PETSC_DIR/bmake/$PETSC_ARCH/petscconf not found; check PETSC_ARCH])])
    else
        AC_MSG_CHECKING([for PETSc version == $1])
        echo "PETSC_DIR = $PETSC_DIR" > petscconf
        echo "PETSC_ARCH = $PETSC_ARCH" >> petscconf
        cat $PETSC_DIR/bmake/$PETSC_ARCH/petscconf $PETSC_DIR/bmake/common/variables >> petscconf
        cat >petsc.py <<END_OF_PYTHON
[from distutils.sysconfig import parse_config_h, parse_makefile, expand_makefile_vars

f = open('$PETSC_DIR/include/petscversion.h')
vars = parse_config_h(f)
f.close()

parse_makefile('petscconf', vars)

keys = (
    'PETSC_VERSION_MAJOR',
    'PETSC_VERSION_MINOR',
    'PETSC_VERSION_SUBMINOR',

    'PETSC_INCLUDE',
    'PETSC_LIB',
    'PETSC_FORTRAN_LIB',

    'CC',
    'FC',
)

for key in keys:
    if key[:6] == 'PETSC_':
        print '%s="%s"' % (key, expand_makefile_vars(str(vars[key]), vars))
    else:
        print 'PETSC_%s="%s"' % (key, expand_makefile_vars(str(vars[key]), vars))

]
END_OF_PYTHON
        AS_IF([AC_TRY_COMMAND([$PYTHON petsc.py >conftest.sh 2>&AS_MESSAGE_LOG_FD])],
              [],
              [AC_MSG_FAILURE([cannot parse PETSc configuration])])
        eval `cat conftest.sh`
        rm -f conftest.sh petsc.py petscconf

        [eval `echo $1 | sed 's/\([^.]*\)[.]\([^.]*\).*/petsc_1_major=\1; petsc_1_minor=\2;/'`]
        if test -z "$PETSC_VERSION_MAJOR" -o -z "$PETSC_VERSION_MINOR"; then
            AC_MSG_RESULT(no)
            m4_default([$3], [AC_MSG_ERROR([no suitable PETSc package found])])
        elif test "$PETSC_VERSION_MAJOR" -eq "$petsc_1_major" -a \
                  "$PETSC_VERSION_MINOR" -eq "$petsc_1_minor" ; then
            AC_MSG_RESULT([yes ($PETSC_VERSION_MAJOR.$PETSC_VERSION_MINOR.$PETSC_VERSION_SUBMINOR)])
            $2
        else
            AC_MSG_RESULT([no ($PETSC_VERSION_MAJOR.$PETSC_VERSION_MINOR.$PETSC_VERSION_SUBMINOR)])
            m4_default([$3], [AC_MSG_ERROR([no suitable PETSc package found])])
        fi
    fi
fi
AC_SUBST([PETSC_VERSION_MAJOR])
AC_SUBST([PETSC_VERSION_MINOR])
AC_SUBST([PETSC_VERSION_SUBMINOR])
AC_SUBST([PETSC_INCLUDE])
AC_SUBST([PETSC_LIB])
AC_SUBST([PETSC_FORTRAN_LIB])
AC_SUBST([PETSC_CC])
AC_SUBST([PETSC_FC])
])dnl CIT_PATH_PETSC


# CIT_CHECK_LIB_PETSC
# -------------------
# Try to link against the PETSc libraries.  If the current language is
# C++, determine the value of PETSC_CXX_LIB, which names the extra
# libraries needed when using a C++ compiler.  (As of PETSc v2.3,
# PETSC_CXX_LIB will always be empty; see comment below.)
AC_DEFUN([CIT_CHECK_LIB_PETSC], [
# $Id$
AC_REQUIRE([CIT_PATH_PETSC])dnl
AC_SUBST(PETSC_CXX_LIB)
PETSC_CXX_LIB=
cit_petsc_save_CC=$CC
cit_petsc_save_LIBS=$LIBS
CC=$PETSC_CC
LIBS="$PETSC_LIB $LIBS"
AC_CHECK_FUNC(PetscInitialize, [], [
    AC_LANG_CASE(
        [C++], [],
        _CIT_CHECK_LIB_PETSC_FAILED
    )
    #
    # Try to guess the correct value for PETSC_CXX_LIB, assuming PETSC_CC
    # is an MPI wrapper.
    #
    # In theory, when PETSC_CC is 'mpicc', *both* the MPI libraries and
    # includes are effectively hidden, and must be extracted in order to
    # use a C++ compiler (the PETSc configuration does not specify a C++
    # compiler command).
    #
    # But this path was only added for symmetry with CIT_HEADER_PETSC.
    # Because, in practice, there is an asymmetry between includes and
    # libs.  When PETSC_CC is 'mpicc', the MPI includes are indeed hidden:
    # PETSC_INCLUDE omits MPI includes.  But PETSC_LIB always explicitly
    # specifies the MPI library, even (redundantly) when PETSC_CC is
    # 'mpicc'.  So, as of PETSc v2.3 at least, this path is never taken.
    CIT_MPI_LIBS(cit_libs, $PETSC_CC, [
	LIBS="$PETSC_LIB $cit_libs $cit_petsc_save_LIBS"
	unset ac_cv_func_PetscInitialize
	AC_CHECK_FUNC(PetscInitialize, [
	    PETSC_CXX_LIB=$cit_libs
	], [
	    _CIT_CHECK_LIB_PETSC_FAILED
	])
    ], [
	_CIT_CHECK_LIB_PETSC_FAILED
    ])
])
LIBS=$cit_petsc_save_LIBS
CC=$cit_petsc_save_CC
])dnl CIT_CHECK_LIB_PETSC


# _CIT_CHECK_LIB_PETSC_FAILED
# ---------------------------
AC_DEFUN([_CIT_CHECK_LIB_PETSC_FAILED], [
AC_MSG_ERROR([cannot link against PETSc libraries])
])dnl _CIT_CHECK_LIB_PETSC_FAILED


# CIT_HEADER_PETSC
# ----------------
# Try to use PETSc headers.  If the current language is C++, determine
# the value of PETSC_CXX_INCLUDE, which names the extra include paths
# needed when using a C++ compiler... i.e., the MPI includes.  When
# PETSC_CC is set to an MPI wrapper such as 'mpicc', the required MPI
# includes are effectively hidden, and must be extracted in order to
# use a C++ compiler (the PETSc configuration does not specify a C++
# compiler command).
AC_DEFUN([CIT_HEADER_PETSC], [
# $Id$
AC_REQUIRE([CIT_PATH_PETSC])dnl
AC_REQUIRE([CIT_CHECK_LIB_PETSC])dnl
AC_SUBST(PETSC_CXX_INCLUDE)
PETSC_CXX_INCLUDE=
cit_petsc_save_CC=$CC
cit_petsc_save_CPPFLAGS=$CPPFLAGS
cit_petsc_save_LIBS=$LIBS
CC=$PETSC_CC
CPPFLAGS="$PETSC_INCLUDE $CPPFLAGS"
AC_MSG_CHECKING([for petsc.h])
dnl Use AC_TRY_COMPILE instead of AC_CHECK_HEADER because the
dnl latter also preprocesses using $CXXCPP.
AC_TRY_COMPILE([
#include <petsc.h>
], [], [
    AC_MSG_RESULT(yes)
], [
    AC_MSG_RESULT(no)
    AC_LANG_CASE(
        [C++], [],
        _CIT_HEADER_PETSC_FAILED
    )
    # Try to guess the correct value for PETSC_CXX_INCLUDE, assuming
    # PETSC_CC is an MPI wrapper.
    CIT_MPI_INCLUDES(cit_includes, $PETSC_CC, [
	AC_MSG_CHECKING([for petsc.h])
	CPPFLAGS="$PETSC_INCLUDE $cit_includes $cit_petsc_save_CPPFLAGS"
	AC_TRY_COMPILE([
#include <petsc.h>
	], [], [
	    AC_MSG_RESULT(yes)
	    PETSC_CXX_INCLUDE=$cit_includes
	], [
	    AC_MSG_RESULT(no)
	    _CIT_HEADER_PETSC_FAILED
	])
    ], [
	_CIT_HEADER_PETSC_FAILED
    ])
])
AC_LANG_CASE([C++], [
    LIBS="$PETSC_LIB $PETSC_CXX_LIB $LIBS"
    CIT_MPI_CHECK_CXX_LINK(PETSC_CXX_INCLUDE, [$PETSC_LIB],
                           _CIT_TRIVIAL_PETSC_PROGRAM,
                           [whether we can link a trivial C++ PETSc program],
                           [],
			   AC_MSG_FAILURE([cannot link a trivial C++ PETSc program using $CXX]))
])
LIBS=$cit_petsc_save_LIBS
CPPFLAGS=$cit_petsc_save_CPPFLAGS
CC=$cit_petsc_save_CC
])dnl CIT_HEADER_PETSC


# _CIT_HEADER_PETSC_FAILED
# ------------------------
AC_DEFUN([_CIT_HEADER_PETSC_FAILED], [
AC_MSG_ERROR([header "petsc.h" not found])
])dnl _CIT_HEADER_PETSC_FAILED


# _CIT_TRIVIAL_PETSC_PROGRAM
# --------------------------
AC_DEFUN([_CIT_TRIVIAL_PETSC_PROGRAM], [
AC_LANG_PROGRAM([[
#include <petsc.h>
]], [[
    PetscInitialize(0, 0, 0, "trivial");
    PetscFinalize();
]])
])dnl _CIT_TRIVIAL_PETSC_PROGRAM


dnl end of file
