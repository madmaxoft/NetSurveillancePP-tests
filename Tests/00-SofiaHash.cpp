#include <stdexcept>
#include <iostream>
#include "SofiaHash.hpp"





static void testHash(const std::string & aOrigText, const std::string & aExpectedHash)
{
	auto hash = NetSurveillancePp::sofiaHash(aOrigText);
	if (hash != aExpectedHash)
	{
		throw std::runtime_error(aOrigText);
	}
}





/** This test program has a dual purpose:
- it checks the NetSurveillancePp::sofiaHash() function against known hashes
- it can hash any string (provided as the first commandline parameter) */
int main(int aArgC, char * aArgV[])
{
	// If there is a commandline param, output the hash to stdout and exit:
	if (aArgC > 1)
	{
		std::cout << NetSurveillancePp::sofiaHash(aArgV[1]) << "\n";
		return 0;
	}

	// If there are no commandline params, check the hashes of known values:
	try
	{
		testHash("admin",    "6QNMIQGe");
		testHash("test",     "S2fGqNFs");
		testHash("",         "tlJwpbo6");
		testHash("password", "mF95aD4o");
		testHash("bla",      "ahX6WENC");

		std::cout << "All ok";
		return 0;
	}
	catch (const std::exception & exc)
	{
		std::cerr << "Test failed: " << exc.what();
		return 1;
	}
}