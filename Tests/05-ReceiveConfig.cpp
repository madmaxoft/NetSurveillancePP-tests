#define _CRT_SECURE_NO_WARNINGS 1
#include <mutex>
#include <atomic>
#include <iostream>
#include "fmt/format.h"
#include "Recorder.hpp"
#include "Root.hpp"





using namespace NetSurveillancePp;






std::mutex gMtxFinished;
std::condition_variable gCvFinished;
std::atomic_int gResult(0);

/** The name of the config to request; specified via commandline. */
std::string gConfigName;





static void onConfig(
	const std::error_code & aError,
	const std::string & aConfigName,
	const nlohmann::json & aConfigData
)
{
	if (aError)
	{
		std::cerr << "Error: " << aError.message() << "\n";
		std::cerr << aConfigData.dump() << "\n";
		gResult = 2;
		std::unique_lock<std::mutex> lg(gMtxFinished);
		gCvFinished.notify_all();
	}
	else
	{
		std::cout << fmt::format("Config {} received: {}\n", aConfigName, aConfigData.dump());
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
		std::cout << fmt::format(FMT_STRING("Logged in, requesting config {}...\n"), gConfigName);
		aRecorder->getConfig(&onConfig, gConfigName);
	}
}





int main(int aArgC, char * aArgV[])
{
	auto hostName = (aArgC < 2) ? "localhost" : aArgV[1];
	auto portStr  = (aArgC < 3) ? "34567" : aArgV[2];
	auto userName = (aArgC < 4) ? "builtinUser" : aArgV[3];
	auto password = (aArgC < 5) ? "builtinPassword" : aArgV[4];
	gConfigName   = (aArgC < 6) ? "General.General" : aArgV[5];
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
