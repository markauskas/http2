module HTTP2
  # This module should be included in all Objects that can be emitted using the
  # `HTTP2::Emitter`.
  module Emittable
    def to_frame : Frame
      if self.is_a? Frame
        self
      else
        raise "Not a frame!"
      end
    end

    def to_stream : Stream
      if self.is_a? Stream
        self
      else
        raise "Not a stream!"
      end
    end
  end

  # Inspired by https://github.com/igrigorik/http-2
  module Emitter
    def on(event : Symbol, &block : Proc(Emittable,Void))
      listeners(event).push(block)
    end

    def emit(event : Symbol, emittable : Emittable)
      listeners(event).each do |cb|
        cb.call(emittable)
      end
    end

    def listeners(event : Symbol)
      if !@listeners
        @listeners = Hash(Symbol, Array(Proc(Emittable,Void))).new do |hash, key|
          hash[key] = [] of Proc(Emittable,Void)
        end
      end
      @listeners.not_nil![event]
    end
  end
end
