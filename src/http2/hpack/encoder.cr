module HTTP2
  module HPACK
    class Encoder
      getter index : Index

      def initialize
        @huffman = Huffman.new(Huffman::TABLE)
        @slice = Slice(UInt8).new(1)
        @pos = 0
        @index = Index.new
      end

      def encode(headers : Array(Array(String)))
        io = MemoryIO.new
        headers.each do |h|
          # TODO: literal field without indexing
          # TODO: literal field never indexed
          if idx = index.index_of(h)
            slice = encode_integer(idx, 7_u8)
            slice[0] = slice[0] | 0x80_u8
            io.write(slice)
          elsif idx = index.index_of(h[0], "")
            slice = encode_integer(idx, 6_u8)
            slice[0] = slice[0] | 0x40_u8
            io.write(slice)
            io.write(encode_string(h[1], false))
            index.add(h)
          else
            io.write_byte(0x40_u8)
            io.write(encode_string(h[0], false))
            io.write(encode_string(h[1], false))
            index.add(h)
          end
        end
        io.to_slice
      end

      private def encode_string(str : String, huffman : Bool)
        io = MemoryIO.new
        slice = str.to_slice
        size = slice.size.to_u32
        header = encode_integer(size, 7_u8)
        if huffman
          header[0] = header[0] | 0x80_u8
        else
          header[0] = header[0] & 0x7f_u8
        end
        io.write(header)
        io.write(slice)
        io.to_slice
      end

      private def encode_integer(n : UInt32, prefix : UInt8)
        max = 2 ** prefix - 1
        io = MemoryIO.new

        if n < max
          io.write_byte(n.to_u8)
        else
          io.write_byte(max.to_u8)
          n = n - max.to_u32
          while n >= 128
            io.write_byte((n % 128 + 128).to_u8)
            n = n / 128
          end
          io.write_byte(n.to_u8)
        end

        io.to_slice
      end
    end
  end
end
