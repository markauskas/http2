module HTTP2
  module HPACK
    class Decoder
      getter index : Index

      def initialize
        @huffman = Huffman.new(Huffman::TABLE)
        @index = Index.new(4096) # TODO: define correct value
        @slice = Slice(UInt8).new(1)
        @pos = 0
      end

      def decode(slice : Slice(UInt8))
        @slice = slice
        @pos = 0
        headers = [] of Array(String)

        # window updates are only allowed at the beginning of the header block.
        # after the first field that is not a window update, we won't allow
        # window updates anymore
        window_update_allowed = true

        while @pos < @slice.size
          # will set to true if current field is a window update
          window_update = false

          if peek.bit(7) == 1_u8
            idx = decode_integer(7)
            headers << index.get(idx)
          elsif peek.bit(6) == 1_u8
            idx = decode_integer(6)

            if idx == 0
              h = [String.new(decode_string), String.new(decode_string)]
              index.add(h)
              headers << h
            else
              h = [index.get(idx)[0], String.new(decode_string)]
              index.add(h[0], h[1])
              headers << h
            end
          elsif peek.bit(5) == 1_u8
            raise Error.new(Error::Code::COMPRESSION_ERROR) unless window_update_allowed

            window_update = true
            new_size = decode_integer(5)
            index.max_table_size = new_size.to_i32
          elsif peek.bit(4) == 1_u8
            idx = decode_integer(4)
            name = idx == 0 ? String.new(decode_string) : index.get(idx)[0]
            h = [name, String.new(decode_string)]
            headers << h
          else
            idx = decode_integer(4)
            name = idx == 0 ? String.new(decode_string) : index.get(idx)[0]
            h = [name, String.new(decode_string)]
            headers << h
          end

          window_update_allowed = window_update
        end
        headers
      rescue ex : Error
        # in case it's already an instance of Error, then we just re-raise it
        raise ex
      rescue ex
        raise Error.new(Error::Code::COMPRESSION_ERROR)
      end

      private def peek
        @slice[@pos]
      end

      private def read
        byte = @slice[@pos]
        @pos += 1
        byte
      end

      private def read_bytes(n)
        bytes = @slice[@pos, n]
        @pos += n
        bytes
      end

      private def decode_integer(prefix)
        num = (read & (0xff_u8 >> (8 - prefix))).to_u32
        max = (2 ** prefix - 1).to_u32

        return num if num < max

        m = 0_u32
        loop do
          byte = read.to_u8
          num = (num + (byte & 0x7f_u8) * (2_u32 ** m)).to_u32
          m += 7_u32
          return num if byte.bit(7) == 0_u8
        end
      end

      private def decode_string
        huffman = peek.bit(7) == 1_u8
        length = decode_integer(7)
        bytes = read_bytes(length)

        if huffman
          @huffman.decode(bytes)
        else
          bytes
        end
      end
    end
  end
end
