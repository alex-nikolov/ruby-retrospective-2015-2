class Spreadsheet
  attr_accessor :table

  def initialize(table = nil)
    @table = Array.new

    @table = Parser.parse_table(table) unless table.nil? or table == ''
  end

  def empty?
    @table.empty?
  end

  def cell_at(call_index)
    unless Parser.correct_cell_index?(call_index)
      raise Spreadsheet::Error, "Invalid cell index '#{call_index}'"
    end

    cell = @table[Parser.row(call_index) - 1][Parser.column(call_index) - 1]

  rescue NoMethodError => e
    raise Spreadsheet::Error, "Cell '#{call_index}' does not exist"
  end

  def [](call_index)
    raw_cell = cell_at(call_index)

    if raw_cell != nil and raw_cell[0] == '='
      Error.new.unknown_function_error(raw_cell)
      Error.new.argument_number_error(raw_cell)
      Error.new.invalid_expression_error(raw_cell)
    end

    evaluate_cell_data(raw_cell)
  end

  def to_s
    evaluated_table = @table.map do |row|
      row.map { |cell| evaluate_cell_data(cell) }
    end

    evaluated_table.map { |row| row.join("\t") }.join("\n")
  end

  private

  def evaluate_cell_data(raw_cell)
    case raw_cell
      when /\A=#{Parser::NUMBER}\Z/ then Parser.evaluate_number(raw_cell)
      when /\A=#{Parser::CELL}\Z/ then evaluate_cell(raw_cell)
      when /\A#{Parser::FORMULA}\Z/ then evaluate_formula(raw_cell)
      else raw_cell
    end
  end

  def evaluate_formula(raw_cell)
    match, formula = Parser::FORMULA.match(raw_cell), /=(.*)\(/.match(raw_cell)

    arguments = Parser.extract_formula_arguments(match)
    arguments.map! { |argument| evaluate_cell_data(argument).to_f }
    accumulated = arguments.reduce do |memo, argument|
      Parser::FORMULA_TO_METHOD[formula[1]].to_proc.call(memo, argument)
    end
    accumulated % 1 == 0 ? accumulated.to_i.to_s : '%.2f' % accumulated
  end

  def evaluate_cell(raw_cell)
    reference_data = cell_at(raw_cell[1..-1]).dup

    if /\A#{Parser::NUMBER}\Z/.match reference_data
      reference_data.insert(0, '=')
    end
    evaluate_cell_data(reference_data)
  end

  class Error < Exception
    def unknown_function_error(formula)
      function_name = /=(.*)\(.*\)/.match formula

      return unless function_name

      if Parser::FORMULA_TO_METHOD[function_name[1]].nil?
        raise Spreadsheet::Error, "Unknown function '#{function_name[1]}'"
      end
    end

    def invalid_expression_error(formula)
      expression = formula[1..-1]

      number = Parser::NUMBER
      cell = Parser::CELL
      at_least_one = "(((#{number}|#{cell})(\s*,\s*))*(#{number}|#{cell}))"

      unless /\A[A-Z]+\(#{at_least_one}\)\Z/.match expression
        raise Spreadsheet::Error, "Invalid expression '#{expression}'"
      end
    end

    def argument_number_error(formula)
      function_name = /=(.*)\(/.match formula
      arguments = (/\((.*)\)/.match formula).to_s.split(',')
      arguments_size = arguments == ["()"] ? 0 : arguments.size

      return unless function_name

      check_for_argument_number_error(function_name[1], arguments_size)
    end

    private

    def check_for_argument_number_error(function_name, argument_size)
      case function_name
        when 'ADD', 'MULTIPLY'
          argument_size_error('<', argument_size, function_name)
        when 'SUBTRACT', 'MOD', 'DIVIDE'
          argument_size_error('!=', argument_size, function_name)
      end
    end

    def argument_size_error(operation, argument_size, function_name)
      message_start = "Wrong number of arguments for '#{function_name}': "
      error_condition = operation.to_sym.to_proc.call(argument_size, 2)

      case operation
        when '<' then message_end = "expected at least 2, got #{argument_size}"
        when '!=' then message_end = "expected 2, got #{argument_size}"
      end

      raise Spreadsheet::Error, message_start + message_end if error_condition
    end
  end

  class Parser
    CELL = "([A-Z]+[1-9]+[0-9]*)"
    NUMBER = "(0|-?0\.[0-9]*|-?[1-9][0-9]*\.?[0-9]*)"

    MULTIPLE_ARGUMENTS = "(((#{NUMBER}|#{CELL})(\s*,\s*))+(#{NUMBER}|#{CELL}))"
    TWO_ARGUMENTS = "((#{NUMBER}|#{CELL})\s*,\s*(#{NUMBER}|#{CELL}))"

    ADD = /\A=ADD\(#{MULTIPLE_ARGUMENTS}\)\Z/
    MULTIPLY = /\A=MULTIPLY\(#{MULTIPLE_ARGUMENTS}\)\Z/
    SUBTRACT = /\A=SUBTRACT\(#{TWO_ARGUMENTS}\)\Z/
    DIVIDE = /\A=DIVIDE\(#{TWO_ARGUMENTS}\)\Z/
    MOD = /\A=MOD\(#{TWO_ARGUMENTS}\)\Z/

    FORMULA = /(#{ADD}|#{MULTIPLY}|#{SUBTRACT}|#{DIVIDE}|#{MOD})/

    FORMULA_TO_METHOD = { 'ADD' => '+'.to_sym, 'MULTIPLY' => '*'.to_sym,
                          'SUBTRACT' => '-'.to_sym, 'DIVIDE' => '/'.to_sym,
                          'MOD' => '%'.to_sym,
                        }

    def self.parse_table(table)
      split_by_spaces = table.lstrip.rstrip.split(/( {2,}|\t|\n)/)
      first_new_line = split_by_spaces.find_index("\n")
      width = first_new_line ? (first_new_line + 1) / 2 : split_by_spaces.size

      no_spaces = split_by_spaces.select { |s| not /\A(\s*|\t|\n)\Z/.match s }
      no_spaces.each_slice(width).to_a
    end

    def self.correct_cell_index?(call_index)
      /\A#{CELL}\Z/.match call_index
    end

    def self.column(call_index)
      column_letters = /[A-Z]+/.match call_index
      column_letters.to_s.chars.map { |c| c.ord - 'A'.ord + 1 }.join.to_i(26)
    end

    def self.row(call_index)
      row_numbers = /[0-9]+/.match call_index
      row_numbers.to_s.to_i
    end

    def self.evaluate_number(raw_cell)
      cell_to_f = raw_cell[1..-1].to_f
      cell_to_f % 1 == 0 ? cell_to_f.to_i : '%.2f' % cell_to_f
    end

    def self.extract_formula_arguments(match)
      arguments = match[1].gsub(/(=.*\()/,'').chomp(')').split(',')

      arguments.each { |argument| argument.gsub!(/\s+/, '') }
      arguments.map! { |argument| argument.insert(0, '=') }
    end
  end
end