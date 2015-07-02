# Ceres Solver - A fast non-linear least squares minimizer
# Copyright 2015 Google Inc. All rights reserved.
# http://ceres-solver.org/
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of Google Inc. nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Author: alexs.mac@gmail.com (Alex Stewart)
#

# FindGflags.cmake - Find Google gflags logging library.
#
# This module will first attempt to find an exported CMake configuration for
# gflags, which should be present for gflags versions >= 2.1 which are built
# with CMake, in which case the exported configuration is used (albeit with
# the values replicated to those below to ensure compatibility).  If no
# exported CMake configuration for gflags is found, then a standard search is
# performed for the gflags components.
#
# This module defines the following variables:
#
# GFLAGS_FOUND: TRUE iff gflags is found.
# GFLAGS_INCLUDE_DIRS: Include directories for gflags.
# GFLAGS_LIBRARIES: Libraries required to link gflags.
# GFLAGS_NAMESPACE: The namespace in which gflags is defined.  In versions of
#                   gflags < 2.1, this was google, for versions >= 2.1 it is
#                   by default gflags, although can be configured when building
#                   gflags to be something else (i.e. google for legacy
#                   compatibility).
#
# The following variables control the behaviour of this module when an exported
# gflags CMake configuration is not found.
#
# GFLAGS_INCLUDE_DIR_HINTS: List of additional directories in which to
#                           search for gflags includes, e.g: /timbuktu/include.
# GFLAGS_LIBRARY_DIR_HINTS: List of additional directories in which to
#                           search for gflags libraries, e.g: /timbuktu/lib.
#
# The following variables are also defined by this module, but in line with
# CMake recommended FindPackage() module style should NOT be referenced directly
# by callers (use the plural variables detailed above instead).  These variables
# do however affect the behaviour of the module via FIND_[PATH/LIBRARY]() which
# are NOT re-called (i.e. search for library is not repeated) if these variables
# are set with valid values _in the CMake cache_. This means that if these
# variables are set directly in the cache, either by the user in the CMake GUI,
# or by the user passing -DVAR=VALUE directives to CMake when called (which
# explicitly defines a cache variable), then they will be used verbatim,
# bypassing the HINTS variables and other hard-coded search locations.
#
# GFLAGS_INCLUDE_DIR: Include directory for gflags, not including the
#                     include directory of any dependencies.
# GFLAGS_LIBRARY: gflags library, not including the libraries of any
#                 dependencies.

# Reset CALLERS_CMAKE_FIND_LIBRARY_PREFIXES to its value when FindGflags was
# invoked, necessary for MSVC.
MACRO(GFLAGS_RESET_FIND_LIBRARY_PREFIX)
  IF (MSVC)
    SET(CMAKE_FIND_LIBRARY_PREFIXES "${CALLERS_CMAKE_FIND_LIBRARY_PREFIXES}")
  ENDIF (MSVC)
ENDMACRO(GFLAGS_RESET_FIND_LIBRARY_PREFIX)

# Called if we failed to find gflags or any of it's required dependencies,
# unsets all public (designed to be used externally) variables and reports
# error message at priority depending upon [REQUIRED/QUIET/<NONE>] argument.
MACRO(GFLAGS_REPORT_NOT_FOUND REASON_MSG)
  UNSET(GFLAGS_FOUND)
  UNSET(GFLAGS_INCLUDE_DIRS)
  UNSET(GFLAGS_LIBRARIES)
  # Do not use unset, as we want to keep GFLAGS_NAMESPACE in the cache,
  # but simply clear its value.
  SET(GFLAGS_NAMESPACE "" CACHE STRING
    "gflags namespace (google or gflags)" FORCE)

  # Make results of search visible in the CMake GUI if gflags has not
  # been found so that user does not have to toggle to advanced view.
  MARK_AS_ADVANCED(CLEAR GFLAGS_INCLUDE_DIR
                         GFLAGS_LIBRARY
                         GFLAGS_NAMESPACE)

  GFLAGS_RESET_FIND_LIBRARY_PREFIX()

  # Note <package>_FIND_[REQUIRED/QUIETLY] variables defined by FindPackage()
  # use the camelcase library name, not uppercase.
  IF (Gflags_FIND_QUIETLY)
    MESSAGE(STATUS "Failed to find gflags - " ${REASON_MSG} ${ARGN})
  ELSEIF (Gflags_FIND_REQUIRED)
    MESSAGE(FATAL_ERROR "Failed to find gflags - " ${REASON_MSG} ${ARGN})
  ELSE()
    # Neither QUIETLY nor REQUIRED, use no priority which emits a message
    # but continues configuration and allows generation.
    MESSAGE("-- Failed to find gflags - " ${REASON_MSG} ${ARGN})
  ENDIF ()
