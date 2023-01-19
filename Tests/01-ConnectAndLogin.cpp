#include <mutex>
#include <atomic>
#include <iostream>
#include "Recorder.hpp"
#include "Root.hpp"





using namespace NetSurveillancePp;






std::mutex gMtxFinished;
std::condition_variable gCvFinished;
std::atomic_bool gIsSuccess(false);





void onFinished(const std::error_code & aError)
{
	if (aError)
	{
		std::cerr << "Error: " << aError.message() << "\n";
		gIsSuccess = false;
	}
	else
	{
		std::cout << "Finished.\n";
		gIsSuccess = true;
	}
	std::unique_lock<std::mutex> lg(gMtxFinished);
	gCvFinished.notify_all();
}





int main(int aArgc, char * aArgv[])
{
	const char * hostName = (aArgc < 2) ? "localhost" : aArgv[1];
	const char * userName = (aArgc < 3) ? "builtinUser" : aArgv[2];
	const char * password = (aArgc < 4) ? "builtinPassword" : aArgv[3];
	std::cout << "Connecting to " << hostName << " using credentials " << userName << " / " << password << "...\n";
	auto rec = Recorder::create();
	rec->connectAndLogin(hostName, 34567, userName, password, &onFinished);

	// Wait for completion:
	{
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.wait(lg);
	}

	if (!gIsSuccess)
	{
		return 1;
	}
	return 0;
}