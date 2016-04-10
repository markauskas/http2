require "http"
require "./emitter"

module HTTP2
  class Connection
    include Emitter

    # First thing a HTTP/2 client sends to the server
    PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    # Default connection settings as defined in RFC 7540
    SPEC_DEFAULT_SETTINGS = {
      settings_header_table_size:      4096,
      settings_enable_push:            1,
      settings_max_concurrent_streams: Frame::MAX_STREAM_ID,
      settings_initial_window_size:    65_535,
      settings_max_frame_size:         16_384,
      settings_max_header_list_size:   2**31 - 1,
    }

    # Our default settings
    DEFAULT_SETTINGS = {
      settings_max_concurrent_streams: 100,
    }

    # Settings name/id mapping
    SETTINGS_MAP = {
      settings_header_table_size:      1_u16,
      settings_enable_push:            2_u16,
      settings_max_concurrent_streams: 3_u16,
      settings_initial_window_size:    4_u16,
      settings_max_frame_size:         5_u16,
      settings_max_header_list_size:   6_u16,
    }

    getter hpack_encoder : HPACK::Encoder
    getter hpack_decoder : HPACK::Decoder

    def initialize(io)
      @io = io
      @local_settings = SPEC_DEFAULT_SETTINGS.merge(DEFAULT_SETTINGS)
      @remote_settings = SPEC_DEFAULT_SETTINGS.dup

      @streams = {} of UInt32 => Stream
      @last_stream_id = 0_u32 # highest received stream id
      @hpack_encoder = HPACK::Encoder.new
      @hpack_decoder = HPACK::Decoder.new

      @next_stream_id = 2_u32
    end

    def inspect
      to_s
    end

    def send_settings
      # TODO: add payload
      frame = Frame.new(Frame::Type::Settings, 0_u32)
      send_frame(frame)
    end

    def send_goaway(error_code : Error::Code)
      payload = MemoryIO.new
      payload.write_bytes(@last_stream_id, IO::ByteFormat::BigEndian)
      payload.write_bytes(error_code.value, IO::ByteFormat::BigEndian)
      frame = Frame.new(Frame::Type::GoAway, 0_u32, Frame::Flags::None, payload.to_slice)
      send_frame(frame)
    end

    def send_rst_stream(error_code : Error::Code)
      payload = MemoryIO.new
      payload.write_bytes(error_code.value, IO::ByteFormat::BigEndian)
      frame = Frame.new(Frame::Type::RstStream, @last_stream_id, Frame::Flags::None, payload.to_slice)
      send_frame(frame)
    end

    def send_frame(frame : Frame)
      @io.write(frame.to_slice)
      emit(:frame_sent, frame)
    end

    def receive_preface
      @io.read_fully(buf = Slice(UInt8).new(PREFACE.size))

      unless String.new(buf) == PREFACE
        @io.close
        raise "Invalid preface" # TODO
        # TODO: support for Upgrade: h2c
      end

      send_settings

      # the preface must be followed by a settings frame
      process_settings(receive_frame(Frame::Type::Settings))
    end

    def receive_frame(type : Frame::Type = nil)
      frame = Frame.new(@io, @local_settings[:settings_max_frame_size].to_u32)
      emit(:frame_received, frame)
      @last_stream_id = frame.stream_id if frame.stream_id > @last_stream_id
      raise Error.new(Error::Code::PROTOCOL_ERROR) unless type.nil? || type == frame.type
      frame
    end

    def find_or_create_stream(stream_id)
      unless @streams[stream_id]?
        @streams[stream_id] = Stream.new(stream_id)
        emit(:stream, @streams[stream_id])
        @streams[stream_id].on(:frame) do |emittable|
          send_frame(emittable.to_frame)
        end
      end
      @streams[stream_id]
    end

    def new_stream_id
      id = @next_stream_id
      @next_stream_id += 2
      id
    end

    def reserve_push_stream
      id = new_stream_id
      @streams[id] = Stream.new(id, Stream::State::RESERVED_LOCAL)
      emit(:stream, @streams[id])
      @streams[id].on(:frame) do |emittable|
        send_frame(emittable.to_frame)
      end
      @streams[id]
    end

    def receive_and_process_frame
      frame = receive_frame
      stream = find_or_create_stream(frame.stream_id)

      case frame.type
      when Frame::Type::Headers
        stream.headers = process_headers(frame)
      when Frame::Type::WindowUpdate
        process_window_update(frame)
      when Frame::Type::Settings
        process_settings(frame)
      when Frame::Type::Ping
        process_ping(frame)
      when Frame::Type::Priority
        # TODO: do something
      when Frame::Type::Data
        # TODO: do something
      when Frame::Type::RstStream
        # TODO: do something
      when Frame::Type::Continuation
        # TODO: do something
      when Frame::Type::GoAway
        # TODO: do something
      else
        raise NotImplementedError.new("Unsupported frame type: #{frame.type}")
      end

      if frame.stream_id != 0_u32
        stream.receive(frame)
      end
    rescue ex : Error
      puts "Error: #{ex.error_code}"
      case ex.error_code
      when Error::Code::FRAME_SIZE_ERROR
        send_goaway(ex.error_code)
        @io.close
      when Error::Code::PROTOCOL_ERROR
        send_goaway(ex.error_code)
        @io.close
      when Error::Code::COMPRESSION_ERROR
        send_goaway(ex.error_code)
        @io.close
      when Error::Code::STREAM_CLOSED
        send_rst_stream(ex.error_code)
      else
        raise ex
      end
    rescue ex : IO::EOFError
      @io.close
    rescue ex : Errno
      @io.close
    end

    def process_settings(frame : Frame)
      raise Error.new(Error::Code::PROTOCOL_ERROR) unless frame.type == Frame::Type::Settings
      raise Error.new(Error::Code::PROTOCOL_ERROR) unless frame.stream_id == 0_u32
      raise Error.new(Error::Code::FRAME_SIZE_ERROR) unless frame.payload.size % 6 == 0

      if frame.flags.includes? Frame::Flags::EndStream # NOTE: EndStream means Ack in settings frames
         # TODO: mark as ACKed?
      else
        length = frame.payload.size
        payload_io = MemoryIO.new(frame.payload)

        while length > 0
          identifier = SETTINGS_MAP.key(payload_io.read_bytes(UInt16, IO::ByteFormat::BigEndian))
          value = payload_io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
          # TODO: emit settings change
          @remote_settings[identifier] = value
          length -= 6
        end

        send_frame Frame.new(Frame::Type::Settings, 0_u32, Frame::Flags::EndStream)
      end
    end

    def process_ping(frame : Frame)
      if frame.flags.includes? Frame::Flags::EndStream
      else
        send_frame Frame.new(Frame::Type::Ping, 0_u32, Frame::Flags::EndStream, frame.payload)
      end
    end

    def process_headers(frame : Frame)
      stream = find_or_create_stream(frame.stream_id)

      payload_io = MemoryIO.new(frame.payload)
      length = frame.payload.size.to_u32

      if frame.flags.includes? Frame::Flags::Padded
        padding = payload_io.read_byte.not_nil!.to_u32
        length -= 1       # padding length byte
        length -= padding # actual padding
      end

      if frame.flags.includes? Frame::Flags::Priority
        # TODO: do something with these values
        buffer = payload_io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
        stream_dependency = buffer & 0x7fffffff_u32
        exclusive = buffer.bit(31) == 1_u8
        weight = payload_io.read_byte.not_nil!
        length -= 5_u32
      end

      header_block = Slice(UInt8).new(length)
      payload_io.read(header_block)

      unless frame.flags.includes? Frame::Flags::EndHeaders
        io = MemoryIO.new
        io.write(header_block)
        io.write(receive_continuation_frames(stream))
        header_block = io.to_slice
      end

      hpack_decoder.decode(header_block)
    end

    def receive_continuation_frames(stream : Stream)
      io = MemoryIO.new
      while frame = receive_frame(Frame::Type::Continuation)
        raise Error.new(Error::Code::PROTOCOL_ERROR) if frame.stream_id != stream.id
        io.write(frame.payload)
        break if frame.flags.includes?(Frame::Flags::EndHeaders)
      end
      io.to_slice
    end

    def process_window_update(frame)
      stream = find_or_create_stream(frame.stream_id)
      payload_io = MemoryIO.new(frame.payload)
      size = payload_io.read_bytes(UInt32, IO::ByteFormat::BigEndian) & 0x7fffffff_u32
      # TODO: do something with the new size"
    end
  end
end
