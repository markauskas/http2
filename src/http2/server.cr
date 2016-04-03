require "./connection"

module HTTP2
  class Server < Connection
    def initialize(io)
      super(io)
    end

    def work
      receive_preface
      while !@io.closed?
        receive_and_process_frame
      end
    rescue ex
      puts "rescue: #{ex.class}: #{ex.message}"
      # puts ex.backtrace.join("\n")
    end
  end
end