ENDMACRO(GFLAGS_REPORT_NOT_FOUND)

# Verify that all variable names passed as arguments are defined (can be empty
# but must be defined) or raise a fatal error.
MACRO(GFLAGS_CHECK_VARS_DEFINED)
  FOREACH(CHECK_VAR ${ARGN})
    IF (NOT DEFINED ${CHECK_VAR})
      MESSAGE(FATAL_ERROR "Ceres Bug: ${VAR} is not defined.")
    ENDIF()
  ENDFOREACH()
ENDMACRO(GFLAGS_CHECK_VARS_DEFINED)

# Use check_cxx_source_compiles() to compile trivial test programs to determine
# the gflags namespace.  This works on all OSs except Windows.  If using Visual
# Studio, it fails because msbuild forces check_cxx_source_compiles() to use
# CMAKE_BUILD_TYPE=Debug for the test project, which usually breaks detection
# because MSVC requires that the test project use the same build type as gflags,
# which would normally be built in Release.
#
# Defines: GFLAGS_NAMESPACE in the caller's scope with the detected namespace,
#          which is blank (empty string, will test FALSE is CMake conditionals)
#          if detection failed.
FUNCTION(GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_TRY_COMPILE)
  # Verify that all required variables are defined.
  GFLAGS_CHECK_VARS_DEFINED(
    GFLAGS_INCLUDE_DIR GFLAGS_LIBRARY GFLAGS_LINK_LIBRARIES)
  # Ensure that GFLAGS_NAMESPACE is always unset on completion unless
  # we explicitly set if after having the correct namespace.
  SET(GFLAGS_NAMESPACE "" PARENT_SCOPE)

  INCLUDE(CheckCXXSourceCompiles)
  # Setup include path & link library for gflags for CHECK_CXX_SOURCE_COMPILES.
  SET(CMAKE_REQUIRED_INCLUDES ${GFLAGS_INCLUDE_DIR})
  SET(CMAKE_REQUIRED_LIBRARIES ${GFLAGS_LIBRARY} ${GFLAGS_LINK_LIBRARIES})
  # First try the (older) google namespace.  Note that the output variable
  # MUST be unique to the build type as otherwise the test is not repeated as
  # it is assumed to have already been performed.
  CHECK_CXX_SOURCE_COMPILES(
    "#include <gflags/gflags.h>
     int main(int argc, char * argv[]) {
       google::ParseCommandLineFlags(&argc, &argv, true);
       return 0;
     }"
     GFLAGS_IN_GOOGLE_NAMESPACE)
  IF (GFLAGS_IN_GOOGLE_NAMESPACE)
    SET(GFLAGS_NAMESPACE google PARENT_SCOPE)
    RETURN()
  ENDIF()

  # Try (newer) gflags namespace instead.  Note that the output variable
  # MUST be unique to the build type as otherwise the test is not repeated as
  # it is assumed to have already been performed.
  SET(CMAKE_REQUIRED_INCLUDES ${GFLAGS_INCLUDE_DIR})
  SET(CMAKE_REQUIRED_LIBRARIES ${GFLAGS_LIBRARY} ${GFLAGS_LINK_LIBRARIES})
  CHECK_CXX_SOURCE_COMPILES(
    "#include <gflags/gflags.h>
     int main(int argc, char * argv[]) {
        gflags::ParseCommandLineFlags(&argc, &argv, true);
        return 0;
     }"
     GFLAGS_IN_GFLAGS_NAMESPACE)
  IF (GFLAGS_IN_GFLAGS_NAMESPACE)
    SET(GFLAGS_NAMESPACE gflags PARENT_SCOPE)
    RETURN()
  ENDIF (GFLAGS_IN_GFLAGS_NAMESPACE)
