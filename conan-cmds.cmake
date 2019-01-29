# The MIT License (MIT)

# Copyright (c) 2019 Mats G. Liljegren, FLIR Systems AB
# Copyright (c) 2018 JFrog

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



# This file comes from: https://github.com/conan-io/cmake-conan. Please refer
# to this repository for issues and documentation.

# Its purpose is to wrap and launch Conan C/C++ Package Manager when cmake is called.
# It will take CMake current settings (os, compiler, compiler version, architecture)
# and translate them to conan settings for installing and retrieving dependencies.

# It is intended to facilitate developers building projects that have conan dependencies,
# but it is only necessary on the end-user side. It is not necessary to create conan
# packages, in fact it shouldn't be use for that. Check the project documentation.

include( CMakeParseArguments )
include( FindPkgConfig )

#
# Checks conan availability in PATH.
# Sets CONAN_CMD to name or full path to Conan shell command.
# Arguments REQUIRED and VERSION are optional.
# Other arguments are passed to find_program().
# NOTE: Arguments to be passed on to find_program() need to be placed first, or else
#       might be mistaken to be arguments to commands understood by conan_check().
# Example usage:
#    conan_check(VERSION 1.0.0 REQUIRED CMAKE_FIND_ROOT_PATH_BOTH)
#
function( conan_check )
    message( STATUS "Conan: checking conan executable in path" )
    message( "conan_check(${ARGV})" )
    cmake_parse_arguments( PARSE_ARGV 0 ARGUMENTS
        "REQUIRED"
        "VERSION"
        "GENERATOR"
    )

    if( NOT DEFINED ARGUMENTS_GENERATOR )
        set( ARGUMENTS_GENERATOR cmake )
    endif()

    find_program( CONAN_CMD conan DOC "Name or full path to conan shell command" ${ARGUMENTS_UNPARSED_ARGUMENTS} )
    if( NOT CONAN_CMD AND ARGUMENTS_REQUIRED )
        message( FATAL_ERROR "Conan executable not found!" )
    endif()
    message( STATUS "Conan: Found program ${CONAN_CMD}" )
    execute_process( COMMAND ${CONAN_CMD} --version
                     OUTPUT_VARIABLE CONAN_VERSION_OUTPUT
                     ERROR_VARIABLE CONAN_VERSION_OUTPUT )
    message( STATUS "Conan: Version found ${CONAN_VERSION_OUTPUT}" )

    # Verify version
    if( DEFINED CONAN_VERSION )
        string( REGEX MATCH ".*Conan version ([0-9]+\.[0-9]+\.[0-9]+)" FOO
            "${CONAN_VERSION_OUTPUT}" )
        if( ${CMAKE_MATCH_1} VERSION_LESS ${CONAN_VERSION} )
            message( FATAL_ERROR "Conan outdated. Installed: ${CONAN_VERSION}, \
                required: ${CONAN_VERSION_REQUIRED}. Consider updating via 'pip \
                install conan --upgrade'." )
        endif()
    endif()

    if( CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE )
        set( MULTI ON )
        message( STATUS "Conan: Using cmake-multi generator" )
    else()
        set( MULTI OFF )
    endif()

    set( CONAN_CMAKE_MULTI ${MULTI} CACHE BOOL "True if CMake supports setting build type during build rather than during configure. This is usually the case when building with Visual Studio or XCode." )

    set( _GENERATORS "" )
    foreach( generator ${ARGUMENTS_GENERATOR} )
        if( ${generator} STREQUAL "cmake" AND CONAN_CMAKE_MULTI )
            set( generator "cmake_multi" )
        endif()
        list( APPEND _GENERATORS ${generator} )
    endforeach()

    set( CONAN_GENERATORS "${_GENERATORS}" CACHE INTERNAL "" )
    message( "CONAN_GENERATORS: ${CONAN_GENERATORS}" )
endfunction()

