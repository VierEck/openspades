#pragma once

#include <string>

class VersionInfo {
public:
    static std::string GetOperatingSystem();
	static std::string GetVersionInfo() {
		std::string os = GetOperatingSystem();
		std::string version4spades = "  |  IV of Spades  " GIT_COMMIT_HASH;
		std::string git = " https://github.com/VierEck/openspades/tree/4";
		return os + version4spades + git;
	}
};
