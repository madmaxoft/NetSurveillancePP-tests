# Test hashing known values:
add_executable(00-SofiaHash 00-SofiaHash.cpp)
target_link_libraries(00-SofiaHash PRIVATE NetSurveillancePp-static)
add_test(
	NAME 00-SofiaHash-test
	COMMAND 00-SofiaHash
)





# Test connecting to a localhost simulator:
add_executable(01-ConnectAndLogin 01-ConnectAndLogin.cpp)
target_link_libraries(01-ConnectAndLogin PRIVATE NetSurveillancePp-static)
target_compile_features(01-ConnectAndLogin PRIVATE cxx_std_20)
add_test(
	NAME 01-ConnectAndLogin-test-goodlogin
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:01-ConnectAndLogin> localhost goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
add_test(
	NAME 01-ConnectAndLogin-test-badlogin
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua --expect-failure $<TARGET_FILE:01-ConnectAndLogin> localhost goodUser badPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