#
# Helper macro to implement call to Conan shell command.
# options describes valid non-value arguments.
# onevalues describes valid one-value arguments.
# multivalues describes valid multi-value arguments.
#
# Each options, onevalues and multivalues will be pre-pended with "--" and the argument
# name will be lower-case version of the name given by options, onevalues and multivalues.
# For onevalues and multivalues each value will become its own argument, with
# "=<value>" appended.
#
# Example:
#   conan_execute( install "NO_IMPORTS" "INSTALL_FOLDER" "GENERATOR" NO_IMPORTS INSTALL_FOLDER . GENERATOR cmake cmake_find_package )
#
# becomes the following command line:
#
#   conan install --no-imports --install-folder . --generator cmake --generator cmake_find_package
#
macro( conan_execute command_name options onevalues multivalues )
    # @FIXME: Debug code
    message( "Function ${command_name}():")
    message( "- Options.....: ${options}" )
    message( "- One-values..: ${onevalues}" )
    message( "- Multi-values: ${multivalues}" )
    message( "- Arguments...: ${ARGN}" )

    # Make sure we know conan command
    conan_check()

    # Parse arguments for this conan command
    cmake_parse_arguments( ARG "${options}" "${onevalues}" "${multivalues}" ${ARGN} )
    if( DEFINED ARG_UNPARSED_ARGUMENTS )
        # Check for arguments used by CMake function rather than Conan command
        cmake_parse_arguments( EXEC_ARG "" "OUTPUT_VARIABLE;ERROR_VARIABLE;RESULT_VARIABLE;WORKING_DIRECTORY" "" ${ARG_UNPARSED_ARGUMENTS} )
    endif()

    set( conan_options "" )

    # This is the variable that will store all arguments to be given to the Conan command
    list( APPEND conan_options "${command_name}" )

    # Handle options
    foreach( arg_name ${options} )
        if( ARG_${arg_name} )
            message( "Seeing option '${arg_name}'" ) # @FIXME: Debug only
            string( TOLOWER ${arg_name} arg_name_lower )
            string( REPLACE "_" "-" arg_name_lower ${arg_name_lower} )
            list( APPEND conan_options "--${arg_name_lower}" )
        endif()
    endforeach()

    # Handle one value arguments
    foreach( arg_name ${onevalues} )
        if( DEFINED ARG_${arg_name} )
            message( "Seeing one-value '${arg_name}'" ) # @FIXME: Debug only
            string( TOLOWER ${arg_name} arg_name_lower )
            string( REPLACE "_" "-" arg_name_lower ${arg_name_lower} )
            if( ARG_${arg_name} STREQUAL "" )
                list( APPEND conan_options "--${arg_name_lower}" )
            else()
                list( APPEND conan_options "--${arg_name_lower}=${ARG_${arg_name}}" )
                message( "- Value: '${ARG_${arg_name}}'" )
            endif()
        endif()
    endforeach()

    # Handle multi-value arguments
    foreach( arg_name ${multivalues} )
        if( DEFINED ARG_${arg_name} )
            message( "Seeing multi-value '${arg_name}'" ) # @FIXME: Debug only
            string( TOLOWER ${arg_name} arg_name_lower )
            string( REPLACE "_" "-" arg_name_lower ${arg_name_lower} )
            foreach( value ${ARG_${arg_name}} )
                if( ARG_${arg_name} STREQUAL "" )
                    list( APPEND conan_options "--${arg_name_lower}" )
                else()
                    list( APPEND conan_options "--${arg_name_lower}=${value}" )
                    message( "- Value: '${value}'" )
                endif()
            endforeach()
        endif()
    endforeach()

    # Add rest of arguments, if any
    if( DEFINED EXEC_ARG_UNPARSED_ARGUMENTS )
        list( APPEND conan_options ${EXEC_ARG_UNPARSED_ARGUMENTS} )
    endif()

    set( cmdline "" )

    # Make it all into a command line
    list( APPEND cmdline COMMAND ${CONAN_CMD} ${conan_options} )

    if( EXEC_ARG_WORKING_DIRECTORY )
        set( WORKDIR "${EXEC_ARG_WORKING_DIRECTORY}" )
    else()
        set( WORKDIR "${CMAKE_CURRENT_BINARY_DIR}" )
    endif()

    # Execute the command
    message( STATUS "Running: '${cmdline}' in directory '${WORKDIR}'" )
    execute_process( ${cmdline}
                     RESULT_VARIABLE conan_result
                     OUTPUT_VARIABLE conan_output
                     ERROR_VARIABLE  conan_error
                     WORKING_DIRECTORY "${WORKDIR}"
                     )

    message( "${conan_output}" )

    # Print error messages, unless caller takes care of them
    if( DEFINED EXEC_ARG_ERROR_VARIABLE )
        set( ${EXEC_ARG_ERROR_VARIABLE} "${conan_error}" PARENT_SCOPE )
    elseif( conan_error )
        message( "Error messages from conan:" )
        message( "${conan_error}" )
    endif()

    # Only fail if execution fails and caller does not take care of the result code
    if( DEFINED EXEC_ARG_RESULT_VARIABLE )
        set( ${EXEC_ARG_RESULT_VARIABLE} "${conan_result}" PARENT_SCOPE )
    elseif( NOT "${conan_result}" STREQUAL "0" )
        message( FATAL_ERROR "${cmdline}: Returned error code ${conan_result}" )
    endif()

    if( DEFINED EXEC_ARG_OUTPUT_VARIABLE )
        set( ${EXEC_ARG_OUTPUT_VARIABLE} "${conan_output}" PARENT_SCOPE )
    endif()
endmacro()

#
# Description of valid Conan command syntaxes
#

