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
	rec->connectAndLogin(hostName, port, userName, password, &onFinished);

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
