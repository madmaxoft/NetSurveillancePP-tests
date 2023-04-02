# Test hashing known values:
add_executable(00-SofiaHash 00-SofiaHash.cpp)
target_link_libraries(00-SofiaHash PRIVATE NetSurveillancePp-static)
add_test(
	NAME 00-SofiaHash-test
	COMMAND 00-SofiaHash
)
set_target_properties(00-SofiaHash PROPERTIES FOLDER "Tests")





# Test connecting to a localhost simulator:
add_executable(01-ConnectAndLogin 01-ConnectAndLogin.cpp)
target_link_libraries(01-ConnectAndLogin PRIVATE NetSurveillancePp-static)
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
set_target_properties(01-ConnectAndLogin PROPERTIES FOLDER "Tests")




# Test enumerating channel names against a localhost simulator:
add_executable(02-EnumChannelNames 02-EnumChannelNames.cpp)
target_link_libraries(02-EnumChannelNames PRIVATE NetSurveillancePp-static)
add_test(
	NAME 02-EnumChannelNames-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:02-EnumChannelNames> localhost goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(02-EnumChannelNames PROPERTIES FOLDER "Tests")





# Test receiving a picture:
add_executable(03-CapturePicture 03-CapturePicture.cpp)
target_link_libraries(03-CapturePicture PRIVATE NetSurveillancePp-static)
add_test(
	NAME 03-CapturePicture-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:03-CapturePicture> localhost goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(03-CapturePicture PROPERTIES FOLDER "Tests")





# Test receiving alarms:
add_executable(04-MonitorAlarms 04-MonitorAlarms.cpp)
target_link_libraries(04-MonitorAlarms PRIVATE NetSurveillancePp-static)
add_test(
	NAME 04-MonitorAlarms-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:04-MonitorAlarms> localhost goodUser goodPassword 2
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(04-MonitorAlarms PROPERTIES FOLDER "Tests")
