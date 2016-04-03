module HTTP2
  module HPACK
    class Huffman
      class DecodingError < Exception
      end

      def initialize(table)
        @decoding_table = Hash(UInt8, Hash(UInt32, UInt8)).new
        @table = table
        @table.each do |value, bits|
          code, length = bits
          @decoding_table[length] ||= {} of UInt32 => UInt8
          @decoding_table[length][code] = value
        end
      end

      def encode(slice : Slice(UInt8))
        io = MemoryIO.new
        buffer = 0_u8
        offset = 8 # number of bits that are still unused in buffer
        slice.each do |byte|
          code, length = @table[byte]
          while length > 0
            if offset >= length
              # all of the remaining bits will fit into buffer byte
              buffer = buffer | (code << (offset - length)).to_u8
              offset = offset - length
              length = 0_u32
            else
              # only a prefix will fit into buffer
              buffer = buffer | (code >> (length - offset)).to_u8
              length = length - offset
              offset = 0
            end

            if offset == 0
              # puts "Buffer full, writing %08s" % buffer.to_s(2)
              io.write_byte(buffer)
              buffer = 0_u8
              offset = 8
            end
          end
        end

        if offset < 8
          mask = 0x7f_u8 >> (7 - offset)
          buffer = buffer | mask
          io.write_byte(buffer)
        end
        io.to_slice
      end

      def decode(slice : Slice(UInt8))
        io = MemoryIO.new
        lookup = 0_u32
        length = 0_u8
        slice.each do |byte|
          7.downto 0 do |bit|
            lookup = (lookup << 1) | byte.bit(bit).to_u32
            length += 1
            if @decoding_table[length]? && @decoding_table[length][lookup]?
              io.write_byte(@decoding_table[length][lookup])
              length = 0
              lookup = 0_u32
            end
          end
        end
        if length > 7
          raise DecodingError.new
        elsif length > 0
          mask = 0xffffffff_u32 >> (32 - length)
          raise DecodingError.new if mask & lookup != mask
        end
        io.to_slice
      end

      # :nodoc:
      TABLE = {
          0_u8 => {0x1ff8_u32, 13_u8},
          1_u8 => {0x7fffd8_u32, 23_u8},
          2_u8 => {0xfffffe2_u32, 28_u8},
          3_u8 => {0xfffffe3_u32, 28_u8},
          4_u8 => {0xfffffe4_u32, 28_u8},
          5_u8 => {0xfffffe5_u32, 28_u8},
          6_u8 => {0xfffffe6_u32, 28_u8},
          7_u8 => {0xfffffe7_u32, 28_u8},
          8_u8 => {0xfffffe8_u32, 28_u8},
          9_u8 => {0xffffea_u32, 24_u8},
         10_u8 => {0x3ffffffc_u32, 30_u8},
         11_u8 => {0xfffffe9_u32, 28_u8},
         12_u8 => {0xfffffea_u32, 28_u8},
         13_u8 => {0x3ffffffd_u32, 30_u8},
         14_u8 => {0xfffffeb_u32, 28_u8},
         15_u8 => {0xfffffec_u32, 28_u8},
         16_u8 => {0xfffffed_u32, 28_u8},
         17_u8 => {0xfffffee_u32, 28_u8},
         18_u8 => {0xfffffef_u32, 28_u8},
         19_u8 => {0xffffff0_u32, 28_u8},
         20_u8 => {0xffffff1_u32, 28_u8},
         21_u8 => {0xffffff2_u32, 28_u8},
         22_u8 => {0x3ffffffe_u32, 30_u8},
         23_u8 => {0xffffff3_u32, 28_u8},
         24_u8 => {0xffffff4_u32, 28_u8},
         25_u8 => {0xffffff5_u32, 28_u8},
         26_u8 => {0xffffff6_u32, 28_u8},
         27_u8 => {0xffffff7_u32, 28_u8},
         28_u8 => {0xffffff8_u32, 28_u8},
         29_u8 => {0xffffff9_u32, 28_u8},
         30_u8 => {0xffffffa_u32, 28_u8},
         31_u8 => {0xffffffb_u32, 28_u8},
         32_u8 => {0x14_u32, 6_u8},
         33_u8 => {0x3f8_u32, 10_u8},
         34_u8 => {0x3f9_u32, 10_u8},
         35_u8 => {0xffa_u32, 12_u8},
         36_u8 => {0x1ff9_u32, 13_u8},
         37_u8 => {0x15_u32, 6_u8},
         38_u8 => {0xf8_u32, 8_u8},
         39_u8 => {0x7fa_u32, 11_u8},
         40_u8 => {0x3fa_u32, 10_u8},
         41_u8 => {0x3fb_u32, 10_u8},
         42_u8 => {0xf9_u32, 8_u8},
         43_u8 => {0x7fb_u32, 11_u8},
         44_u8 => {0xfa_u32, 8_u8},
         45_u8 => {0x16_u32, 6_u8},
         46_u8 => {0x17_u32, 6_u8},
         47_u8 => {0x18_u32, 6_u8},
         48_u8 => {0x0_u32, 5_u8},
         49_u8 => {0x1_u32, 5_u8},
         50_u8 => {0x2_u32, 5_u8},
         51_u8 => {0x19_u32, 6_u8},
         52_u8 => {0x1a_u32, 6_u8},
         53_u8 => {0x1b_u32, 6_u8},
         54_u8 => {0x1c_u32, 6_u8},
         55_u8 => {0x1d_u32, 6_u8},
         56_u8 => {0x1e_u32, 6_u8},
         57_u8 => {0x1f_u32, 6_u8},
         58_u8 => {0x5c_u32, 7_u8},
         59_u8 => {0xfb_u32, 8_u8},
         60_u8 => {0x7ffc_u32, 15_u8},
         61_u8 => {0x20_u32, 6_u8},
         62_u8 => {0xffb_u32, 12_u8},
         63_u8 => {0x3fc_u32, 10_u8},
         64_u8 => {0x1ffa_u32, 13_u8},
         65_u8 => {0x21_u32, 6_u8},
         66_u8 => {0x5d_u32, 7_u8},
         67_u8 => {0x5e_u32, 7_u8},
         68_u8 => {0x5f_u32, 7_u8},
         69_u8 => {0x60_u32, 7_u8},
         70_u8 => {0x61_u32, 7_u8},
         71_u8 => {0x62_u32, 7_u8},
         72_u8 => {0x63_u32, 7_u8},
         73_u8 => {0x64_u32, 7_u8},
         74_u8 => {0x65_u32, 7_u8},
         75_u8 => {0x66_u32, 7_u8},
         76_u8 => {0x67_u32, 7_u8},
         77_u8 => {0x68_u32, 7_u8},
         78_u8 => {0x69_u32, 7_u8},
         79_u8 => {0x6a_u32, 7_u8},
         80_u8 => {0x6b_u32, 7_u8},
         81_u8 => {0x6c_u32, 7_u8},
         82_u8 => {0x6d_u32, 7_u8},
         83_u8 => {0x6e_u32, 7_u8},
         84_u8 => {0x6f_u32, 7_u8},
         85_u8 => {0x70_u32, 7_u8},
         86_u8 => {0x71_u32, 7_u8},
         87_u8 => {0x72_u32, 7_u8},
         88_u8 => {0xfc_u32, 8_u8},
         89_u8 => {0x73_u32, 7_u8},
         90_u8 => {0xfd_u32, 8_u8},
         91_u8 => {0x1ffb_u32, 13_u8},
         92_u8 => {0x7fff0_u32, 19_u8},
         93_u8 => {0x1ffc_u32, 13_u8},
         94_u8 => {0x3ffc_u32, 14_u8},
         95_u8 => {0x22_u32, 6_u8},
         96_u8 => {0x7ffd_u32, 15_u8},
         97_u8 => {0x3_u32, 5_u8},
         98_u8 => {0x23_u32, 6_u8},
         99_u8 => {0x4_u32, 5_u8},
        100_u8 => {0x24_u32, 6_u8},
        101_u8 => {0x5_u32, 5_u8},
        102_u8 => {0x25_u32, 6_u8},
        103_u8 => {0x26_u32, 6_u8},
        104_u8 => {0x27_u32, 6_u8},
        105_u8 => {0x6_u32, 5_u8},
        106_u8 => {0x74_u32, 7_u8},
        107_u8 => {0x75_u32, 7_u8},
        108_u8 => {0x28_u32, 6_u8},
        109_u8 => {0x29_u32, 6_u8},
        110_u8 => {0x2a_u32, 6_u8},
        111_u8 => {0x7_u32, 5_u8},
        112_u8 => {0x2b_u32, 6_u8},
        113_u8 => {0x76_u32, 7_u8},
        114_u8 => {0x2c_u32, 6_u8},
        115_u8 => {0x8_u32, 5_u8},
        116_u8 => {0x9_u32, 5_u8},
        117_u8 => {0x2d_u32, 6_u8},
        118_u8 => {0x77_u32, 7_u8},
        119_u8 => {0x78_u32, 7_u8},
        120_u8 => {0x79_u32, 7_u8},
        121_u8 => {0x7a_u32, 7_u8},
        122_u8 => {0x7b_u32, 7_u8},
        123_u8 => {0x7ffe_u32, 15_u8},
        124_u8 => {0x7fc_u32, 11_u8},
        125_u8 => {0x3ffd_u32, 14_u8},
        126_u8 => {0x1ffd_u32, 13_u8},
        127_u8 => {0xffffffc_u32, 28_u8},
        128_u8 => {0xfffe6_u32, 20_u8},
        129_u8 => {0x3fffd2_u32, 22_u8},
        130_u8 => {0xfffe7_u32, 20_u8},
        131_u8 => {0xfffe8_u32, 20_u8},
        132_u8 => {0x3fffd3_u32, 22_u8},
        133_u8 => {0x3fffd4_u32, 22_u8},
        134_u8 => {0x3fffd5_u32, 22_u8},
        135_u8 => {0x7fffd9_u32, 23_u8},
        136_u8 => {0x3fffd6_u32, 22_u8},
        137_u8 => {0x7fffda_u32, 23_u8},
        138_u8 => {0x7fffdb_u32, 23_u8},
        139_u8 => {0x7fffdc_u32, 23_u8},
        140_u8 => {0x7fffdd_u32, 23_u8},
        141_u8 => {0x7fffde_u32, 23_u8},
        142_u8 => {0xffffeb_u32, 24_u8},
        143_u8 => {0x7fffdf_u32, 23_u8},
        144_u8 => {0xffffec_u32, 24_u8},
        145_u8 => {0xffffed_u32, 24_u8},
        146_u8 => {0x3fffd7_u32, 22_u8},
        147_u8 => {0x7fffe0_u32, 23_u8},
        148_u8 => {0xffffee_u32, 24_u8},
        149_u8 => {0x7fffe1_u32, 23_u8},
        150_u8 => {0x7fffe2_u32, 23_u8},
        151_u8 => {0x7fffe3_u32, 23_u8},
        152_u8 => {0x7fffe4_u32, 23_u8},
        153_u8 => {0x1fffdc_u32, 21_u8},
        154_u8 => {0x3fffd8_u32, 22_u8},
        155_u8 => {0x7fffe5_u32, 23_u8},
        156_u8 => {0x3fffd9_u32, 22_u8},
        157_u8 => {0x7fffe6_u32, 23_u8},
        158_u8 => {0x7fffe7_u32, 23_u8},
        159_u8 => {0xffffef_u32, 24_u8},
        160_u8 => {0x3fffda_u32, 22_u8},
        161_u8 => {0x1fffdd_u32, 21_u8},
        162_u8 => {0xfffe9_u32, 20_u8},
        163_u8 => {0x3fffdb_u32, 22_u8},
        164_u8 => {0x3fffdc_u32, 22_u8},
        165_u8 => {0x7fffe8_u32, 23_u8},
        166_u8 => {0x7fffe9_u32, 23_u8},
        167_u8 => {0x1fffde_u32, 21_u8},
        168_u8 => {0x7fffea_u32, 23_u8},
        169_u8 => {0x3fffdd_u32, 22_u8},
        170_u8 => {0x3fffde_u32, 22_u8},
        171_u8 => {0xfffff0_u32, 24_u8},
        172_u8 => {0x1fffdf_u32, 21_u8},
        173_u8 => {0x3fffdf_u32, 22_u8},
        174_u8 => {0x7fffeb_u32, 23_u8},
        175_u8 => {0x7fffec_u32, 23_u8},
        176_u8 => {0x1fffe0_u32, 21_u8},
        177_u8 => {0x1fffe1_u32, 21_u8},
        178_u8 => {0x3fffe0_u32, 22_u8},
        179_u8 => {0x1fffe2_u32, 21_u8},
        180_u8 => {0x7fffed_u32, 23_u8},
        181_u8 => {0x3fffe1_u32, 22_u8},
        182_u8 => {0x7fffee_u32, 23_u8},
        183_u8 => {0x7fffef_u32, 23_u8},
        184_u8 => {0xfffea_u32, 20_u8},
        185_u8 => {0x3fffe2_u32, 22_u8},
        186_u8 => {0x3fffe3_u32, 22_u8},
        187_u8 => {0x3fffe4_u32, 22_u8},
        188_u8 => {0x7ffff0_u32, 23_u8},
        189_u8 => {0x3fffe5_u32, 22_u8},
        190_u8 => {0x3fffe6_u32, 22_u8},
        191_u8 => {0x7ffff1_u32, 23_u8},
        192_u8 => {0x3ffffe0_u32, 26_u8},
        193_u8 => {0x3ffffe1_u32, 26_u8},
        194_u8 => {0xfffeb_u32, 20_u8},
        195_u8 => {0x7fff1_u32, 19_u8},
        196_u8 => {0x3fffe7_u32, 22_u8},
        197_u8 => {0x7ffff2_u32, 23_u8},
        198_u8 => {0x3fffe8_u32, 22_u8},
        199_u8 => {0x1ffffec_u32, 25_u8},
        200_u8 => {0x3ffffe2_u32, 26_u8},
        201_u8 => {0x3ffffe3_u32, 26_u8},
        202_u8 => {0x3ffffe4_u32, 26_u8},
        203_u8 => {0x7ffffde_u32, 27_u8},
        204_u8 => {0x7ffffdf_u32, 27_u8},
        205_u8 => {0x3ffffe5_u32, 26_u8},
        206_u8 => {0xfffff1_u32, 24_u8},
        207_u8 => {0x1ffffed_u32, 25_u8},
        208_u8 => {0x7fff2_u32, 19_u8},
        209_u8 => {0x1fffe3_u32, 21_u8},
        210_u8 => {0x3ffffe6_u32, 26_u8},
        211_u8 => {0x7ffffe0_u32, 27_u8},
        212_u8 => {0x7ffffe1_u32, 27_u8},
        213_u8 => {0x3ffffe7_u32, 26_u8},
        214_u8 => {0x7ffffe2_u32, 27_u8},
        215_u8 => {0xfffff2_u32, 24_u8},
        216_u8 => {0x1fffe4_u32, 21_u8},
        217_u8 => {0x1fffe5_u32, 21_u8},
        218_u8 => {0x3ffffe8_u32, 26_u8},
        219_u8 => {0x3ffffe9_u32, 26_u8},
        220_u8 => {0xffffffd_u32, 28_u8},
        221_u8 => {0x7ffffe3_u32, 27_u8},
        222_u8 => {0x7ffffe4_u32, 27_u8},
        223_u8 => {0x7ffffe5_u32, 27_u8},
        224_u8 => {0xfffec_u32, 20_u8},
        225_u8 => {0xfffff3_u32, 24_u8},
        226_u8 => {0xfffed_u32, 20_u8},
        227_u8 => {0x1fffe6_u32, 21_u8},
        228_u8 => {0x3fffe9_u32, 22_u8},
        229_u8 => {0x1fffe7_u32, 21_u8},
        230_u8 => {0x1fffe8_u32, 21_u8},
        231_u8 => {0x7ffff3_u32, 23_u8},
        232_u8 => {0x3fffea_u32, 22_u8},
        233_u8 => {0x3fffeb_u32, 22_u8},
        234_u8 => {0x1ffffee_u32, 25_u8},
        235_u8 => {0x1ffffef_u32, 25_u8},
        236_u8 => {0xfffff4_u32, 24_u8},
        237_u8 => {0xfffff5_u32, 24_u8},
        238_u8 => {0x3ffffea_u32, 26_u8},
        239_u8 => {0x7ffff4_u32, 23_u8},
        240_u8 => {0x3ffffeb_u32, 26_u8},
        241_u8 => {0x7ffffe6_u32, 27_u8},
        242_u8 => {0x3ffffec_u32, 26_u8},
        243_u8 => {0x3ffffed_u32, 26_u8},
        244_u8 => {0x7ffffe7_u32, 27_u8},
        245_u8 => {0x7ffffe8_u32, 27_u8},
        246_u8 => {0x7ffffe9_u32, 27_u8},
        247_u8 => {0x7ffffea_u32, 27_u8},
        248_u8 => {0x7ffffeb_u32, 27_u8},
        249_u8 => {0xffffffe_u32, 28_u8},
        250_u8 => {0x7ffffec_u32, 27_u8},
        251_u8 => {0x7ffffed_u32, 27_u8},
        252_u8 => {0x7ffffee_u32, 27_u8},
        253_u8 => {0x7ffffef_u32, 27_u8},
        254_u8 => {0x7fffff0_u32, 27_u8},
        255_u8 => {0x3ffffee_u32, 26_u8},
      }
    end
  end
end
