module HTTP2
  module HPACK
    # The Index class handles the static and dynamic tables as defined in
    # RFC 7541 (HPACK)
    class Index
      getter max_table_size : Int32

      def initialize(@max_table_size : Int32)
        @static_table = HTTP2::HPACK::Index::STATIC_TABLE # see end of this file
        @dynamic_table = Array(Array(String)).new
        @dynamic_table_bytesize = 0
      end

      def max_table_size=(value : Int32)
        @max_table_size = value
        evict(@max_table_size)
      end

      def size
        @static_table.size + @dynamic_table.size
      end

      def bytesize
        @dynamic_table_bytesize
      end

      def add(name : String, value : String)
        add([name, value])
      end

      def add(h : Array(String))
        new_entry_size = h[0].size + h[1].size + 32
        limit = max_table_size - new_entry_size

        evict(limit)

        if limit >= 0
          @dynamic_table.unshift(h)
          @dynamic_table_bytesize += new_entry_size
        end
      end

      def evict(limit : Int32)
        while @dynamic_table.size > 0 && @dynamic_table_bytesize > limit
          last = @dynamic_table.pop
          last_size = last[0].size + last[1].size + 32
          @dynamic_table_bytesize -= last_size
        end
      end

      def get(index : UInt32)
        raise Error.new(Error::Code::COMPRESSION_ERROR) if index == 0_u32

        if index <= @static_table.size
          @static_table[index - 1]
        elsif index <= size
          @dynamic_table[index - @static_table.size - 1]
        else
          raise Error.new(Error::Code::COMPRESSION_ERROR)
        end
      end

      def index_of(header_field : Array(String))
        if i = @static_table.index { |hf| hf == header_field }
          i.to_u32 + 1_u32
        elsif i = @dynamic_table.index { |hf| hf == header_field }
          i.to_u32 + @static_table.size + 1_u32
        else
          nil
        end
      end

      def index_of(name : String, value : String)
        index_of([name, value])
      end

      # :nodoc:
      STATIC_TABLE = [
        [":authority", ""],
        [":method", "GET"],
        [":method", "POST"],
        [":path", "/"],
        [":path", "/index.html"],
        [":scheme", "http"],
        [":scheme", "https"],
        [":status", "200"],
        [":status", "204"],
        [":status", "206"],
        [":status", "304"],
        [":status", "400"],
        [":status", "404"],
        [":status", "500"],
        ["accept-charset", ""],
        ["accept-encoding", "gzip,deflate"],
        ["accept-language", ""],
        ["accept-ranges", ""],
        ["accept", ""],
        ["access-control-allow-origin", ""],
        ["age", ""],
        ["allow", ""],
        ["authorization", ""],
        ["cache-control", ""],
        ["content-disposition", ""],
        ["content-encoding", ""],
        ["content-language", ""],
        ["content-length", ""],
        ["content-location", ""],
        ["content-range", ""],
        ["content-type", ""],
        ["cookie", ""],
        ["date", ""],
        ["etag", ""],
        ["expect", ""],
        ["expires", ""],
        ["from", ""],
        ["host", ""],
        ["if-match", ""],
        ["if-modified-since", ""],
        ["if-none-match", ""],
        ["if-range", ""],
        ["if-unmodified-since", ""],
        ["last-modified", ""],
        ["link", ""],
        ["location", ""],
        ["max-forwards", ""],
        ["proxy-authenticate", ""],
        ["proxy-authorization", ""],
        ["range", ""],
        ["referer", ""],
        ["refresh", ""],
        ["retry-after", ""],
        ["server", ""],
        ["set-cookie", ""],
        ["strict-transport-security", ""],
        ["transfer-encoding", ""],
        ["user-agent", ""],
        ["vary", ""],
        ["via", ""],
        ["www-authenticate", ""],
      ]
    end
  end
end
