require "./emitter"

module HTTP2
  class Frame
    include Emittable

    enum Type : UInt8
      Data         = 0x0
      Headers      = 0x1
      Priority     = 0x2
      RstStream    = 0x3
      Settings     = 0x4
      PushPromise  = 0x5
      Ping         = 0x6
      GoAway       = 0x7
      WindowUpdate = 0x8
      Continuation = 0x9
    end

    @[Flags]
    # TODO: find a way to deal with Ack flag (for Settings and Ping frames)
    enum Flags : UInt8
      EndStream  =  0x1
      EndHeaders =  0x4
      Padded     =  0x8
      Priority   = 0x20
    end

    MAX_STREAM_ID = 0x7fffffff_u32

    getter type
    getter stream_id
    getter flags
    getter payload
    getter headers : Array(Array(String)) | Nil

    def initialize(@type : Type, @stream_id : UInt32, @flags : Flags, @payload : Slice(UInt8))
    end

    # For Headers frames
    def initialize(@type : Type, @stream_id : UInt32, @flags : Flags, @headers : Array(Array(String)))
      @payload = Slice(UInt8).new(0)
    end

    # For PushPromise frames
    def initialize(@type : Type, @stream_id : UInt32, @flags : Flags, @payload : Slice(UInt8), @headers : Array(Array(String)))
    end

    def initialize(io : IO, max_frame_size : UInt32)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_u32
      length = ((length << 8) | io.read_byte.not_nil!).to_u32
      @type = Type.new(io.read_byte.not_nil!)
      @flags = Flags.new(io.read_byte.not_nil!)
      @stream_id = (io.read_bytes(UInt32, IO::ByteFormat::BigEndian) & 0x7fffffff).to_u32
      if length > max_frame_size
        raise Error.new(Error::Code::FRAME_SIZE_ERROR)
      end
      @payload = Slice(UInt8).new(length)
      io.read(@payload) if length > 0
    end

    def inspect
      "#<#{type.to_s.upcase} stream_id=0x#{stream_id.to_s(16)} flags=#{flags.inspect} headers=#{headers.inspect} payload=#{payload.size}B>"
    end
  end
end
