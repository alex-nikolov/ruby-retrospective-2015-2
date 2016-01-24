class TurtleGraphics
  class Turtle
    ORIENTATIONS = [
      [:up, [-1, 0]],
      [:left, [0, -1]],
      [:down, [1, 0]],
      [:right, [0, 1]],
    ]

    def initialize(rows, columns)
      @rows, @columns = rows, columns
      @x, @y = 0, 0
      @orientation = :right
      @canvas = Canvas::Default.new(rows, columns)
    end

    def spawn_at(row, column)
      @x = row
      @y = column
      if [row, column] != [0, 0]
        @canvas.remove_steps_at(0, 0)
        @canvas.increment_value(row, column)
      end
    end

    def move
      @x += move_offset.first
      @y += move_offset.last

      correct_out_of_bounds_coordinates(@x, @y)
      @canvas.increment_value(@x, @y)
    end

    def turn_left
      turn 1
    end

    def turn_right
      turn -1
    end

    def draw(given_canvas = @canvas, &block)
      instance_eval(&block) if block_given?

      given_canvas.convert_canvas(@canvas)
    end

    def look(orientation)
      @orientation = orientation
    end

    private

    def turn(direction)
      orientation_index = ORIENTATIONS.index { |pair| pair.first == @orientation }
      changed_orientation = ORIENTATIONS[(orientation_index + direction) % 4]

      @orientation = changed_orientation.first
    end

    def move_offset
      ORIENTATIONS.find { |pair| @orientation == pair.first }.last
    end

    def correct_out_of_bounds_coordinates(x, y)
      @x = x % @rows
      @y = y % @columns
    end
  end

  class Canvas
    class Default
      attr_reader :canvas, :maximum_steps

      def initialize(rows, columns)
        @canvas = Array.new(rows) { Array.new(columns, 0) }
        @canvas[0][0] = 1
        @maximum_steps = 1
      end

      def convert_canvas(_)
        @canvas
      end

      def increment_value(x, y)
        @canvas[x][y] += 1
        @maximum_steps = @canvas[x][y] if @canvas[x][y] > @maximum_steps
      end

      def remove_steps_at(x, y)
        @canvas[x][y] = 0
      end
    end

    module Intensity
      def convert_to_intensity(default_canvas)
        maximum_steps = default_canvas.maximum_steps
        row_to_intensity = -> (r) { r.map { |steps| steps.to_f / maximum_steps } }
        default_canvas.canvas.map &row_to_intensity
      end
    end

    class ASCII
      include Intensity

      def initialize(allowed_symbols)
        @allowed_symbols = allowed_symbols
      end

      def convert_canvas(default_canvas)
        limit_gaps = @allowed_symbols.size - 1

        to_symbols = -> (symbol, index) { [index.to_f / limit_gaps, symbol] }
        intensity_to_symbol = @allowed_symbols.map.with_index &to_symbols

        intensity_canvas = convert_to_intensity(default_canvas)
        symbol_canvas = convert_to_symbols(intensity_canvas, intensity_to_symbol)
        symbol_canvas.reduce("") { |memo, row| memo + row.join + "\n" }.chomp
      end

      def convert_to_symbols(intensity_canvas, intensity_to_symbol)
        to_symbol = -> (intensity) do
          intensity_to_symbol.find { |pair| pair.first >= intensity }.last
        end
        row_to_symbols = -> (row) { row.map &to_symbol }
        intensity_canvas.map &row_to_symbols
      end
    end

    class HTML
      include Intensity

      def initialize(pixel_size)
        @pixel_size = pixel_size
      end

      def convert_canvas(default_canvas)
        html_head + html_body(default_canvas)
      end

      def html_head
        "<!DOCTYPE html><html><head><title>Turtle graphics</title><style>table
         {border-spacing: 0;}tr {padding: 0;}td {width: #{@pixel_size}px;
         height: #{@pixel_size}px;background-color: black;padding: 0;}
         </style></head>"
      end

      def html_body(default_canvas)
        body_start = "<body><table>"
        body_end = "</table></body></html>"
        body_mid = String.new
        convert_to_intensity(default_canvas).each do |row|
          body_mid << "<tr>"
          row.each { |intensity| body_mid << html_opacity(intensity) }
          body_mid << "</tr>"
        end
        body_start + body_mid + body_end
      end

      def html_opacity(intensity)
        quotes = '"'
        "<td style=#{quotes}opacity: #{format('%.2f', intensity)}#{quotes}></td>"
      end
    end
  end
end