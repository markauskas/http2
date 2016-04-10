require "http"
require "./emitter"

module HTTP2
  class Stream
    include Emitter
    include Emittable

    enum State
      IDLE
      RESERVED_LOCAL
      RESERVED_REMOTE
      OPEN
      HALF_CLOSED_LOCAL
      HALF_CLOSED_REMOTE
      CLOSED
    end

    getter id : UInt32
    getter state : State

    property headers : Array(Array(String))

    def initialize(@id : UInt32, @state : State = State::IDLE)
      @headers = Array(Array(String)).new
    end

    def inspect
      "#<STREAM #{"0x%04s" % id.to_s(16)} state=#{@state}>"
    end

    def receive(frame : Frame)
      case @state
      when State::IDLE
        case frame.type
        when Frame::Type::Headers
          if frame.flags.includes?(Frame::Flags::EndStream)
            @state = State::HALF_CLOSED_REMOTE
            emit(:half_closed_remote, self)
          else
            @state = State::OPEN
            emit(:open, self)
          end
        when Frame::Type::Priority
          # TODO: handle priority
        else
          raise Error.new(Error::Code::PROTOCOL_ERROR)
        end

      when State::OPEN
        if frame.type == Frame::Type::RstStream
          @state = State::CLOSED
          emit(:closed, self)
        elsif frame.flags.includes?(Frame::Flags::EndStream)
          @state = State::HALF_CLOSED_REMOTE
          emit(:half_closed_remote, self)
        end

      when State::HALF_CLOSED_REMOTE
        case frame.type
        when Frame::Type::WindowUpdate
          # TODO: handle
        when Frame::Type::Priority
          # TODO: handle
        when Frame::Type::RstStream
          @state = State::CLOSED
          emit(:closed, self)
        else
          raise Error.new(Error::Code::STREAM_CLOSED)
        end

      when State::CLOSED
        # For now we don't accept any frames on closed streams
        raise Error.new(Error::Code::STREAM_CLOSED)

      else
        raise NotImplementedError.new("Not implemented State: #{@state}")
      end
    end

    def headers(payload : Slice(UInt8), flags = Frame::Flags::EndHeaders)
      f = Frame.new(Frame::Type::Headers, id, flags, payload)
      emit(:frame, f)
    end

    def data(payload : Slice(UInt8), flags)
      f = Frame.new(Frame::Type::Data, id, flags, payload)
      emit(:frame, f)
    end

    def push_promise(stream_id : UInt32, payload : Slice(UInt8))
      io = MemoryIO.new
      io.write_bytes(stream_id & 0x7fffffff_u32, IO::ByteFormat::BigEndian)
      io.write(payload)
      f = Frame.new(Frame::Type::PushPromise, id, Frame::Flags::EndHeaders, io.to_slice)
      emit(:frame, f)
    end
  end
end
