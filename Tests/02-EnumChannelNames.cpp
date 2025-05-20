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





int main(int aArgC, char * aArgV[])
{
	auto hostName = (aArgC < 2) ? "localhost" : aArgV[1];
	auto portStr  = (aArgC < 3) ? "34567" : aArgV[2];
	auto userName = (aArgC < 4) ? "builtinUser" : aArgV[3];
	auto password = (aArgC < 5) ? "builtinPassword" : aArgV[4];
	auto port = std::atoi(portStr);
	if (port == 0)
	{
		std::cerr << "Cannot parse port, using default 34567 instead";
		port = 34567;
	}
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
