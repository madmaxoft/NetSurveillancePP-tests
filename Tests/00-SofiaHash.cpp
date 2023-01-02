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





int main()
{
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