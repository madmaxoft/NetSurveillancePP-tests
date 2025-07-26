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

/** The channel for which to request the video stream. */
int gChannel = 0;

/** Number of video packets to capture. */
int gNumPackets = 20;

/** The output file, opened for writing. */
FILE * gOutFile = nullptr;





static void onVideoData(const std::error_code & aError, const void * aData, size_t aSize)
{
	if (aError)
	{
		std::cerr << "Error: " << aError.message() << "\n";
		gResult = 2;
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.notify_all();
	}
	else
	{
		static int numPacketsReceived = 0;
		std::cout << fmt::format("Video data packet received: {} bytes\n", aSize);
		fwrite(aData, 1, aSize, gOutFile);
		if (numPacketsReceived++ > gNumPackets)
		{
			std::cout << "Received all packets, quitting.\n";
			std::unique_lock<std::mutex> lg(gMtxFinished);
			gCvFinished.notify_all();
		}
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
		std::cout << fmt::format("Logged in, requesting {} packets from the video stream from channel {}...\n", gNumPackets, gChannel);
		aRecorder->receiveLiveVideo(&onVideoData, gChannel);
	}
}





/** This test program connects to the NVR specified on the commandline and dumps the specified number
of live-video packets into an output file.
Command-line parameters:
	1. NVR hostname
	2. NVR port
	3. NVR username
	4. NVR password
	5. Channel to capture
	6. Output file name
	7. Number of packets to dump
*/
int main(int aArgC, char * aArgV[])
{
	// Parse the cmdline arguments:
	auto hostName        = (aArgC < 2) ? "localhost" : aArgV[1];
	auto portStr         = (aArgC < 3) ? "34567" : aArgV[2];
	auto userName        = (aArgC < 4) ? "builtinUser" : aArgV[3];
	auto password        = (aArgC < 5) ? "builtinPassword" : aArgV[4];
	gChannel             = (aArgC < 6) ? 0 : std::atoi(aArgV[5]);
	std::string outFNam  = (aArgC < 7) ? "09-out.raw" : aArgV[6];
	gNumPackets          = (aArgC < 8) ? 20 : std::atoi(aArgV[7]);
	auto port = std::atoi(portStr);
	if (port == 0)
	{
		std::cerr << "Cannot parse port, using default 34567 instead\n";
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
	std::cout << "Connecting to " << hostName << " : " << port << " using credentials " << userName << " / " << password << "...\n";
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
