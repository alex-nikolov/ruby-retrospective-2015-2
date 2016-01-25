class LazyMode
  def self.create_file(name, &block)
    new_file = LazyMode::File.new(name)

    new_file.instance_eval(&block)
    new_file
  end

  class Date
    attr_accessor :year, :month, :day

    def initialize(date)
      @year, @month, @day = date.split(' ').first.split('-').map(&:to_i)

      repeat_period = date.split(' ').last
      formated_date = sprintf('%.4d-%.2d-%.2d', @year, @month, @day)
      no_repeat_period = repeat_period == date

      @date = formated_date
      @date << ' ' << repeat_period unless no_repeat_period
    end

    def to_s
      @date
    end

    def match_date?(date)
      old_total_days = LazyMode::Date.new(date).total_days
      return total_days == old_total_days if date.length == 10

      cycle_period = cycle_period_to_days(date)
      days_difference = total_days - old_total_days
      days_difference > 0 and days_difference % cycle_period == 0
    end

    def match_days_of_week(date)
      old_days = LazyMode::Date.new(date).total_days
      equal_day = (total_days..total_days + 6).find { |d| d == old_days }

      return [equal_day] if date.size == 10 and equal_day
      return nil if date.size == 10

      match_multiple_days_of_week(date)
    end

    def match_multiple_days_of_week(date)
      old_days = LazyMode::Date.new(date).total_days
      cycle_period = cycle_period_to_days(date)

      matching_days = (total_days..total_days + 6).find_all do |days|
        days >= old_days and days % cycle_period == old_days % cycle_period
      end

      matching_days == [] ? nil : matching_days
    end

    def self.total_days_to_s(total_days)
      years_months_days = []
      years_months_days[0] = total_days / 360
      years_months_days[1] = total_days % 360 / 30 + 1
      years_months_days[2] = total_days % 30

      Date.new(years_months_days.join('-')).to_s
    end

    def cycle_period_to_days(date)
      cycle_period = date[11..-2].to_i

      case date[-1]
        when 'w' then cycle_period *= 7
        when 'm' then cycle_period *= 30
      end
      cycle_period
    end

    def total_days
      @year * 360 + (@month - 1) * 30 + @day
    end
  end

  class Note
    attr_accessor :header, :file_name, :tags, :notes

    def initialize(file_name, header, *tags)
      @file_name = file_name
      @header = header
      @status = :topostpone
      @body = ''
      @tags = tags.flatten
      @notes = Array.new
    end

    def body(*note_content)
      note_content.size == 1 ? @body = note_content.first : @body
    end

    def status(*symbols)
      symbols.size == 1 ? @status = symbols.first : @status
    end

    def scheduled(*date)
      if date.size == 1
        @scheduled = LazyMode::Date.new(date.first).to_s
      else
        @scheduled
      end
    end

    def note(header, *tags, &block)
      new_note = Note.new(@file_name, header, tags)

      new_note.instance_eval(&block)
      @notes << new_note
      @notes += new_note.notes if new_note.notes.size > 0
    end

    class AgendaNote < Note
      attr_reader :date

      def initialize(note, date)
        @file_name = note.file_name
        @header, @body = note.header, note.body
        @status = note.status
        @tags = note.tags
        @notes = note.notes
        @date = date
      end
    end
  end

  class File
    attr_reader :name, :notes

    def initialize(name)
      @name = name
      @notes = Array.new
    end

    def note(header, *tags, &block)
      new_note = Note.new(@name, header, tags)

      new_note.instance_eval(&block)
      @notes << new_note
      @notes += new_note.notes if new_note.notes.size > 0
    end

    def daily_agenda(date)
      share_date = -> (note) { date.match_date?(note.scheduled) }
      scheduled_notes = @notes.select &share_date

      new_agenda_note = -> (note) { Note::AgendaNote.new(note, date) }
      scheduled_agenda_notes = scheduled_notes.map &new_agenda_note
      Agenda.new(scheduled_agenda_notes)
    end

    def weekly_agenda(date)
      date_within_week = -> (note) { date.match_days_of_week(note.scheduled) }
      notes_at_least_once_within_week = @notes.select &date_within_week

      Agenda.new(all_notes_within_week(notes_at_least_once_within_week, date))
    end

    private

    def all_notes_within_week(notes_at_least_once_within_week, date)
      new_agenda_notes = -> (note) do
        match_days = date.match_days_of_week(note.scheduled)
        map_match_days_to_agenda_notes(note, match_days)
      end

      notes_at_least_once_within_week.flat_map &new_agenda_notes
    end

    def map_match_days_to_agenda_notes(note, match_days)
      match_days.map do |day|
        Note::AgendaNote.new(note, Date.new(Date.total_days_to_s(day)))
      end
    end

    class Agenda < File
      def initialize(scheduled_notes)
        @notes = scheduled_notes
      end

      def where(tag: nil, text: nil, status: nil)
        filtered_notes = @notes.dup

        filter_by_tag(filtered_notes, tag) if tag
        filter_by_status(filtered_notes, status) if status
        filter_by_text(filtered_notes, text) if text

        Agenda.new(filtered_notes)
      end

      private

      def filter_by_tag(filtered_notes, tag)
        filtered_notes.select! { |note| note.tags.include?(tag) }
      end

      def filter_by_text(filtered_notes, text)
        filtered_notes.select! do |note|
          text.match(note.header) or text.match(note.body)
        end
      end

      def filter_by_status(filtered_notes, status)
        filtered_notes.select! { |note| note.status == status }
      end
    end
  end
end