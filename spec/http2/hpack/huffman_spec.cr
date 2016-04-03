require "../../spec_helper"

describe HTTP2::HPACK::Huffman do
  it "encodes end decodes random bytes correctly" do
    hm = HTTP2::HPACK::Huffman.new(HTTP2::HPACK::Huffman::TABLE)
    slice = Slice(UInt8).new(1000) { |i| Random.rand(256).to_u8 }
    hm.decode(hm.encode(slice)).should eq slice
  end

  it "raises on padding with wrong bits" do
    hm = HTTP2::HPACK::Huffman.new(HTTP2::HPACK::Huffman::TABLE)
    data = [0xf1, 0xe3, 0xc2, 0xe5, 0xf2, 0x3a, 0x6b, 0xa0, 0xab, 0x90, 0xf4, 0xaa]
    slice = Slice(UInt8).new(data.size) { |i| data[i].to_u8 }
    expect_raises(HTTP2::HPACK::Huffman::DecodingError) do
      hm.decode(slice)
    end
  end

  it "raises on padding longer than 7 bits" do
    hm = HTTP2::HPACK::Huffman.new(HTTP2::HPACK::Huffman::TABLE)
    data = [0xf1, 0xe3, 0xc2, 0xe5, 0xf2, 0x3a, 0x6b, 0xa0, 0xab, 0x90, 0xf4, 0xff, 0xff]
    slice = Slice(UInt8).new(data.size) { |i| data[i].to_u8 }
    expect_raises(HTTP2::HPACK::Huffman::DecodingError) do
      hm.decode(slice)
    end
  end
end
