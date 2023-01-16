#include <mutex>
#include <atomic>
#include <iostream>
#include "Recorder.hpp"
#include "Root.hpp"





using namespace NetSurveillancePp;






std::mutex gMtxFinished;
std::condition_variable gCvFinished;
std::atomic_int gResult(0);





static void onChannelNames(const std::error_code & aError, const std::vector<std::string> & aChannelNames)
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
		std::cout << "Channel names retrieved:\n";
		for (const auto & chn: aChannelNames)
		{
			std::cout << "  " << chn << "\n";
		}
		gResult = 0;
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
		std::cout << "Logged in, enumerating channel names...\n";
		aRecorder->getChannelNames(&onChannelNames);
	}
}





int main(int aArgc, char * aArgv[])
{
	const char * hostName = (aArgc < 2) ? "localhost" : aArgv[1];
	const char * userName = (aArgc < 3) ? "builtinUser" : aArgv[2];
	const char * password = (aArgc < 4) ? "builtingPassword" : aArgv[3];
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