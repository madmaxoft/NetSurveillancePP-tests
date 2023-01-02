cmake_minimum_required(VERSION 3.1 FATAL_ERROR)

project(NetSurveillancePp-Tests LANGUAGES CXX)





# Enable generating the tests from CMake:
enable_testing()
list(APPEND CMAKE_CTEST_ARGUMENTS "--output-on-failure")





# Set the minimum Windows SDK target to Windows XP
if(WIN32)
	add_definitions(-D_WIN32_WINNT=0x0601)
endif()





# Pull in all the libraries used:
add_subdirectory(Lib)

# Add all the tests:
add_subdirectory(Tests)
