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

/** Number of alarms to be received before exiting.
If set to -1 (default when no cmdline params), doesn't abort based on number of received alarms. */
int gNumAlarmsLeft;




static void onAlarm(
	const std::error_code & aError,
	int aChannel,
	bool aIsStart,
	const std::string & aEventType,
	const nlohmann::json & aWholeJson
)
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
		std::cout << fmt::format("Alarm received: Channel {}, IsStart: {}, EventType: {}\n", aChannel, aIsStart ? "true" : "false", aEventType);
		if (gNumAlarmsLeft > 0)
		{
			gNumAlarmsLeft -= 1;
			if (gNumAlarmsLeft == 0)
			{
				gResult = 0;
				std::unique_lock<std::mutex> lg(gMtxFinished);
				gCvFinished.notify_all();
			}
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
		std::cout << "Logged in, monitoring alarms...\n";
		aRecorder->monitorAlarms(&onAlarm);
	}
}





int main(int aArgC, char * aArgV[])
{
	const char * hostName = (aArgC < 2) ? "localhost" : aArgV[1];
	const char * userName = (aArgC < 3) ? "builtinUser" : aArgV[2];
	const char * password = (aArgC < 4) ? "builtingPassword" : aArgV[3];
	gNumAlarmsLeft = (aArgC < 5) ? -1 : std::atoi(aArgV[4]);
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
