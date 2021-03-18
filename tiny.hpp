#pragma once

#include <string>
#include <vector>

namespace tcc {
	enum class action_type {
		_null, _if, _then, _else, _repeat, _until, _end,
		_read, _write
	};

	enum class signal_type {
		_null, _expect, _add, _sub, _mul, _div, _cmp, _les, _lbr, _rbr, _sem, _asi
	};

	enum class token_type {
		_null, _action, _signal, _literal, _identifier
	};

	enum class literal_type {
		_null, _number
	};

	action_type get_action(const std::string &);

	signal_type get_signal(const std::string &);

	class token_base {
		std::size_t _line = 0, _pos = 0;
	public:
		token_base() = default;
		token_base(std::size_t l, std::size_t p) : _line(l), _pos(p) {}
		virtual ~token_base() = default;
		virtual token_type get_type() const noexcept
		{
			return token_type::_null;
		}
		virtual std::string to_string() const = 0;
		inline std::size_t get_line() const noexcept
		{
			return _line;
		}
		inline std::size_t get_pos() const noexcept
		{
			return _pos;
		}
	};

	class token_action final : public token_base {
		action_type _type = action_type::_null;
	public:
		token_action(action_type t, std::size_t l, std::size_t p) : token_base(l, p), _type(t) {}
		std::string to_string() const override
		{
			switch (_type) {
			case action_type::_if:
				return "reserved word: if";
			case action_type::_then:
				return "reserved word: then";
			case action_type::_else:
				return "reserved word: else";
			case action_type::_repeat:
				return "reserved word: repeat";
			case action_type::_until:
				return "reserved word: until";
			case action_type::_end:
				return "reserved word: end";
			case action_type::_read:
				return "reserved word: read";
			case action_type::_write:
				return "reserved word: write";
			}
		}
		token_type get_type() const noexcept override
		{
			return token_type::_action;
		}
		inline action_type get_action() const noexcept
		{
			return _type;
		}
	};

	class token_signal final : public token_base {
		signal_type _type = signal_type::_null;
	public:
		token_signal(signal_type t, std::size_t l, std::size_t p) : token_base(l, p), _type(t) {}
		std::string to_string() const override
		{
			switch (_type) {
			case signal_type::_add:
				return "+";
			case signal_type::_sub:
				return "-";
			case signal_type::_mul:
				return "*";
			case signal_type::_div:
				return "/";
			case signal_type::_cmp:
				return "=";
			case signal_type::_les:
				return "<";
			case signal_type::_lbr:
				return "(";
			case signal_type::_rbr:
				return ")";
			case signal_type::_sem:
				return ";";
			case signal_type::_asi:
				return ":=";
			}
		}
		token_type get_type() const noexcept override
		{
			return token_type::_signal;
		}
		inline signal_type get_signal() const noexcept
		{
			return _type;
		}
	};

	class token_literal final : public token_base {
		literal_type _type = literal_type::_number;
		std::string _lit;
	public:
		token_literal(literal_type t, std::string lit, std::size_t l, std::size_t p) : token_base(l, p), _type(t), _lit(std::move(lit)) {}
		token_type get_type() const noexcept override
		{
			return token_type::_literal;
		}
		std::string to_string() const override
		{
			return std::string("NUM, val = ") + _lit;
		}
		inline const std::string &get_literal() const noexcept
		{
			return _lit;
		}
		inline literal_type get_lit_type() const noexcept
		{
			return _type;
		}
	};

	class token_identifier final : public token_base {
		std::string _id;
	public:
		token_identifier(std::string id, std::size_t l, std::size_t p) : token_base(l, p), _id(std::move(id)) {}
		token_type get_type() const noexcept override
		{
			return token_type::_identifier;
		}
		std::string to_string() const override
		{
			return std::string("ID, name = ") + _id;
		}
		inline const std::string &get_id() const noexcept
		{
			return _id;
		}
	};

	class lexer final {
		std::vector<token_base *> results;
		std::string last_buffer, buffer;
		std::size_t line = 0, pos = 0;
		token_base *result = nullptr;
	public:
		enum class state : unsigned char {
			unexpected_character = 0b1001, incomplete_signal = 0b1010, unexpected_signal = 0b1011,
			ready = 0b0000, output = 0b0001, incom = 0b0010, insig = 0b0011, inlit = 0b0100, inidn = 0b0101
		};
	private:
		state _s = state::ready;
	public:
		inline std::size_t get_line() const noexcept
		{
			return line;
		}
		inline std::size_t get_pos() const noexcept
		{
			return pos;
		}
		inline state get_state() const noexcept
		{
			return _s;
		}
		inline bool error_state() const noexcept
		{
			return (static_cast<unsigned char>(_s) & 0b1000) > 0;
		}
		inline const std::string &get_buffer() const noexcept
		{
			if (error_state() || _s == state::output)
				return last_buffer;
			else
				return buffer;
		}
		const char *get_error() const noexcept;
		void reset_status()
		{
			_s = state::ready;
			buffer.clear();
		}
		inline token_base * get_output() noexcept
		{
			if (_s == state::output)
				_s = state::ready;
			return results.back();
		}
		inline const std::vector<token_base *> & get_results() const noexcept
		{
			return results;
		}
		inline void clear_output() noexcept
		{
			results.clear();
		}
		state read_next(char, bool = true);
	};
}