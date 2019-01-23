# The MIT License (MIT)

# Copyright (c) 2019 Mats G. Liljegren, FLIR Systems AB

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

# This file contains the CMake interface towards Conan shell command. It is used by
# conan.cmake.

#
# Checks conan availability in PATH.
# Arguments REQUIRED and VERSION are optional.
# Other arguments are passed to find_program().
# Example usage:
#    conan_check(VERSION 1.0.0 REQUIRED CMAKE_FIND_ROOT_PATH_BOTH)
#
function( conan_check )
    message( STATUS "Conan: checking conan executable in path" )
    set( options REQUIRED )
    set( oneValueArgs VERSION )
    cmake_parse_arguments( CONAN "${options}" "${oneValueArgs}" "" ${ARGN} )

    find_program( CONAN_CMD conan DOC "Name or full path to conan shell command" ${ARG_UNPARSED_ARGUMENTS} )
    if( NOT CONAN_CMD AND CONAN_REQUIRED )
        message( FATAL_ERROR "Conan executable not found!" )
    endif()
    message( STATUS "Conan: Found program ${CONAN_CMD}" )
    execute_process( COMMAND ${CONAN_CMD} --version
                     OUTPUT_VARIABLE CONAN_VERSION_OUTPUT
                     ERROR_VARIABLE CONAN_VERSION_OUTPUT )
    message( STATUS "Conan: Version found ${CONAN_VERSION_OUTPUT}" )

    if( DEFINED CONAN_VERSION )
        string( REGEX MATCH ".*Conan version ([0-9]+\.[0-9]+\.[0-9]+)" FOO
            "${CONAN_VERSION_OUTPUT}" )
        if( ${CMAKE_MATCH_1} VERSION_LESS ${CONAN_VERSION} )
            message( FATAL_ERROR "Conan outdated. Installed: ${CONAN_VERSION}, \
                required: ${CONAN_VERSION_REQUIRED}. Consider updating via 'pip \
                install conan --upgrade'." )
        endif()
    endif()
endfunction()

