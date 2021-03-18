#include "tiny.hpp"
#include <iostream>
#include <fstream>
#include <regex>

int main(int argc, const char *argv[])
{
	// Checking CLI input
	if (argc != 2) {
		std::cout << "Usage: tinyscan <INPUT>.tny" << std::endl;
		return -1;
	}
	// Extract filename of input using regex
	std::regex reg("^(.*)\\.tny$");
	std::smatch m;
	std::string if_name(argv[1]);
	if (!std::regex_search(if_name, m, reg)) {
		std::cout << "Invalid input file: " << argv[1] << std::endl;
		return -1;
	}
	// Open file streams
	std::string of_name = m.str(1) + ".txt";
	std::cout << std::endl << "Writing result to: " << of_name  << "..." << std::endl << std::endl;
	std::ifstream ifs(argv[1]);
	std::ofstream ofs(of_name);
	// Start scanning
	ofs << "TINY COMPILATION:" << std::endl;
	std::string line;
	std::size_t count = 0;
	tcc::lexer lex;
	bool next = true;
	while (std::getline(ifs, line)) {
		line += '\n';
		++count;
		ofs << "\t" << count << ": " << line << std::flush;
		for (std::size_t i = 0; i < line.size();) {
			// Read next
			auto s = lex.read_next(line[i], next);
			if (!next)
				next = true;
			if (lex.error_state()) {
				ofs << "\t\t" << count << ": ERROR: " << lex.get_buffer() << std::endl;
				std::cout << "In line " << lex.get_line() + 1 << ": " << lex.get_error() << std::endl;
				for (char &ch : line) if (ch == '\t') ch = ' ';
				std::cout << line << std::flush;
				std::cout << std::string(lex.get_pos() - 1, ' ') << "^" << std::endl << std::endl;
				lex.reset_status();
			}
			else if (s == tcc::lexer::state::output) {
				ofs << "\t\t" << count << ": " << lex.get_output()->to_string() << std::endl;
				next = false;
				continue;
			}
			++i;
		}
	}
	ofs << "\t" << ++count << ": EOF" << std::flush;
	return 0;
}