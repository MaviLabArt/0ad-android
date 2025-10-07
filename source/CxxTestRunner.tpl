// vim: set filetype=cpp :

#include <cxxtest/ErrorPrinter.h>
#include <cxxtest/XmlPrinter.h>

#include <ps/DllLoader.h>
#include <cstring>
#include <iostream>
#include <string>


void usage(const char* prog) {
	const std::string help = std::string("Usage: ") + prog  + R"( [options]

--libdir    dir             Where to find extra shared libraries, used for running tests in staging area
--format    junit|simple    simple: default, good for cli - junit: for use by CI
--output    file            File to write to, defaults to stdout
--help                      This message
)";
	std::printf("%s\n", help.c_str());
}

int main(int argc, char **argv)
{

	bool xml = false;
	std::ostream* output = &std::cout;
    std::ofstream out;

	for (int i = 1; i < argc; ++i)
	{
		if (std::strcmp(argv[i], "--libdir") == 0)
		{
			if (++i >= argc)
			{
				std::printf("Option libdir requires an optarg\n\n");
				usage(argv[0]);
				std::exit(1);
			}

			DllLoader::OverrideLibdir(argv[i]);
		}
		else if (std::strcmp(argv[i], "--format") == 0)
		{
			if (++i >= argc)
			{
				std::printf("Option format requires an optarg\n\n");
				usage(argv[0]);
				std::exit(1);
			}

			if (std::strcmp(argv[i], "junit") == 0)
				xml  = true;
			else if (std::strcmp(argv[i], "simple") == 0)
				xml = false;
			else
			{
				std::printf("Unkown format: %s\n\n", argv[i]);
				usage(argv[0]);
				std::exit(1);
			}
		}

		else if (std::strcmp(argv[i], "--output") == 0)
		{
			if (++i >= argc)
			{
				std::printf("Option output requires an optarg\n\n");
				usage(argv[0]);
				std::exit(1);
			}

			out.open(argv[i]);
			output = &out;
		}
		else if (std::strcmp(argv[i], "--help") == 0)
		{
			usage(argv[0]);
			std::exit(0);
		}
		else
		{
			std::printf("Unkown argument: %s\n\n", argv[i]);
			usage(argv[0]);
			std::exit(1);
		}
	}

	if (xml)
		return CxxTest::XmlPrinter(*output).run();

	return CxxTest::ErrorPrinter(*output).run();
}

// The CxxTest "world"
<CxxTest world>
