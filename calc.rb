#!/usr/bin/env ruby
require 'tempfile'
require 'fileutils'
require 'optparse'

class SpeechProcessor

  AVERAGE_WORDS_PER_SECOND = 120.0 / 60.0

  attr_reader :stats

  def initialize(text_file)
    @text_file_path = text_file
    @output_dir = "audio"
    @output_file_path = File.join(@output_dir, "#{File.basename(text_file, File.extname(text_file))}.aiff")
    @number_of_words = 0
    @stats = {}
  end

  def run
    FileUtils.mkdir_p(@output_dir)
    process_file
    generate_recording
    calculate_stats
  end

  def generate_report
    <<-EOF
Audio file written to               : #{@output_file_path}
Number of words                     : #{@number_of_words}
Estimated calculated speech length  : #{seconds_to_time_string(@stats[:calculated_duration])} at #{AVERAGE_WORDS_PER_SECOND * 60} words per minute
Esitmated recorded speech length    : #{seconds_to_time_string(@stats[:estimated_recorded_duration])}
EOF
  end

  protected

  def process_file
    @content = File.read(@text_file_path).gsub(/##\s/,'')
    @content.each_line do |line|
      line.split.each do |word|
        @number_of_words += 1
      end
    end
  end

  def generate_recording
    file = Tempfile.new('foo')
    begin
      file.write @content
      file.close
      `say -f #{file.path} -o #{@output_file_path}`
    ensure
      file.close
      file.unlink
    end
  end

  def calculate_stats
    @stats[:audio_file_info] = `afinfo #{@output_file_path}`
    @stats[:estimated_recorded_duration] = /estimated duration: (.+) sec\n/.match(@stats[:audio_file_info])[1].to_f
    @stats[:number_of_words] = @number_of_words
    @stats[:calculated_duration] = @number_of_words / AVERAGE_WORDS_PER_SECOND
  end

  def seconds_to_time_string(total_seconds)
    seconds = total_seconds % 60
    minutes = (total_seconds / 60) % 60
    hours = total_seconds / (60 * 60)
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby calc.rb [options]"

  opts.on("-f", "--file FILE", "Input file") do |f|
    options[:input_file] = f
  end

end.parse!

unless options[:input_file] && File.exists?(options[:input_file])
  STDERR.puts "File #{options[:input_file]} could not be found"
  exit(-1)
end

processor = SpeechProcessor.new(options[:input_file])
processor.run
puts processor.generate_report
