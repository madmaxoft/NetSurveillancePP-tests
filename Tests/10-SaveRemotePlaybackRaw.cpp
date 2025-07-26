#include "fmt/format.h"
#define _CRT_SECURE_NO_WARNINGS 1
#include <mutex>
#include <atomic>
#include <iostream>
#include "Recorder.hpp"





using namespace NetSurveillancePp;






std::mutex gMtxFinished;
std::condition_variable gCvFinished;
std::atomic_int gResult(0);

/** Number of video packets to capture. */
int gNumPackets = 20;

/** The output file, opened for writing. */
FILE * gOutFile = nullptr;

/** The timestamp of the video start. */
time_t gStartTime;

/** The name of the remote file to play back. */
std::string gRemoteFileName;

/** The default gStartTime. 2025-07-25 12:00:00 (Use R16 to easily find a different value; watch out for timezone offset!). */
static constexpr time_t cDefaultStartTime = 1753444800;

/** The default gRemoteFileName (Use R14 to easily find a different value). */
static const char * cDefaultRemoteFileName = "/idea0/2025-07-25/001/12.00.00-12.37.37[R][@104b0a][0].h264";






static void onVideoData(const std::error_code & aError, const void * aData, size_t aSize)
{
	if (aError)
	{
		std::cerr << "Error: " << aError.message() << std::endl;
		gResult = 2;
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.notify_all();
		return;
	}
	if (gOutFile == nullptr)
	{
		// Already closed the file, ignore any further data
		return;
	}

	static int numPacketsReceived = 1;
	std::cout << fmt::format(FMT_STRING("Video data packet {} received: {} bytes"), numPacketsReceived, aSize) << std::endl;
	fwrite(aData, 1, aSize, gOutFile);
	if (++numPacketsReceived > gNumPackets)
	{
		std::cout << "Received all packets, quitting." << std::endl;
		fclose(gOutFile);
		gOutFile = nullptr;
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.notify_all();
	}
}





static void onLoginFinished(std::shared_ptr<Recorder> aRecorder, const std::error_code & aError)
{
	if (aError)
	{
		std::cerr << "Error: " << aError.message() << "\n";
		gResult = 1;
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.notify_all();
	}
	else
	{
		std::cout << fmt::format(
			FMT_STRING("Logged in, requesting {} packets from the remote playback video stream from file {} from timestamp {} ({})..."),
			gNumPackets, gRemoteFileName, gStartTime, Recorder::formatTimeStamp(gStartTime)
		) << std::endl;
		aRecorder->receiveRemotePlayback(&onVideoData, gStartTime, gStartTime + 60 * 60, gRemoteFileName);
	}
}





/** This test program connects to the NVR specified on the commandline and dumps the specified number
of remote playback packets into an output file.
Command-line parameters:
	1. NVR hostname
	2. NVR port
	3. NVR username
	4. NVR password
	5. Output file name
	6. Number of packets to dump
	7. Start time (UNIXtime)
	8. Remote file name
*/
int main(int aArgC, char * aArgV[])
{
	// Parse the cmdline arguments:
	auto hostName        = (aArgC < 2) ? "localhost" : aArgV[1];
	auto portStr         = (aArgC < 3) ? "34567" : aArgV[2];
	auto userName        = (aArgC < 4) ? "builtinUser" : aArgV[3];
	auto password        = (aArgC < 5) ? "builtinPassword" : aArgV[4];
	std::string outFNam  = (aArgC < 6) ? "10-out.raw" : aArgV[5];
	gNumPackets          = (aArgC < 7) ? 200 : std::atoi(aArgV[6]);
	gStartTime           = (aArgC < 8) ? cDefaultStartTime : std::atoi(aArgV[7]);
	gRemoteFileName      = (aArgC < 9) ? cDefaultRemoteFileName : aArgV[8];
	auto port = std::atoi(portStr);
	if (port == 0)
	{
		std::cerr << "Cannot parse port, using default 34567 instead" << std::endl;
		port = 34567;
	}

	// Open the output file:
	gOutFile = fopen(outFNam.c_str(), "wb");
	if (gOutFile == nullptr)
	{
		std::cerr << "Cannot open output file " << outFNam << std::endl;
		return 1;
	}

	// Dump the video stream:
	std::cout << "Connecting to " << hostName << " : " << port << " using credentials " << userName << " / " << password << "..." << std::endl;
	auto rec = Recorder::create();
	rec->connectAndLogin(hostName, port, userName, password,
		[rec](const std::error_code & aError)
		{
			onLoginFinished(rec, aError);
		}
	);

	// Wait for completion:
	{
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.wait(lg);
	}

	return gResult.load();
}
