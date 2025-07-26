#include <mutex>
#include <iostream>
#include "CapturedStreamParser.hpp"
#include "Recorder.hpp"
#include "fmt/format.h"





using namespace NetSurveillancePp;






/** The hostname of the NVR to connect to. */
std::string gNvrHostName;

/** The port on NVR to connect to. */
int gNvrPort;

/** The username to use as login for the NVR. */
std::string gNvrUserName;

/** The password to use as login for the NVR. */
std::string gNvrPassword;

/** The channel for which to request the video stream. */
int gNvrChannel = 0;





void relayOnSocket(asio::ip::tcp::socket & aLocalSocket)
{
	std::cout << "Client connected: " << aLocalSocket.remote_endpoint() << std::endl;
	auto onVideoFrame = [&aLocalSocket](const void * aData, size_t aSize)
	{
		if (aSize > 0)
		{
			asio::write(aLocalSocket, asio::const_buffer(aData, aSize));
		}
	};

	std::mutex mtxFinished;
	std::condition_variable cvFinished;
	NetSurveillancePp::CapturedStreamParser csp(onVideoFrame, onVideoFrame);
	auto rec = Recorder::create();
	Recorder::ICapturedStreamReceiverPtr csr;
	rec->connectAndLogin(gNvrHostName, gNvrPort, gNvrUserName, gNvrPassword,
		[&](const std::error_code & aError)
		{
			if (aError)
			{
				std::cerr << "Error while connecting to NVR: " << aError.message() << std::endl;
				std::unique_lock<std::mutex> lg(mtxFinished);
				cvFinished.notify_all();
				return;
			}
			std::cout << "Connected and logged into NVR. Requesting video data" << std::endl;
			csr = rec->receiveLiveVideo(
				[&](const std::error_code & aError, const void * aData, size_t aSize)
				{
					if (aError)
					{
						std::cerr << "Error while receiving CapturedStream data: " << aError.message() << std::endl;
						std::unique_lock<std::mutex> lg(mtxFinished);
						cvFinished.notify_all();
						return;
					}
					try
					{
						csp.parse(aData, aSize);
					}
					catch (const std::exception & exc)
					{
						std::cerr << " Parsing CapturedStream failed: " << exc.what() << std::endl;
						auto csrCapture = csr;
						if (csrCapture != nullptr)
						{
							std::cerr << "Closing CapturedStreamReceiver." << std::endl;
							csrCapture->close();
						}
						std::unique_lock<std::mutex> lg(mtxFinished);
						cvFinished.notify_all();
						return;
					}
				},
				gNvrChannel
			);
		}
	);

	// Wait for completion:
	{
		std::unique_lock<std::mutex> lg(mtxFinished);
		cvFinished.wait(lg);
	}
}





/** The commandline params indicate the NVR to use, the credentials and the channel number;
lastly, the local TCP port on which to listen (34570 + channel by default). */
int main(int aArgC, char * aArgV[])
{
	gNvrHostName    = (aArgC < 2) ? "localhost" : aArgV[1];
	auto nvrPortStr = (aArgC < 3) ? "34567" : aArgV[2];
	gNvrUserName    = (aArgC < 4) ? "builtinUser" : aArgV[3];
	gNvrPassword    = (aArgC < 5) ? "builtinPassword" : aArgV[4];
	gNvrChannel     = (aArgC < 6) ? 0 : std::atoi(aArgV[5]);
	gNvrPort = std::atoi(nvrPortStr);
	if (gNvrPort == 0)
	{
		std::cerr << "Cannot parse remote port, using default 34567 instead\n";
		gNvrPort = 34567;
	}
	auto localPort = (aArgC < 7) ? (34570 + gNvrChannel) : std::atoi(aArgV[6]);
	std::cout << "Will connect to " << gNvrHostName << " : " << gNvrPort << " using credentials " << gNvrUserName << " / " << gNvrPassword << "..." << std::endl;

	try
	{
		asio::io_context ctx;
		asio::ip::tcp::acceptor acceptor(ctx, asio::ip::tcp::endpoint(asio::ip::tcp::v4(), localPort));
		std::cout << "Listening on port " << localPort << " for incoming connections...\n";
		while (true)
		{
			asio::ip::tcp::socket acceptedSocket(ctx);
			acceptor.accept(acceptedSocket);
			relayOnSocket(acceptedSocket);
		}
	}
	catch (const std::exception & exc)
	{
		std::cerr << "Exception: " << exc.what() << std::endl;
		return 1;
	}
}
