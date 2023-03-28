#define _CRT_SECURE_NO_WARNINGS 1
#include <mutex>
#include <atomic>
#include <iostream>
#include "Fmt/format.h"
#include "Recorder.hpp"
#include "Root.hpp"





using namespace NetSurveillancePp;






std::mutex gMtxFinished;
std::condition_variable gCvFinished;
std::atomic_int gResult(0);

/** The channel for which to request the picture. */
int gChannel = 0;





static void onPicture(const std::error_code & aError, const char * aData, size_t aSize)
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
		std::cout << fmt::format("Picture received: {} bytes\n", aSize);
		std::cout << "Saving to file pic.jpg...";
		FILE * f = fopen("pic.jpg", "wb");
		if (f == nullptr)
		{
			std::cout << "\nFailed to open file.\n";
			gResult = 3;
		}
		else
		{
			fwrite(aData, 1, aSize, f);
			fclose(f);
			std::cout << "\nDone.\n";
			gResult = 0;
		}
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
		std::cout << fmt::format("Logged in, requesting a picture from channel {}...\n", gChannel);
		aRecorder->capturePicture(gChannel, &onPicture);
	}
}





int main(int aArgc, char * aArgv[])
{
	const char * hostName = (aArgc < 2) ? "localhost" : aArgv[1];
	const char * userName = (aArgc < 3) ? "builtinUser" : aArgv[2];
	const char * password = (aArgc < 4) ? "builtingPassword" : aArgv[3];
	gChannel = (aArgc < 5) ? 0 : std::atoi(aArgv[4]);
	std::cout << "Connecting to " << hostName << " using credentials " << userName << " / " << password << "...\n";
	auto rec = Recorder::create();
	rec->connectAndLogin(hostName, 34567, userName, password, 
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