ENDFUNCTION(GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_TRY_COMPILE)

# Use regex on the gflags headers to attempt to determine the gflags namespace.
# Checks both gflags.h (contained namespace on versions < 2.1.2) and
# gflags_declare.h, which contains the namespace on versions >= 2.1.2.
# In general, this method should only be used when
# GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_TRY_COMPILE() cannot be used, or has
# failed.
#
# Defines: GFLAGS_NAMESPACE in the caller's scope with the detected namespace,
#          which is blank (empty string, will test FALSE is CMake conditionals)
#          if detection failed.
FUNCTION(GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_REGEX)
  # Verify that all required variables are defined.
  GFLAGS_CHECK_VARS_DEFINED(GFLAGS_INCLUDE_DIR)
  # Ensure that GFLAGS_NAMESPACE is always undefined on completion unless
  # we explicitly set if after having the correct namespace.
  SET(GFLAGS_NAMESPACE "" PARENT_SCOPE)

  # Scan gflags.h to identify what namespace gflags was built with.  On
  # versions of gflags < 2.1.2, gflags.h was configured with the namespace
  # directly, on >= 2.1.2, gflags.h uses the GFLAGS_NAMESPACE #define which
  # is defined in gflags_declare.h, we try each location in turn.
  SET(GFLAGS_HEADER_FILE ${GFLAGS_INCLUDE_DIR}/gflags/gflags.h)
  IF (NOT EXISTS ${GFLAGS_HEADER_FILE})
    GFLAGS_REPORT_NOT_FOUND(
      "Could not find file: ${GFLAGS_HEADER_FILE} "
      "containing namespace information in gflags install located at: "
      "${GFLAGS_INCLUDE_DIR}.")
  ENDIF()
  FILE(READ ${GFLAGS_HEADER_FILE} GFLAGS_HEADER_FILE_CONTENTS)

  STRING(REGEX MATCH "namespace [A-Za-z]+"
    GFLAGS_NAMESPACE "${GFLAGS_HEADER_FILE_CONTENTS}")
  STRING(REGEX REPLACE "namespace ([A-Za-z]+)" "\\1"
    GFLAGS_NAMESPACE "${GFLAGS_NAMESPACE}")

  IF (NOT GFLAGS_NAMESPACE)
    GFLAGS_REPORT_NOT_FOUND(
      "Failed to extract gflags namespace from header file: "
      "${GFLAGS_HEADER_FILE}.")
  ENDIF (NOT GFLAGS_NAMESPACE)

  IF (GFLAGS_NAMESPACE STREQUAL "google" OR
      GFLAGS_NAMESPACE STREQUAL "gflags")
    # Found valid gflags namespace from gflags.h.
    SET(GFLAGS_NAMESPACE "${GFLAGS_NAMESPACE}" PARENT_SCOPE)
    RETURN()
  ENDIF()

  # Failed to find gflags namespace from gflags.h, gflags is likely a new
  # version, check gflags_declare.h, which in newer versions (>= 2.1.2) contains
  # the GFLAGS_NAMESPACE #define, which is then referenced in gflags.h.
  SET(GFLAGS_DECLARE_FILE ${GFLAGS_INCLUDE_DIR}/gflags/gflags_declare.h)
  IF (NOT EXISTS ${GFLAGS_DECLARE_FILE})
    GFLAGS_REPORT_NOT_FOUND(
      "Could not find file: ${GFLAGS_DECLARE_FILE} "
      "containing namespace information in gflags install located at: "
      "${GFLAGS_INCLUDE_DIR}.")
  ENDIF()
  FILE(READ ${GFLAGS_DECLARE_FILE} GFLAGS_DECLARE_FILE_CONTENTS)

  STRING(REGEX MATCH "#define GFLAGS_NAMESPACE [A-Za-z]+"
    GFLAGS_NAMESPACE "${GFLAGS_DECLARE_FILE_CONTENTS}")
  STRING(REGEX REPLACE "#define GFLAGS_NAMESPACE ([A-Za-z]+)" "\\1"
    GFLAGS_NAMESPACE "${GFLAGS_NAMESPACE}")

  IF (NOT GFLAGS_NAMESPACE)
    GFLAGS_REPORT_NOT_FOUND(
      "Failed to extract gflags namespace from declare file: "
      "${GFLAGS_DECLARE_FILE}.")
  ENDIF (NOT GFLAGS_NAMESPACE)

  IF (GFLAGS_NAMESPACE STREQUAL "google" OR
      GFLAGS_NAMESPACE STREQUAL "gflags")
    # Found valid gflags namespace from gflags.h.
    SET(GFLAGS_NAMESPACE "${GFLAGS_NAMESPACE}" PARENT_SCOPE)
    RETURN()
  ENDIF()
