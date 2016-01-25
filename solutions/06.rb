class TurtleGraphics
  class Turtle
    ORIENTATIONS = [:up, :left, :down, :right].freeze
    MOVE_OFFSET = [[-1, 0], [0, -1], [1, 0], [0, 1]].freeze

    def initialize(rows, columns)
      @rows = rows
      @columns = columns
      @x = 0
      @y = 0
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

      @x = @x % @rows
      @y = @y % @columns

      @canvas.increment_value(@x, @y)
    end

    def draw(given_canvas = @canvas, &block)
      instance_eval(&block) if block_given?

      given_canvas.convert_canvas(@canvas)
    end

    def look(orientation)
      @orientation = orientation
    end

    def turn_left
      @orientation = ORIENTATIONS[(ORIENTATIONS.find_index(@orientation) + 1) % 4]
    end

    def turn_right
      @orientation = ORIENTATIONS[(ORIENTATIONS.find_index(@orientation) - 1) % 4]
    end

    private

    def move_offset
      MOVE_OFFSET[ORIENTATIONS.find_index(@orientation)]
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
        maximum_steps = default_canvas.maximum_steps

        default_canvas.canvas.map do |row|
          row.map do |steps|
            steps_to_symbol(steps, maximum_steps)
          end.join
        end.join("\n")
      end

      def steps_to_symbol(steps, maximum_steps)
        intensity = steps.to_f / maximum_steps
        corresponding_symbol_index = (intensity * (@allowed_symbols.size - 1)).ceil

        @allowed_symbols[corresponding_symbol_index]
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