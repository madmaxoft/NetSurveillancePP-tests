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
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:01-ConnectAndLogin> localhost 34567 goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
add_test(
	NAME 01-ConnectAndLogin-test-badlogin
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua --expect-failure $<TARGET_FILE:01-ConnectAndLogin> localhost 34567 goodUser badPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(01-ConnectAndLogin PROPERTIES FOLDER "Tests")




# Test enumerating channel names against a localhost simulator:
add_executable(02-EnumChannelNames 02-EnumChannelNames.cpp)
target_link_libraries(02-EnumChannelNames PRIVATE NetSurveillancePp-static)
add_test(
	NAME 02-EnumChannelNames-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:02-EnumChannelNames> localhost 34567 goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(02-EnumChannelNames PROPERTIES FOLDER "Tests")





# Test receiving a picture:
add_executable(03-CapturePicture 03-CapturePicture.cpp)
target_link_libraries(03-CapturePicture PRIVATE NetSurveillancePp-static)
add_test(
	NAME 03-CapturePicture-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:03-CapturePicture> localhost 34567 goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(03-CapturePicture PROPERTIES FOLDER "Tests")





# Test monitoring alarms:
add_executable(04-MonitorAlarms 04-MonitorAlarms.cpp)
target_link_libraries(04-MonitorAlarms PRIVATE NetSurveillancePp-static)
add_test(
	NAME 04-MonitorAlarms-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:04-MonitorAlarms> localhost 34567 goodUser goodPassword 2
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(04-MonitorAlarms PROPERTIES FOLDER "Tests")





# Test receiving config:
add_executable(05-ReceiveConfig 05-ReceiveConfig.cpp)
target_link_libraries(05-ReceiveConfig PRIVATE NetSurveillancePp-static)
add_test(
	NAME 05-ReceiveConfig-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:05-ReceiveConfig> localhost 34567 goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(05-ReceiveConfig PROPERTIES FOLDER "Tests")





# Test receiving SysInfo:
add_executable(06-ReceiveSysInfo 06-ReceiveSysInfo.cpp)
target_link_libraries(06-ReceiveSysInfo PRIVATE NetSurveillancePp-static)
add_test(
	NAME 06-ReceiveSysInfo-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:06-ReceiveSysInfo> localhost 34567 goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(06-ReceiveSysInfo PROPERTIES FOLDER "Tests")





# Test receiving Ability:
add_executable(07-ReceiveAbility 07-ReceiveAbility.cpp)
target_link_libraries(07-ReceiveAbility PRIVATE NetSurveillancePp-static)
add_test(
	NAME 07-ReceiveAbiliy-test
	COMMAND lua ${CMAKE_CURRENT_SOURCE_DIR}/SimpleSimulatorDriver.lua $<TARGET_FILE:07-ReceiveAbility> localhost 34567 goodUser goodPassword
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(07-ReceiveAbility PROPERTIES FOLDER "Tests")





# Test parsing the raw captured video (from R15 real device test or test-09):
add_executable(08-ParseRawCapturedStream 08-ParseRawCapturedStream.cpp)
target_link_libraries(08-ParseRawCapturedStream PRIVATE NetSurveillancePp-static)
add_test(
	NAME 08-ParseRawCapturedStream-test
	COMMAND $<TARGET_FILE:08-ParseRawCapturedStream> R15-out.raw
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(08-ParseRawCapturedStream PROPERTIES FOLDER "Tests")





# Test capturing the raw captured video (same as R15 real device test):
add_executable(09-SaveCapturedStreamRaw 09-SaveCapturedStreamRaw.cpp)
target_link_libraries(09-SaveCapturedStreamRaw PRIVATE NetSurveillancePp-static)
set_target_properties(09-SaveCapturedStreamRaw PROPERTIES FOLDER "Tests")





# Test downloading a remote playback file (same as R16 real device test):
add_executable(10-SaveRemotePlaybackRaw 10-SaveRemotePlaybackRaw.cpp)
target_link_libraries(10-SaveRemotePlaybackRaw PRIVATE NetSurveillancePp-static)
set_target_properties(10-SaveRemotePlaybackRaw PROPERTIES FOLDER "Tests")





# A gateway that claims a live video stream, strips the CapturedStream wrapper and provides the raw video
# data in a local TCP server. This can be the played back using e.g. "ffplay tcp://localhost:<port>"
add_executable(ChannelLiveVideoTcpGateway ChannelLiveVideoTcpGateway.cpp)
target_link_libraries(ChannelLiveVideoTcpGateway PRIVATE NetSurveillancePp-static)
set_target_properties(ChannelLiveVideoTcpGateway PROPERTIES FOLDER "Tools")
