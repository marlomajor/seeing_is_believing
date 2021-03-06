require 'seeing_is_believing/event_stream/events'
require 'thread'

class SeeingIsBelieving
  module EventStream
    class Producer

      module NullQueue
        extend self
        def <<(*)   end
        def shift() end
      end

      attr_accessor :max_line_captures, :filename

      def initialize(resultstream)
        self.filename          = nil
        self.max_line_captures = Float::INFINITY
        self.recorded_results  = []
        self.queue             = Queue.new
        self.producer_thread   = Thread.new do
          begin
            resultstream.sync = true
            loop do
              to_publish = queue.shift
              break if to_publish == :break
              resultstream << (to_publish << "\n")
            end
          rescue IOError, Errno::EPIPE
            queue.clear
          ensure
            self.queue = NullQueue
            resultstream.flush rescue nil
          end
        end
      end

      attr_reader :version
      alias ver version
      def record_sib_version(sib_version)
        @version = sib_version
        queue << "sib_version #{to_string_token sib_version}"
      end

      def record_ruby_version(ruby_version)
        queue << "ruby_version #{to_string_token ruby_version}"
      end

      def record_max_line_captures(max_line_captures)
        self.max_line_captures = max_line_captures
        queue << "max_line_captures #{max_line_captures}"
      end

      StackErrors = [SystemStackError]
      StackErrors << Java::JavaLang::StackOverflowError if defined?(RUBY_PLATFORM) && RUBY_PLATFORM == 'java'
      def record_result(type, line_number, value)
        counts = recorded_results[line_number] ||= Hash.new(0)
        count  = counts[type]
        recorded_results[line_number][type] = count.next
        if count < max_line_captures
          begin
            if block_given?
              inspected = yield(value).to_str
            else
              inspected = value.inspect.to_str
            end
          rescue *StackErrors
            # this is necessary because SystemStackError won't show the backtrace of the method we tried to call
            # which means there won't be anything showing the user where this came from
            # so we need to re-raise the error to get a backtrace that shows where we came from
            # otherwise it looks like the bug is in SiB and not the user's program, see https://github.com/JoshCheek/seeing_is_believing/issues/37
            raise SystemStackError, "Calling inspect blew the stack (is it recursive w/o a base case?)"
          rescue Exception
            inspected = "#<no inspect available>"
          end
          queue << "result #{line_number} #{type} #{to_string_token inspected}"
        elsif count == max_line_captures
          queue << "maxed_result #{line_number} #{type}"
        end
        value
      end

      # records the exception, returns the exitstatus for that exception
      def record_exception(line_number, exception)
        return exception.status if exception.kind_of? SystemExit
        if !line_number && filename
          begin line_number = exception.backtrace.grep(/#{filename}/).first[/:\d+/][1..-1].to_i
          rescue NoMethodError
          end
        end
        line_number ||= -1
        queue << [
          "exception",
          line_number,
          to_string_token(exception.class.name),
          to_string_token(exception.message),
          exception.backtrace.size,
          *exception.backtrace.map { |line| to_string_token line }
        ].join(" ")
        1 # exit status
      end

      def record_filename(filename)
        self.filename = filename
        queue << "filename #{to_string_token filename}"
      end

      def record_exec(args)
        queue << "exec #{to_string_token args.inspect}"
      end

      def record_num_lines(num_lines)
        queue << "num_lines #{num_lines}"
      end

      def finish!
        queue << :break # note that consumer will continue reading until stream is closed
        producer_thread.join
      end

      private

      attr_accessor :resultstream, :queue, :producer_thread, :recorded_results

      # for a consideration of many different ways of doing this, see 5633064
      def to_string_token(string)
        [Marshal.dump(string.to_s)].pack('m0')
      end
    end
  end
end