ENDFUNCTION(GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_REGEX)

# -----------------------------------------------------------------

# Newer versions of gflags (2.1+) use CMake to build, and thus provide an
# exported CMake configuration.  We use this in preference to perform our own
# manual search for the installed components if it exists.
FIND_PACKAGE(gflags QUIET NO_MODULE)
SET(FOUND_INSTALLED_GFLAGS_CMAKE_CONFIGURATION ${gflags_FOUND})
IF (FOUND_INSTALLED_GFLAGS_CMAKE_CONFIGURATION)
  MESSAGE(STATUS "Detected gflags CMake install version: ${gflags_VERSION}")
  SET(GFLAGS_FOUND ${gflags_FOUND})
  SET(GFLAGS_INCLUDE_DIR ${gflags_INCLUDE_DIR})
  SET(GFLAGS_LIBRARY ${gflags_LIBRARIES})

  # gflags does not export the namespace in their CMake configuration, so
  # use our function to determine what it should be, as it can be either
  # gflags or google dependent upon version & configuration.
  #
  # NOTE: We use the regex method to determine the namespace here, as
  #       check_cxx_source_compiles() will not use imported targets, which
  #       is what gflags will be in this case.
  GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_REGEX()

  IF (NOT GFLAGS_NAMESPACE)
    GFLAGS_REPORT_NOT_FOUND(
      "Failed to determine gflags namespace using regex for gflags "
      "version: ${gflags_VERSION} exported here: ${gflags_DIR} using CMake.")
  ENDIF (NOT GFLAGS_NAMESPACE)