function( conan_cmd_install )
    conan_execute( install
        "NO_IMPORTS;UPDATE"
        "INSTALL_FOLDER;MANIFESTS;MANIFESTS_INTERACTIVE;VERIFY;JSON;REMOTE"
        "GENERATOR;BUILD;ENV;OPTIONS;PROFILE;SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_rm )
    conan_execute( "config;rm"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_set )
    conan_execute( "config;set"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_get )
    conan_execute( "config;get"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_install )
    conan_execute( "config;install"
        ""
        "VERIFY_SSL;TYPE;ARGS"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_get )
    conan_execute( get
        "RAW"
        "PACKAGE;REMOTE"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_info )
    conan_execute( info
        "PATHS;UPDATE"
        "BUILD_ORDER;GRAPH;INSTALL_FOLDER;JSON;PACKAGE_FILTER;DRY_BUILD;PROFILE;REMOTE"
        "ONLY;ENV;OPTIONS;SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_search )
    conan_execute( search
        "OUTDATED;CASE_SENSITIVE;RAW"
        "QUERY;REMOTE;TABLE;JSON"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_new )
    conan_execute( new
        "TEST;HEADER;PURE_C;SOURCES;BARE;CI_SHARED;CI_TRAVIS_GCC;CI_TRAVIS_CLANG;CI_TRAVIS_OSX;CI_APPVEYOR_WIN;CI_GITLAB_GCC;CI_GITLAB_CLANG;CI_CIRCLECI_GCC;CI_CIRCLECI_CLANG;CI_CIRCLECI_OSX;GITIGNORE"
        "CI_UPLOAD_URL"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_create )
    conan_execute( create
        "KEEP_SOURCE;KEEP_BUILD;NOT_EXPORT;UPDATE"
        "JSON;TEST_BUILD_FOLDER;TEST_FOLDER;MANIFESTS;MANIFESTS_INTERACTIVE;VERIFY;BUILD;PROFILE;REMOTE"
        "ENV;OPTIONS;SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_upload )
    conan_execute( upload
        "ALL;SKIP_UPLOAD;FORCE;CHECK;CONFIRM"
        "PACKAGE;QUERY;REMOTE;RETRY;RETRY_WAIT;NO_OVERWRITE;JSON"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_export )
    conan_execute( export
        "KEEP_SOURCE"
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_export_pkg )
    conan_execute( export-pkg
        "FORCE"
        "BUILD_FOLDER;INSTALL_FOLDER;PROFILE;PACKAGE_FOLDER;SOURCE_FOLDER;JSON"
        "ENV;OPTIONS;SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_test )
    conan_execute( test
        "UPDATE"
        "TEST_BUILD_FOLDER;BUILD;PROFILE;REMOTE"
        "ENV;OPTIONS;SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_source )
    conan_execute( source
        ""
        "SOURCE_FOLDER;INSTALL_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_build )
    conan_execute( build
        "BUILD;CONFIGURE;INSTALL;TEST"
        "BUILD_FOLDER;INSTALL_FOLDER;PACKAGE_FOLDER;SOURCE_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_package )
    conan_execute( package
        ""
        "BUILD_FOLDER;INSTALL_FOLDER;PACKAGE_FOLDER;SOURCE_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_list )
    conan_execute( "profile;list"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_show )
    conan_execute( "profile;show"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_new )
    conan_execute( "profile;new"
        "DETECT"
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_update )
    conan_execute( "profile;update"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_get )
    conan_execute( "profile;get"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_remove )
    conan_execute( "profile;remove"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_list )
    conan_execute( "remote;list"
        "RAW"
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_add )
    conan_execute( "remote;add"
        "FORCE"
        "INSERT"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_remove )
    conan_execute( "remote;remove"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_update )
    conan_execute( "remote;update"
        ""
        "INSERT"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_rename )
    conan_execute( "remote;rename"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_list_ref )
    conan_execute( "remote;list_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_add_ref )
    conan_execute( "remote;add_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_remove_ref )
    conan_execute( "remote;remove_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_update_ref )
    conan_execute( "remote;update_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_list_pref )
    conan_execute( "remote;list_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_add_pref )
    conan_execute( "remote;add_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_remove_pref )
    conan_execute( "remote;remove_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_update_pref )
    conan_execute( "remote;update_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_clean )
    conan_execute( "remote;clean"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_user )
    conan_execute( user
        "CLEAN"
        "PASSWORD;REMOTE;JSON"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_imports )
    conan_execute( imports
        "UNDO"
        "INSTALL_FOLDER;IMPORT_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_copy )
    conan_execute( copy
        "ALL FORCE"
        "PACKAGE"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remove )
    conan_execute( remove
        "FORCE;OUTDATED;SRC;LOCKS"
        "BUILDS;PACKAGES;QUERY;REMOTE"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_alias )
    conan_execute( alias
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_download )
    conan_execute( download
        "RECIPE"
        "PACKAGE;REMOTE"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_inspect )
    conan_execute( inspect
        ""
        "REMOTE;JSON"
        "ATTRIBUTE"
        ${ARGN}
    )
endfunction()

#
# Higher order functions
#

#
# Helper function to determine version of Visual Studio
#
function(_get_msvc_ide_version result)
    set(${result} "" PARENT_SCOPE)
    if(NOT MSVC_VERSION VERSION_LESS 1400 AND MSVC_VERSION VERSION_LESS 1500)
        set(${result} 8 PARENT_SCOPE)
    elseif(NOT MSVC_VERSION VERSION_LESS 1500 AND MSVC_VERSION VERSION_LESS 1600)
        set(${result} 9 PARENT_SCOPE)
    elseif(NOT MSVC_VERSION VERSION_LESS 1600 AND MSVC_VERSION VERSION_LESS 1700)
        set(${result} 10 PARENT_SCOPE)
    elseif(NOT MSVC_VERSION VERSION_LESS 1700 AND MSVC_VERSION VERSION_LESS 1800)
        set(${result} 11 PARENT_SCOPE)
    elseif(NOT MSVC_VERSION VERSION_LESS 1800 AND MSVC_VERSION VERSION_LESS 1900)
        set(${result} 12 PARENT_SCOPE)
    elseif(NOT MSVC_VERSION VERSION_LESS 1900 AND MSVC_VERSION VERSION_LESS 1910)
        set(${result} 14 PARENT_SCOPE)
    elseif(NOT MSVC_VERSION VERSION_LESS 1910 AND MSVC_VERSION VERSION_LESS 1920)
        set(${result} 15 PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Conan: Unknown MSVC compiler version [${MSVC_VERSION}]")
    endif()
endfunction()

#
# Calculate platform arguments to be used in call to conan_cmd_install().
#
function(conan_cmake_settings result)
    message( "conan_cmake_settings(${ARGV})" )
    cmake_parse_arguments(PARSE_ARGV 1 ARGUMENTS
        ""
        "ARCH;DEBUG_PROFILE;RELEASE_PROFILE;RELWITHDEBINFO_PROFILE;MINSIZEREL_PROFILE;PROFILE"
        "PROFILE_AUTO;SETTINGS"
        )

    # Accept unknown arguments to make argument forwarding easier.

    message(STATUS "Conan: Automatic detection of conan settings from cmake")

    if(ARGUMENTS_ARCH)
        set(_CONAN_SETTING_ARCH ${ARGUMENTS_ARCH})
    endif()
    #handle -s os setting
    if(CMAKE_SYSTEM_NAME)
        #use default conan os setting if CMAKE_SYSTEM_NAME is not defined
        set(CONAN_SYSTEM_NAME ${CMAKE_SYSTEM_NAME})
        if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
            set(CONAN_SYSTEM_NAME Macos)
        endif()
        set(CONAN_SUPPORTED_PLATFORMS Windows Linux Macos Android iOS FreeBSD WindowsStore)
        list (FIND CONAN_SUPPORTED_PLATFORMS "${CONAN_SYSTEM_NAME}" _index)
        if (${_index} GREATER -1)
            #check if the cmake system is a conan supported one
            set(_CONAN_SETTING_OS ${CONAN_SYSTEM_NAME})
        else()
            message(FATAL_ERROR "cmake system ${CONAN_SYSTEM_NAME} is not supported by conan. Use one of ${CONAN_SUPPORTED_PLATFORMS}")
        endif()
    endif()

    get_property(_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
    if (";${_languages};" MATCHES ";CXX;")
        set(LANGUAGE CXX)
        set(USING_CXX 1)
    elseif (";${_languages};" MATCHES ";C;")
        set(LANGUAGE C)
        set(USING_CXX 0)
    else ()
        message(FATAL_ERROR "Conan: Neither C or C++ was detected as a language for the project. Unabled to detect compiler version.")
    endif()

    if (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL GNU)
        # using GCC
        # TODO: Handle other params
        string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
        list(GET VERSION_LIST 0 MAJOR)
        list(GET VERSION_LIST 1 MINOR)
        set(COMPILER_VERSION ${MAJOR}.${MINOR})
        if(${MAJOR} GREATER 4)
            set(COMPILER_VERSION ${MAJOR})
        endif()
        set(_CONAN_SETTING_COMPILER gcc)
        set(_CONAN_SETTING_COMPILER_VERSION ${COMPILER_VERSION})
        if (USING_CXX)
            conan_cmake_detect_gnu_libcxx(_LIBCXX)
            set(_CONAN_SETTING_COMPILER_LIBCXX ${_LIBCXX})
        endif ()
    elseif (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL AppleClang)
        # using AppleClang
        string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
        list(GET VERSION_LIST 0 MAJOR)
        list(GET VERSION_LIST 1 MINOR)
        set(_CONAN_SETTING_COMPILER apple-clang)
        set(_CONAN_SETTING_COMPILER_VERSION ${MAJOR}.${MINOR})
        if (USING_CXX)
            set(_CONAN_SETTING_COMPILER_LIBCXX libc++)
        endif ()
    elseif (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL Clang)
        string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
        list(GET VERSION_LIST 0 MAJOR)
        list(GET VERSION_LIST 1 MINOR)
        if(APPLE)
            cmake_policy(GET CMP0025 APPLE_CLANG_POLICY_ENABLED)
            if(NOT APPLE_CLANG_POLICY_ENABLED)
                message(STATUS "Conan: APPLE and Clang detected. Assuming apple-clang compiler. Set CMP0025 to avoid it")
                set(_CONAN_SETTING_COMPILER apple-clang)
                set(_CONAN_SETTING_COMPILER_VERSION ${MAJOR}.${MINOR})
            else()
                set(_CONAN_SETTING_COMPILER clang)
                set(_CONAN_SETTING_COMPILER_VERSION ${MAJOR}.${MINOR})
            endif()
            if (USING_CXX)
                set(_CONAN_SETTING_COMPILER_LIBCXX libc++)
            endif ()
        else()
            set(_CONAN_SETTING_COMPILER clang)
            if(${MAJOR} GREATER 7)
                set(_CONAN_SETTING_COMPILER_VERSION ${MAJOR})
            else()
                set(_CONAN_SETTING_COMPILER_VERSION ${MAJOR}.${MINOR})
            endif()
            if (USING_CXX)
                conan_cmake_detect_gnu_libcxx(_LIBCXX)
                set(_CONAN_SETTING_COMPILER_LIBCXX ${_LIBCXX})
            endif ()
        endif()
    elseif(${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL MSVC)
        set(_VISUAL "Visual Studio")
        _get_msvc_ide_version(_VISUAL_VERSION)
        if("${_VISUAL_VERSION}" STREQUAL "")
            message(FATAL_ERROR "Conan: Visual Studio not recognized")
        else()
            set(_CONAN_SETTING_COMPILER ${_VISUAL})
            set(_CONAN_SETTING_COMPILER_VERSION ${_VISUAL_VERSION})
        endif()

        if(NOT _CONAN_SETTING_ARCH)
            if (MSVC_${LANGUAGE}_ARCHITECTURE_ID MATCHES "64")
                set(_CONAN_SETTING_ARCH x86_64)
            elseif (MSVC_${LANGUAGE}_ARCHITECTURE_ID MATCHES "^ARM")
                message(STATUS "Conan: Using default ARM architecture from MSVC")
                set(_CONAN_SETTING_ARCH armv6)
            elseif (MSVC_${LANGUAGE}_ARCHITECTURE_ID MATCHES "86")
                set(_CONAN_SETTING_ARCH x86)
            else ()
                message(FATAL_ERROR "Conan: Unknown MSVC architecture [${MSVC_${LANGUAGE}_ARCHITECTURE_ID}]")
            endif()
        endif()

        conan_cmake_detect_vs_runtime(_vs_runtime)
        message(STATUS "Conan: Detected VS runtime: ${_vs_runtime}")
        set(_CONAN_SETTING_COMPILER_RUNTIME ${_vs_runtime})

        if (CMAKE_GENERATOR_TOOLSET)
            set(_CONAN_SETTING_COMPILER_TOOLSET ${CMAKE_VS_PLATFORM_TOOLSET})
        elseif(CMAKE_VS_PLATFORM_TOOLSET AND (CMAKE_GENERATOR STREQUAL "Ninja"))
            set(_CONAN_SETTING_COMPILER_TOOLSET ${CMAKE_VS_PLATFORM_TOOLSET})
        endif()
    else()
        message(FATAL_ERROR "Conan: compiler setup not recognized")
    endif()

    # If profile is defined it is used
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND ARGUMENTS_DEBUG_PROFILE)
        set(_PROFILE ${ARGUMENTS_DEBUG_PROFILE})
    elseif(CMAKE_BUILD_TYPE STREQUAL "Release" AND ARGUMENTS_RELEASE_PROFILE)
        set(_PROFILE ${ARGUMENTS_RELEASE_PROFILE})
    elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo" AND ARGUMENTS_RELWITHDEBINFO_PROFILE)
        set(_PROFILE ${ARGUMENTS_RELWITHDEBINFO_PROFILE})
    elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel" AND ARGUMENTS_MINSIZEREL_PROFILE)
        set(_PROFILE ${ARGUMENTS_MINSIZEREL_PROFILE})
    elseif(ARGUMENTS_PROFILE)
        set(_PROFILE ${ARGUMENTS_PROFILE})
    endif()

    if(NOT ARGUMENTS_PROFILE_AUTO OR ARGUMENTS_PROFILE_AUTO STREQUAL "ALL")
        set(ARGUMENTS_PROFILE_AUTO arch build_type compiler compiler.version
                                   compiler.runtime compiler.libcxx compiler.toolset)
    endif()

    set(_SETTINGS "")

    # Automatic from CMake
    foreach(ARG ${ARGUMENTS_PROFILE_AUTO})
        string(TOUPPER ${ARG} _arg_name)
        string(REPLACE "." "_" _arg_name ${_arg_name})
        if(_CONAN_SETTING_${_arg_name})
            list(APPEND _SETTINGS "${ARG}=${_CONAN_SETTING_${_arg_name}}")
        endif()
    endforeach()

    list(APPEND _SETTINGS ${ARGUMENTS_SETTINGS})

    set(_RESULT "")

    if(_PROFILE)
        list(APPEND _RESULT PROFILE ${_PROFILE})
    endif()

    if(_SETTINGS)
        list(APPEND _RESULT SETTINGS ${_SETTINGS})
    endif()

    if(CONAN_GENERATORS)
        list(APPEND _RESULT GENERATOR ${CONAN_GENERATORS})
    endif()

    # Prepend list with arguments not handled
    list( INSERT _RESULT 0 "${ARGUMENTS_UNPARSED_ARGUMENTS}")

    message(STATUS "Conan settings: '${_RESULT}'")

    set(${result} ${_RESULT} PARENT_SCOPE)
endfunction()

#
#
#
function(conan_cmake_detect_gnu_libcxx result)
    # Allow -D_GLIBCXX_USE_CXX11_ABI=ON/OFF as argument to cmake
    if(DEFINED _GLIBCXX_USE_CXX11_ABI)
        if(_GLIBCXX_USE_CXX11_ABI)
            set(${result} libstdc++11 PARENT_SCOPE)
            return()
        else()
            set(${result} libstdc++ PARENT_SCOPE)
            return()
        endif()
    endif()

    # Check if there's any add_definitions(-D_GLIBCXX_USE_CXX11_ABI=0)
    get_directory_property(defines DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} COMPILE_DEFINITIONS)
    foreach(define ${defines})
        if(define STREQUAL "_GLIBCXX_USE_CXX11_ABI=0")
            set(${result} libstdc++ PARENT_SCOPE)
            return()
        endif()
    endforeach()

    # Use C++11 stdlib as default if gcc is 5.1+
    if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "5.1")
      set(${result} libstdc++ PARENT_SCOPE)
    else()
      set(${result} libstdc++11 PARENT_SCOPE)
    endif()
endfunction()

#
#
#
function(conan_cmake_detect_vs_runtime result)
    string(TOUPPER ${CMAKE_BUILD_TYPE} build_type)
    set(variables CMAKE_CXX_FLAGS_${build_type} CMAKE_C_FLAGS_${build_type} CMAKE_CXX_FLAGS CMAKE_C_FLAGS)
    foreach(variable ${variables})
        string(REPLACE " " ";" flags ${${variable}})
        foreach (flag ${flags})
            if(${flag} STREQUAL "/MD" OR ${flag} STREQUAL "/MDd" OR ${flag} STREQUAL "/MT" OR ${flag} STREQUAL "/MTd")
                string(SUBSTRING ${flag} 1 -1 runtime)
                set(${result} ${runtime} PARENT_SCOPE)
                return()
            endif()
        endforeach()
    endforeach()
    if(${build_type} STREQUAL "DEBUG")
        set(${result} "MDd" PARENT_SCOPE)
    else()
        set(${result} "MD" PARENT_SCOPE)
    endif()
endfunction()

#
#
#
function(conan_cmake_setup_conanfile)
    cmake_parse_arguments(PARSE_ARGV 0 ARGUMENTS "" "CONANFILE;WORKING_DIRECTORY" "")
    if(ARGUMENTS_CONANFILE)
        if( NOT IS_ABSOLUTE ${ARGUMENTS_CONANFILE} AND ARGUMENTS_WORKING_DIRECTORY )
            string( PREPEND ARGUMENTS_CONANFILE ${ARGUMENTS_WORKING_DIRECTORY}/ )
        endif()
        if( IS_DIRECTORY ${ARGUMENTS_CONANFILE} )
            if( EXISTS ${ARGUMENTS_CONANFILE}/conanfile.txt )
                set( ARGUMENTS_CONANFILE "${ARGUMENTS_CONANFILE}/conanfile.txt" )
            else()
                set( ARGUMENTS_CONANFILE "${ARGUMENTS_CONANFILE}/conanfile.py" )
            endif()
        endif()
        # configure_file will make sure cmake re-runs when conanfile is updated
        configure_file(${ARGUMENTS_CONANFILE} ${ARGUMENTS_CONANFILE}.junk)
        file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/${ARGUMENTS_CONANFILE}.junk)
    else()
        conan_cmake_generate_conanfile(${ARGV})
    endif()
endfunction()

#
# (Re-)create conanfile.txt in current build directory.
# Uses generators selected by conan_check().
# Each call to this function will add to requires and imports.
# Options will be set to latest value specified.
#
function( conan_cmake_generate_conanfile )
    # Generate, writing in disk a conanfile.txt with the requires, options, and imports
    # specified as arguments
    # This will be considered as temporary file, generated in CMAKE_CURRENT_BINARY_DIR)
    cmake_parse_arguments( PARSE_ARGV 0 ARGUMENTS
        "REQUIRES_OVERRIDE"
        ""
        "REQUIRES;OPTIONS;IMPORTS"
    )
    message( "conan_cmake_generate_conanfile(${ARGV})" )
    message( "Generating '${CMAKE_CURRENT_BINARY_DIR}/conanfile.txt'" )
    message( "Generators: ${CONAN_GENERATORS}" )
    message( "Requires (cached): ${CONAN_CONANFILE_REQUIRES}" )
    message( "Requires: ${ARGUMENTS_REQUIRES}" )
    message( "Options: ${ARGUMENTS_OPTIONS}" )
    message( "Imports: ${ARGUMENTS_IMPORTS}" )

    set( _FN "${CMAKE_CURRENT_BINARY_DIR}/conanfile.txt" )

    file( WRITE ${_FN} "[generators]\n" )
    foreach( ARG ${CONAN_GENERATORS} )
        file( APPEND ${_FN} ${ARG} "\n" )
    endforeach()

    file( APPEND ${_FN} "\n[requires]\n" )
    foreach( ARG ${ARGUMENTS_REQUIRES} )
        file( APPEND ${_FN} ${ARG} "\n" )
    endforeach()


    file( APPEND ${_FN} ${ARG} "\n[options]\n" )
    foreach( ARG ${ARGUMENTS_OPTIONS} )
        file( APPEND ${_FN} ${ARG} "\n" )
    endforeach()

    file( APPEND ${_FN} ${ARG} "\n[imports]\n" )
        foreach( ARG ${ARGUMENTS_IMPORTS} )
        file( APPEND ${_FN} ${ARG} "\n" )
    endforeach()
endfunction()

#
# Load conanbuildinfo[_multi].cmake
#
function(conan_load_buildinfo)
    cmake_parse_arguments( PARSE_ARGV 0 ARGUMENTS "" "WORKING_DIRECTORY" "" )

    if( DEFINED ARGUMENTS_WORKING_DIRECTORY )
        set( _CONANBUILDINFO "${ARGUMENTS_WORKING_DIRECTORY}/" )
    else()
        set( _CONANBUILDINFO "${CMAKE_CURRENT_BINARY_DIR}/" )
    endif()

    if(CONAN_CMAKE_MULTI)
      string( APPEND _CONANBUILDINFO conanbuildinfo_multi.cmake )
    else()
      string( APPEND _CONANBUILDINFO conanbuildinfo.cmake )
    endif()

    # Checks for the existence of conanbuildinfo.cmake, and loads it
    # important that it is macro, so variables defined at parent scope
    if( EXISTS "${_CONANBUILDINFO}" )
      message( STATUS "Conan: Loading ${_CONANBUILDINFO}" )
      include( ${_CONANBUILDINFO} )
    else()
      message( FATAL_ERROR "${_CONANBUILDINFO} doesn't exist" )
    endif()
endfunction()

#
# Check if any item in list search_for is in list in_list.
#
function( is_in_list result_variable search_for in_list )
    foreach( search_item ${search_for} )
        foreach( item ${in_list} )
            if( "${search_item}" STREQUAL "${item}" )
                set( ${result_variable} YES PARENT_SCOPE )
                return()
            endif()
        endforeach()
    endforeach()

    set( ${result_variable} NO PARENT_SCOPE )
endfunction()

#
# Called by conan_install() when there is an overriding dependency.
# Creates a conanfile which depends on the given reference and which
# also includes requires overrides.
#
# Arguments:
#   reference - Conan reference to package whose version is to be overridden
#   requires_override - List of Conan references. For each entry in this list, if it
#               requires <reference>, then the version of <reference> given in this
#               call will be used rather than what was specified in the original
#               requires attribute.
#
# Template variables for conanfile_requires_override_template.py:
#   wrapper_name - Name of the Conan package wrapping the Conan package to override
#   version      - Version of package to override, the wrapper will get the same version
#   requires     - Value for the Conan wrapper package's requires attribute
#
function( conan_install_wrapper reference requires_override )
    cmake_parse_arguments( PARSE_ARGV 2 ARGUMENTS
        ""
        "CONANFILE"
        ""
    )
    if( ARGUMENTS_CONANFILE )
        message( WARNING "CONANFILE argument ignored since it is not applicable when REQUIRES_OVERRIDE is given" )
    endif()

    # Calculate requires line
    set( requires "" )

    foreach( dep ${requires_override} )
        if( requires )
            string( APPEND requires "," )
        endif()
        string( APPEND requires "('${reference}',('${dep}','override')" )
    endforeach()

    message( "reference: ${reference}" )
    string( REGEX MATCH "^[^/]*(/)([^@])" name "${reference}" )
    set( version "${CMAKE_MATCH_1}" )
    set( wrapper_name "${name}_wrapper" )
    set( WORKDIR "${CMAKE_BINARY_DIR}/conan-wrappers/${wrapper_name}" )
    file( MAKE_DIRECTORY "${WORKDIR}" )
    find_path( TEMPLATE_PATH conanfile_requires_override_template.py CMAKE_FIND_ROOT_PATH_BOTH )
    configure_file( ${TEMPLATE_PATH}/conanfile_requires_override_template.py ${WORKDIR}/conanfile.py @ONLY )

    conan_install( ${wrapper_name}/${version}@wrapper/stable CONANFILE . WORKING_DIRECTORY ${WORKDIR} ${ARGUMENTS_UNPARSED_ARGUMENTS} )
endfunction()

#
# Get property named property_name from target. If not found, return empty string.
# Assume property is a ;-separated list, which will be transformed to a list with
# the syntax '<entry>','<entry>',...
#
function( conan_property_list VAR target property_name )
    get_target_property( VAR_list ${target} ${property_name} )
    if( VAR_list STREQUAL "" OR VAR_list STREQUAL "VAR_list-NOTFOUND" )
        set( ${VAR} "" PARENT_SCOPE )
        return()
    endif()

    set( VAR_local "" )
    foreach( entry ${VAR_list} )
        if( VAR_local STREQUAL "" )
            set( VAR_local "'${entry}'" )
        else()
            set( VAR_local "${VAR_local},'${entry}'" )
        endif()
    endforeach()

    set( ${VAR} "${VAR_local}" PARENT_SCOPE )
endfunction()

#
# Get property named property_name from target. If not found, return empty string.
#
function( conan_property VAR target property_name )
    get_target_property( VAR_local ${target} ${property_name} )
    if( VAR_local STREQUAL "" OR VAR_local STREQUAL "VAR_local-NOTFOUND" )
        set( ${VAR} "" PARENT_SCOPE )
        return()
    endif()

    set( ${VAR} "${VAR_local}" PARENT_SCOPE )
endfunction()

#
# Creates a package description for this library with information known to CMake.
# This function is implemented as a wrapper for conan_install(), and all extra arguments
# given to this function will be forwarded to conan_install().
#
# If special arguments need to be given for finding the <target>, call find_package() before
# calling this function. This way, this function will use the cached result of this find_package()
# call.
#
# Arguments:
#   lib     - Name of library as known to Conan
#   package - CMake package name of library
#   target  - CMake target name
#
# Template variables for conanfile_syslib_template.py:
#   lib - Conan name of library
#   lib_includes
#   lib_dirs
#   lib_deps
#   lib_defines
#   lib_compile_options
#   lib_ldflags
#   lib_version
#
# NOTE: The library CMAKE_TARGET must already have been found by CMake!
#
function( conan_install_system_library_wrapper lib package target )
    find_package( ${package} REQUIRED )

    if( NOT TARGET ${target} )
        message( FATAL_ERROR "Target not defined: '${target}'" )
    endif()

    # Extract information into lib_* variables
    conan_property_list( lib_includes ${target} INTERFACE_INCLUDE_DIRECTORIES )
    conan_property_list( lib_dirs ${target} IMPORTED_LOCATION )
    conan_property_list( lib_deps ${target} INTERFACE_LINK_LIBRARIES )
    conan_property_list( lib_defines ${target} INTERFACE_COMPILE_DEFINITIONS )
    conan_property_list( lib_compile_options ${target} INTERFACE_COMPILE_OPTIONS )
    conan_property_list( lib_ldflags ${target} INTERFACE_LINK_LIBRARIES )

    if( ${package}_VERSION_STRING )
        set( lib_version ${${package}_VERSION_STRING} )
    else()
        conan_property( lib_version ${target} VERSION )
    endif()

    if( lib_version STREQUAL "" )
        message( STATUS "Trying pkg-config" )
        pkg_get_variable( lib_version ${lib} modversion )
    endif()

    if( lib_version STREQUAL "" )
        message( FATAL_ERROR "Could not determine version of target '${target}'" )
    endif()

    set( WORKDIR "${CMAKE_BINARY_DIR}/conan-wrappers/${lib}" )
    file( MAKE_DIRECTORY "${WORKDIR}" )
    find_path( TEMPLATE_PATH conanfile_syslib_template.py CMAKE_FIND_ROOT_PATH_BOTH )
    configure_file( ${TEMPLATE_PATH}/conanfile_syslib_template.py ${WORKDIR}/conanfile.py @ONLY )

    conan_install( ${lib}/${lib_version}@wrapper/stable CONANFILE . WORKING_DIRECTORY ${WORKDIR} ${ARGN} )
endfunction()

#
# Install a Conan package.
# <reference> is always a reference. To build using a conanfile, use
# CONANFILE <full_path>
# Argument GENERATE_CONANFILE will generate a conanfile.txt in current build
# directory where [requires] section will have <reference> added to it.
#
function( conan_install reference )
    message( "conan_install(${ARGV})" ) # @FIXME: Debug only

    cmake_parse_arguments( PARSE_ARGV 1 ARGUMENTS
        "CMAKE_TARGETS;KEEP_RPATHS;NO_OUTPUT_DIRS"
        "CONANFILE"
        "GENERATOR"
    )

    if( DEFINED ARGUMENTS_GENERATOR )
        message( WARNING "Argument 'GENERATOR' should be given to conan_check(). It will be ignored here." )
    endif()

#     conan_cmake_setup_conanfile( ${ARGN} )
    if( ARGUMENTS_CONANFILE )
        set( path_or_ref ${ARGUMENTS_CONANFILE} )
    else()
        set( path_or_ref ${reference} )
    endif()

    if( CONAN_CMAKE_MULTI )
        foreach( CMAKE_BUILD_TYPE ${CMAKE_CONFIGURATION_TYPES} )
            set( ENV{CONAN_IMPORT_PATH} ${CMAKE_BUILD_TYPE} )
            conan_cmake_settings( settings ${ARGUMENTS_UNPARSED_ARGUMENTS} )
            conan_cmd_install( ${path_or_ref} ${settings} )
        endforeach()
        set( CMAKE_BUILD_TYPE )
    else()
        conan_cmake_settings( settings ${ARGUMENTS_UNPARSED_ARGUMENTS} )
        conan_cmd_install( ${path_or_ref} ${settings} )
    endif()

    is_in_list( in_list_cmake "cmake;cmake_multi" "${CONAN_GENERATORS}" )
    if( in_list_cmake )    
        conan_load_buildinfo(${ARGN})
    endif()

    if( ARGUMENTS_BASIC_SETUP )
        foreach( _option CMAKE_TARGETS KEEP_RPATHS NO_OUTPUT_DIRS )
            if( ARGUMENTS_${_option} )
                if( ${_option} STREQUAL "CMAKE_TARGETS" )
                    list( APPEND _setup_options "TARGETS" )
                else()
                    list( APPEND _setup_options ${_option} )
                endif()
            endif()
        endforeach()
        conan_basic_setup( ${_setup_options} )
    endif()
endfunction()

