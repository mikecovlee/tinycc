#include "tiny.hpp"
#include <unordered_map>
#include <unordered_set>
#include <cctype>

namespace tcc {
	template<typename _kT, typename _vT> using map_t = std::unordered_map<_kT, _vT>;

	map_t<std::string, action_type> action_map = {
		{"if", action_type::_if},
		{"then", action_type::_then},
		{"else", action_type::_else},
		{"repeat", action_type::_repeat},
		{"until", action_type::_until},
		{"end", action_type::_end},
		{"read", action_type::_read},
		{"write", action_type::_write}
	};

	map_t<std::string, signal_type> signal_map = {
		{"+", signal_type::_add},
		{"-", signal_type::_sub},
		{"*", signal_type::_mul},
		{"/", signal_type::_div},
		{"=", signal_type::_cmp},
		{"<", signal_type::_les},
		{"(", signal_type::_lbr},
		{")", signal_type::_rbr},
		{";", signal_type::_sem},
		{":", signal_type::_expect},
		{":=", signal_type::_asi},
	};

	action_type get_action(const std::string &token)
	{
		if (action_map.count(token) > 0)
			return action_map.at(token);
		else
			return action_type::_null;
	}

	signal_type get_signal(const std::string &token)
	{
		if (signal_map.count(token) > 0)
			return signal_map.at(token);
		else
			return signal_type::_null;
	}

	std::unordered_set<char> signal_set = {
		'+', '-', '*', '/', '=', '<', '(', ')', ';', ':'
	};

	bool is_signal(char c)
	{
		return signal_set.count(c) > 0;
	}

	bool is_identifer(char c)
	{
		return std::isalnum(c) || c == '_';
	}

	map_t<lexer::state, std::string> error_map = {
		{lexer::state::unexpected_character, "未知输入字符"},
		{lexer::state::incomplete_signal, "不完整的符号"},
		{lexer::state::unexpected_signal, "未知符号"}
	};

	const char *lexer::get_error() const noexcept
	{
		if (error_map.count(_s) > 0)
			return error_map.at(_s).c_str();
		else
			return "无错误";
	}

	lexer::state lexer::read_next(char c, bool next)
	{
		if (next)
			++pos;
		switch (_s) {
		case state::ready: {
			if (c == '\0')
				return _s;
			else if (c == '\n') {
				++line;
				pos = 0;
				return _s;
			}
			else if (std::isspace(c))
				return _s;
			else if (c == '{')
				return _s = state::incom;
			else if (std::isdigit(c)) {
				buffer += c;
				return _s = state::inlit;
			}
			else if (is_signal(c)) {
				buffer += c;
				return _s = state::insig;
			}
			else if (is_identifer(c)) {
				buffer += c;
				return _s = state::inidn;
			}
			last_buffer.clear();
			last_buffer += c;
			return _s = state::unexpected_character;
		}
		case state::incom: {
			if (c == '\n') {
				++line;
				pos = 0;
				return _s;
			}
			else if (c == '}')
				return _s = state::ready;
			else
				return _s;
		}
		case state::insig: {
			if (!is_signal(c)) {
				auto sig = get_signal(buffer);
				last_buffer = buffer;
				buffer.clear();
				if (sig == signal_type::_expect)
					return _s = state::incomplete_signal;
				else if (sig == signal_type::_null)
					return _s = state::unexpected_signal;
				results.emplace_back(new token_signal(sig, line, pos - 1));
				return _s = state::output;
			}
			else {
				buffer += c;
				return _s;
			}
		}
		case state::inlit: {
			if (!std::isdigit(c)) {
				results.emplace_back(new token_literal(literal_type::_number, buffer, line, pos - 1));
				last_buffer = buffer;
				buffer.clear();
				return _s = state::output;
			}
			else {
				buffer += c;
				return _s;
			}
		}
		case state::inidn: {
			if (!is_identifer(c)) {
				auto act = get_action(buffer);
				if (act == action_type::_null)
					results.emplace_back(new token_identifier(buffer, line, pos - 1));
				else
					results.emplace_back(new token_action(act, line, pos - 1));
				last_buffer = buffer;
				buffer.clear();
				return _s = state::output;
			}
			else {
				buffer += c;
				return _s;
			}
		}
		}
	}
}