#
# Call conan shell command with the given command name.
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
    # Make sure we know conan command
    conan_check()

    # Parse arguments for this conan command
    cmake_parse_arguments( ARG "${options}" "${onevalues}" "${multivalues}" ${ARGN} )
    if( DEFINED ARG_UNPARSED_ARGUMENTS )
        # Check for arguments used by CMake function rather than Conan command
        cmake_parse_arguments( EXEC_ARG "" "OUTPUT_VARIABLE ERROR_VARIABLE RESULT_VARIABLE" "" ${ARG_UNPARSED_ARGUMENTS} )
    endif()

    # This is the variable that will store all arguments to be given to the Conan command
    set( conan_options "${command_name}" )

    # Handle options
    foreach( arg_name ${options} )
        if( ARG_${arg_name} )
            string( TOLOWER arg_name_lower ${arg_name} )
            string( REPLACE "_" "-" arg_name_lower ${arg_name_lower} )
            set( conan_options "${conan_options} --${arg_name_lower}" )
        endif()
    endforeach()

    # Handle one value arguments
    foreach( arg_name ${onevalues} )
        if( DEFINED ARG_${arg_name} )
            string( TOLOWER arg_name_lower ${arg_name} )
            string( REPLACE "_" "-" arg_name_lower ${arg_name_lower} )
            if( ARG_${arg_name} STREQUAL "" )
                set( conan_options "${conan_options} --${arg_name_lower}" )
            else()
                set( conan_options "${conan_options} --${arg_name_lower}='${ARG_${arg_name}}'" )
            endif()
        endif()
    endforeach()

    # Handle multi-value arguments
    foreach( arg_name ${multivalues} )
        if( DEFINED ARG_${arg_name} )
            string( TOLOWER arg_name_lower ${arg_name} )
            string( REPLACE "_" "-" arg_name_lower ${arg_name_lower} )
            foreach( value ${ARG_${arg_name}} )
                if( ARG_${arg_name} STREQUAL "" )
                    set( conan_options "${conan_options} --${arg_name_lower}" )
                else()
                    set( conan_options "${conan_options} --${arg_name_lower}='${value}'" )
                endif()
            endforeach()
        endif()
    endforeach()

    # Add rest of arguments, if any
    if( DEFINED ARG_UNPARSED_ARGUMENTS )
        set( conan_options "${conan_options} ${ARG_UNPARSED_ARGUMENTS}" )
    endif()

    # Make it all into a command line
    set( cmdline COMMAND ${CONAN_CMD} ${conan_options} )

    # Execute the command
    message( STATUS "Running: ${cmdline}" )
    execute_process( ${cmdline}
                     RESULT_VARIABLE conan_result
                     OUTPUT_VARIABLE conan_output
                     ERROR_VARIABLE  conan_error
                     WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                     )

    message( "${conan_output}" )

    # Print error messages, unless caller takes care of them
    if( DEFINED EXEC_ARG_ERROR_VARIABLE )
        set( ${EXEC_ARG_ERROR_VARIABLE} "${conan_error}" PARENT_SCOPE )
    else()
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
        "NO_IMPORTS UPDATE"
        "INSTALL_FOLDER MANIFESTS MANIFESTS_INTERACTIVE VERIFY JSON REMOTE"
        "set( parse_multivalues GENERATOR BUILD ENV OPTIONS PROFILE SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_rm )
    conan_execute( "config rm"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_set )
    conan_execute( "config set"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_get )
    conan_execute( "config get"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_config_install )
    conan_execute( "config install"
        ""
        "VERIFY_SSL TYPE ARGS"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_get )
    conan_execute( get
        "RAW"
        "PACKAGE REMOTE"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_info )
    conan_execute( info
        "PATHS UPDATE"
        "BUILD_ORDER GRAPH INSTALL_FOLDER JSON PACKAGE_FILTER DRY_BUILD PROFILE REMOTE"
        "ONLY ENV OPTIONS SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_search )
    conan_execute( search
        "OUTDATED CASE_SENSITIVE RAW"
        "QUERY REMOTE TABLE JSON"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_new )
    conan_execute( new
        "TEST HEADER PURE_C SOURCES BARE CI_SHARED CI_TRAVIS_GCC CI_TRAVIS_CLANG CI_TRAVIS_OSX CI_APPVEYOR_WIN CI_GITLAB_GCC CI_GITLAB_CLANG CI_CIRCLECI_GCC CI_CIRCLECI_CLANG CI_CIRCLECI_OSX GITIGNORE"
        "CI_UPLOAD_URL"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_create )
    conan_execute( create
        "KEEP_SOURCE KEEP_BUILD NOT_EXPORT UPDATE"
        "JSON TEST_BUILD_FOLDER TEST_FOLDER MANIFESTS MANIFESTS_INTERACTIVE VERIFY BUILD PROFILE REMOTE"
        "ENV OPTIONS SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_upload )
    conan_execute( upload
        "ALL SKIP_UPLOAD FORCE CHECK CONFIRM"
        "PACKAGE QUERY REMOTE RETRY RETRY_WAIT NO_OVERWRITE JSON"
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
        "BUILD_FOLDER INSTALL_FOLDER PROFILE PACKAGE_FOLDER SOURCE_FOLDER JSON"
        "ENV OPTIONS SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_test )
    conan_execute( test
        "UPDATE"
        "TEST_BUILD_FOLDER BUILD PROFILE REMOTE"
        "ENV OPTIONS SETTINGS"
        ${ARGN}
    )
endfunction()

function( conan_cmd_source )
    conan_execute( source
        ""
        "SOURCE_FOLDER INSTALL_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_build )
    conan_execute( build
        "BUILD CONFIGURE INSTALL TEST"
        "BUILD_FOLDER INSTALL_FOLDER PACKAGE_FOLDER SOURCE_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_package )
    conan_execute( package
        ""
        "BUILD_FOLDER INSTALL_FOLDER PACKAGE_FOLDER SOURCE_FOLDER"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_list )
    conan_execute( "profile list"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_show )
    conan_execute( "profile show"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_new )
    conan_execute( "profile new"
        "DETECT"
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_update )
    conan_execute( "profile update"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_get )
    conan_execute( "profile get"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_profile_remove )
    conan_execute( "profile remove"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_list )
    conan_execute( "remote list"
        "RAW"
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_add )
    conan_execute( "remote add"
        "FORCE"
        "INSERT"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_remove )
    conan_execute( "remote remove"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_update )
    conan_execute( "remote update"
        ""
        "INSERT"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_rename )
    conan_execute( "remote rename"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_list_ref )
    conan_execute( "remote list_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_add_ref )
    conan_execute( "remote add_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_remove_ref )
    conan_execute( "remote remove_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_update_ref )
    conan_execute( "remote update_ref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_list_pref )
    conan_execute( "remote list_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_add_pref )
    conan_execute( "remote add_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_remove_pref )
    conan_execute( "remote remove_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_update_pref )
    conan_execute( "remote update_pref"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_remote_clean )
    conan_execute( "remote clean"
        ""
        ""
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_user )
    conan_execute( user
        "CLEAN"
        "PASSWORD REMOTE JSON"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_imports )
    conan_execute( imports
        "UNDO"
        "INSTALL_FOLDER IMPORT_FOLDER"
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
        "FORCE OUTDATED SRC LOCKS"
        "BUILDS PACKAGES QUERY REMOTE"
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
        "PACKAGE REMOTE"
        ""
        ${ARGN}
    )
endfunction()

function( conan_cmd_inspect )
    conan_execute( inspect
        ""
        "REMOTE JSON"
        "ATTRIBUTE"
        ${ARGN}
    )
endfunction()

