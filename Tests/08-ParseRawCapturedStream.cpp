#include "CapturedStreamParser.hpp"
#include <iostream>
#include <ostream>





/** The output file. */
FILE * gOut = nullptr;





/** Callback for video I-frame data. Save to output file. */
void cbVideoIFrame(const void * aData, size_t aSize)
{
	std::cout << "Got a video I frame, size " << aSize << std::endl;
	fwrite(aData, 1, aSize, gOut);
}





/** Callback for video P-frame data. Save to output file. */
void cbVideoPFrame(const void * aData, size_t aSize)
{
	std::cout << "Got a video P frame, size " << aSize << std::endl;
	fwrite(aData, 1, aSize, gOut);
}





/** This test program attempts to parse a raw CapturedStream (from R15 real device test), outputting only
the video frames to the output file.
The input file can be specified as the only param; defaults to "R15-out.raw" (as per R15's output).
The output file is created by appending a ".h265" suffix to the input file (no matter what actual
video format is used in the stream). */
int main(int argc, const char ** argv)
{
	const char * fileName = (argc > 1) ? argv[1] : "R15-out.raw";
	auto fIn = fopen(fileName, "rb");
	if (fIn == nullptr)
	{
		std::cerr << "Failed to open input file " << fileName << std::endl;
		return 1;
	}

	std::string fileNameOut(fileName);
	fileNameOut.append(".h265");
	gOut = fopen(fileNameOut.c_str(), "wb");
	if (gOut == nullptr)
	{
		std::cerr << "Failed to open output file " << fileNameOut << std::endl;
		return 1;
	}

	NetSurveillancePp::CapturedStreamParser parser(cbVideoIFrame, cbVideoPFrame);
	while (true)
	{
		char buf[512];
		auto numBytesRead = fread(buf, 1, sizeof(buf), fIn);
		if (numBytesRead == 0)
		{
			break;
		}
		try
		{
			parser.parse(buf, numBytesRead);
		}
		catch (const std::exception & exc)
		{
			std::cerr << "Exception while parsing: " << exc.what() << std::endl;
			return 2;
		}
	}
	if (parser.hasLeftoverData())
	{
		std::cerr << "Leftover data in the parser." << std::endl;
		return 3;
	}
	return 1;
}
