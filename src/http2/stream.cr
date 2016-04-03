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

    def initialize(@id : UInt32, @connection : Connection, @state : State = State::IDLE)
      @headers = Array(Array(String)).new
    end

    def inspect
      "#<STREAM #{"0x%04s" % id.to_s(16)} state=#{@state}>"
    end

    def receive(frame : Frame)
      previous_state = @state
      case @state
      when State::IDLE
        case frame.type
        when Frame::Type::PushPromise
          @state = State::RESERVED_REMOTE
        when Frame::Type::Headers
          @state = State::OPEN
        else
          raise NotImplementedError.new("#{@state} + #{frame.type} = ?")
        end

      when State::RESERVED_LOCAL
        case frame.type
        when Frame::Type::RstStream
          @state = State::CLOSED
        else
          raise NotImplementedError.new("#{@state} + #{frame.type} = ?")
        end
      else
        raise NotImplementedError.new("#{@state}")
      end

      emit(:state_change, self)

      if frame.flags.includes?(Frame::Flags::EndStream)
        previous_state = @state
        if @state == State::OPEN
          @state = State::HALF_CLOSED_REMOTE
        elsif @state == State::HALF_CLOSED_LOCAL
          @state = State::CLOSED
        end

        emit(:state_change, self)
      end
    end

    def send_response(headers : Array(Array(String)), data : Slice(UInt8))
      header_block = @connection.hpack_encoder.encode(headers)
      @connection.send_frame(Frame.new(Frame::Type::Headers, id, Frame::Flags::EndHeaders, header_block))
      @connection.send_frame(Frame.new(Frame::Type::Data, id, Frame::Flags::EndStream, data.to_slice))
      nil
    end
  end
end
