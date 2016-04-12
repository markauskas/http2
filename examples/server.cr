require "../src/http2"
require "colorize"
require "option_parser"

class Hello
  def initialize(@ip, @h1_port, @h2_port, @root = ".")
  end

  def content_type(path)
    if path.ends_with? ".html"
      "text/html"
    elsif path.ends_with? ".ico"
      "image/x-icon"
    elsif path.ends_with? ".jpg"
      "image/jpg"
    elsif path.ends_with? ".png"
      "image/png"
    else
      "application/octet-stream"
    end
  end

  def send_data_frame(stream : HTTP2::Stream, path : String)
    File.open(path) do |f|
      f.read(slice = Slice(UInt8).new(f.size))
      stream.data(slice, HTTP2::Frame::Flags::EndStream)
    end
  end

  def handle_connection(socket)
    puts "NEW CONNECTION!"
    conn = HTTP2::Server.new(socket)
    conn.on(:frame_received) do |emittable|
      frame = emittable.to_frame
      puts "<- FRAME: #{frame.inspect}".colorize.green
    end
    conn.on(:frame_sent) do |emittable|
      frame = emittable.to_frame
      puts "-> FRAME: #{frame.inspect}".colorize.red
    end
    conn.on(:stream) do |emittable|
      stream = emittable.to_stream

      # all request headers are received when we reach the HALF_CLOSED_REMOTE state
      stream.on(:half_closed_remote) do |emittable|
        stream = emittable.to_stream
        req = stream.headers.not_nil!
        method = req.find { |e| e.not_nil![0] == ":method" }.not_nil![1]
        authority = req.find { |e| e.not_nil![0] == ":authority" }.not_nil![1]
        scheme = req.find { |e| e.not_nil![0] == ":scheme" }.not_nil![1]
        path_and_query = req.find { |e| e.not_nil![0] == ":path" }.not_nil![1]

        arr = path_and_query.split("?")
        path = arr[0]
        query_string = arr[1]? ? arr[1] : ""

        puts "#{method} #{path}#{query_string.size > 0 ? "?" : ""}#{query_string}"

        path = path + "index.html" if path.ends_with?("/")

        full_path = @root + path

        if File.exists?(full_path)
          stream.headers([[":status", "200"], ["content-type", content_type(full_path)]])

          pushes = [] of String

          # TODO: parse HTML and extract all filenames from local files
          if path == "/index.html"
            pushes = [
              "/favicon.ico",
            ]
          end

          # Send PUSH_PROMISEs for each file
          push_streams = pushes.map do |file|
            push_stream = conn.reserve_push_stream
            puts "PUSH_PROMISE: #{file}"
            stream.push_promise(push_stream.id, [[":method", "GET"], [":authority", authority], [":scheme", scheme], [":path", file]])
            push_stream
          end

          send_data_frame(stream, full_path)

          # Send actual files
          pushes.zip(push_streams) do |file, push_stream|
            push_stream.headers([[":status", "200"], ["content-type", content_type(@root + file)]])
            send_data_frame(push_stream, @root + file)
          end
        else
          stream.headers([[":status", "404"]], HTTP2::Frame::Flags::EndStream | HTTP2::Frame::Flags::EndHeaders)
        end
      end
    end
    conn.work
  end

  def run
    spawn run_h1

    puts "Starting HTTP/2 server in #{@root}, listening on #{@ip}:#{@h2_port}"

    server = TCPServer.new(@ip, @h2_port)
    loop { spawn handle_connection(server.accept) }
  end

  def run_h1
    puts "Starting HTTP/1 server in #{@root}, listening on #{@ip}:#{@h1_port}"

    server = HTTP::Server.new(@h1_port) do |context|
      path = context.request.path
      context.response.content_type = "text/plain"
      context.response.print "Hello HTTP/1!"
    end

    server.listen
  end
end

ip = "127.0.0.1"
h1_port = 8082
h2_port = 8081
root = "."

OptionParser.parse! do |parser|
  parser.banner = "Usage: hello [options] [ROOT]"
  parser.on("--http1-port=PORT", "Port to listen to") { |p| h1_port = p.to_i32 }
  parser.on("--http2-port=PORT", "Port to listen to") { |p| h2_port = p.to_i32 }
  parser.on("-b IP", "--bind=IP", "IP to bind to") { |b| ip = b }
  parser.on("-h", "--help", "Show this help") { puts parser; exit }
  parser.unknown_args do |args|
    if args[0]?
      root = args[0]
    end
  end
end

unless File.directory?(root)
  puts "Given root (#{root}) does not exist!"
  exit 1
end

Hello.new(ip, h1_port, h2_port, root).run