ELSE (FOUND_INSTALLED_GFLAGS_CMAKE_CONFIGURATION)
  # Failed to detect a gflags 2.1+ install exported using CMake, perform
  # a manual search for all components.

  # Handle possible presence of lib prefix for libraries on MSVC, see
  # also GFLAGS_RESET_FIND_LIBRARY_PREFIX().
  IF (MSVC)
    # Preserve the caller's original values for CMAKE_FIND_LIBRARY_PREFIXES
    # s/t we can set it back before returning.
    SET(CALLERS_CMAKE_FIND_LIBRARY_PREFIXES "${CMAKE_FIND_LIBRARY_PREFIXES}")
    # The empty string in this list is important, it represents the case when
    # the libraries have no prefix (shared libraries / DLLs).
    SET(CMAKE_FIND_LIBRARY_PREFIXES "lib" "" "${CMAKE_FIND_LIBRARY_PREFIXES}")
  ENDIF (MSVC)

  # Search user-installed locations first, so that we prefer user installs
  # to system installs where both exist.
  #
  # TODO: Add standard Windows search locations for gflags.
  LIST(APPEND GFLAGS_CHECK_INCLUDE_DIRS
    /usr/local/include
    /usr/local/homebrew/include # Mac OS X
    /opt/local/var/macports/software # Mac OS X.
    /opt/local/include
    /usr/include)
  LIST(APPEND GFLAGS_CHECK_LIBRARY_DIRS
    /usr/local/lib
    /usr/local/homebrew/lib # Mac OS X.
    /opt/local/lib
    /usr/lib)

  # Search supplied hint directories first if supplied.
  FIND_PATH(GFLAGS_INCLUDE_DIR
    NAMES gflags/gflags.h
    PATHS ${GFLAGS_INCLUDE_DIR_HINTS}
    ${GFLAGS_CHECK_INCLUDE_DIRS})
  IF (NOT GFLAGS_INCLUDE_DIR OR
      NOT EXISTS ${GFLAGS_INCLUDE_DIR})
    GFLAGS_REPORT_NOT_FOUND(
      "Could not find gflags include directory, set GFLAGS_INCLUDE_DIR "
      "to directory containing gflags/gflags.h")
  ENDIF (NOT GFLAGS_INCLUDE_DIR OR
    NOT EXISTS ${GFLAGS_INCLUDE_DIR})

  FIND_LIBRARY(GFLAGS_LIBRARY NAMES gflags
    PATHS ${GFLAGS_LIBRARY_DIR_HINTS}
    ${GFLAGS_CHECK_LIBRARY_DIRS})
  IF (NOT GFLAGS_LIBRARY OR
      NOT EXISTS ${GFLAGS_LIBRARY})
    GFLAGS_REPORT_NOT_FOUND(
      "Could not find gflags library, set GFLAGS_LIBRARY "
      "to full path to libgflags.")
  ENDIF (NOT GFLAGS_LIBRARY OR
    NOT EXISTS ${GFLAGS_LIBRARY})

  # gflags typically requires a threading library (which is OS dependent), note
  # that this defines the CMAKE_THREAD_LIBS_INIT variable.  If we are able to
  # detect threads, we assume that gflags requires it.
  FIND_PACKAGE(Threads QUIET)
  SET(GFLAGS_LINK_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})
  # On Windows (including MinGW), the Shlwapi library is used by gflags if
  # available.
  IF (WIN32)
    INCLUDE(CheckIncludeFileCXX)
    CHECK_INCLUDE_FILE_CXX("shlwapi.h" HAVE_SHLWAPI)
    IF (HAVE_SHLWAPI)
      LIST(APPEND GFLAGS_LINK_LIBRARIES shlwapi.lib)
    ENDIF(HAVE_SHLWAPI)
  ENDIF (WIN32)

  # Mark internally as found, then verify. GFLAGS_REPORT_NOT_FOUND() unsets
  # if called.
  SET(GFLAGS_FOUND TRUE)

  # Identify what namespace gflags was built with.
  IF (GFLAGS_INCLUDE_DIR AND NOT GFLAGS_NAMESPACE)
    # To handle Windows peculiarities / CMake bugs on MSVC we try two approaches
    # to detect the gflags namespace:
    #
    # 1) Try to use check_cxx_source_compiles() to compile a trivial program
    #    with the two choices for the gflags namespace.
    #
    # 2) [In the event 1) fails] Use regex on the gflags headers to try to
    #    determine the gflags namespace.  Whilst this is less robust than 1),
    #    it does avoid any interaction with msbuild.
    GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_TRY_COMPILE()

    IF (NOT GFLAGS_NAMESPACE)
      # Failed to determine gflags namespace using check_cxx_source_compiles()
      # method, try and obtain it using regex on the gflags headers instead.
      MESSAGE(STATUS "Failed to find gflags namespace using using "
        "check_cxx_source_compiles(), trying namespace regex instead, "
        "this is expected on Windows.")
      GFLAGS_CHECK_GFLAGS_NAMESPACE_USING_REGEX()

      IF (NOT GFLAGS_NAMESPACE)
        GFLAGS_REPORT_NOT_FOUND(
          "Failed to determine gflags namespace either by "
          "check_cxx_source_compiles(), or namespace regex.")
      ENDIF (NOT GFLAGS_NAMESPACE)
    ENDIF (NOT GFLAGS_NAMESPACE)
  ENDIF (GFLAGS_INCLUDE_DIR AND NOT GFLAGS_NAMESPACE)

  # Make the GFLAGS_NAMESPACE a cache variable s/t the user can view it, and could
  # overwrite it in the CMake GUI.
  SET(GFLAGS_NAMESPACE "${GFLAGS_NAMESPACE}" CACHE STRING
    "gflags namespace (google or gflags)" FORCE)

  # gflags does not seem to provide any record of the version in its
  # source tree, thus cannot extract version.

  # Catch case when caller has set GFLAGS_NAMESPACE in the cache / GUI
  # with an invalid value.
  IF (GFLAGS_NAMESPACE AND
      NOT GFLAGS_NAMESPACE STREQUAL "google" AND
      NOT GFLAGS_NAMESPACE STREQUAL "gflags")
    GFLAGS_REPORT_NOT_FOUND(
      "Caller defined GFLAGS_NAMESPACE:"
      " ${GFLAGS_NAMESPACE} is not valid, not google or gflags.")
  ENDIF ()
  # Catch case when caller has set GFLAGS_INCLUDE_DIR in the cache / GUI and
  # thus FIND_[PATH/LIBRARY] are not called, but specified locations are
  # invalid, otherwise we would report the library as found.
  IF (GFLAGS_INCLUDE_DIR AND
      NOT EXISTS ${GFLAGS_INCLUDE_DIR}/gflags/gflags.h)
    GFLAGS_REPORT_NOT_FOUND(
      "Caller defined GFLAGS_INCLUDE_DIR:"
      " ${GFLAGS_INCLUDE_DIR} does not contain gflags/gflags.h header.")
  ENDIF (GFLAGS_INCLUDE_DIR AND
    NOT EXISTS ${GFLAGS_INCLUDE_DIR}/gflags/gflags.h)
  # TODO: This regex for gflags library is pretty primitive, we use lowercase
  #       for comparison to handle Windows using CamelCase library names, could
  #       this check be better?
  STRING(TOLOWER "${GFLAGS_LIBRARY}" LOWERCASE_GFLAGS_LIBRARY)
  IF (GFLAGS_LIBRARY AND
      NOT "${LOWERCASE_GFLAGS_LIBRARY}" MATCHES ".*gflags[^/]*")
    GFLAGS_REPORT_NOT_FOUND(
      "Caller defined GFLAGS_LIBRARY: "
      "${GFLAGS_LIBRARY} does not match gflags.")
  ENDIF (GFLAGS_LIBRARY AND
    NOT "${LOWERCASE_GFLAGS_LIBRARY}" MATCHES ".*gflags[^/]*")

  GFLAGS_RESET_FIND_LIBRARY_PREFIX()

ENDIF(FOUND_INSTALLED_GFLAGS_CMAKE_CONFIGURATION)

# Set standard CMake FindPackage variables if found.
IF (GFLAGS_FOUND)
  SET(GFLAGS_INCLUDE_DIRS ${GFLAGS_INCLUDE_DIR})
  SET(GFLAGS_LIBRARIES ${GFLAGS_LIBRARY} ${GFLAGS_LINK_LIBRARIES})
ENDIF (GFLAGS_FOUND)

# Handle REQUIRED / QUIET optional arguments.
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(Gflags DEFAULT_MSG
  GFLAGS_INCLUDE_DIRS GFLAGS_LIBRARIES GFLAGS_NAMESPACE)

# Only mark internal variables as advanced if we found gflags, otherwise
# leave them visible in the standard GUI for the user to set manually.
IF (GFLAGS_FOUND)
  MARK_AS_ADVANCED(FORCE GFLAGS_INCLUDE_DIR
    GFLAGS_LIBRARY
    GFLAGS_NAMESPACE)
ENDIF (GFLAGS_FOUND)