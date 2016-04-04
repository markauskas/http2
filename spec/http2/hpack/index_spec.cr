require "../../spec_helper"

describe HTTP2::HPACK::Index do
  describe "#add" do
    it "works" do
      index = HTTP2::HPACK::Index.new(4096)
      index.bytesize.should eq 0
      index.size.should eq 61

      index.add ":authority", "www.example.com"
      index.size.should eq 62
      index.bytesize.should eq 57
      index.index_of(":authority", "www.example.com").should eq 62
      index.index_of([":authority", "www.example.com"]).should eq 62
    end

    it "it evicts oldest entries when needed" do
      index = HTTP2::HPACK::Index.new(80)

      index.add(["aa", "aa"])
      index.size.should eq 62
      index.bytesize.should eq 36

      index.add(["bb", "bb"])
      index.size.should eq 63
      index.bytesize.should eq 72

      index.add(["cc", "cc"])
      index.size.should eq 63
      index.bytesize.should eq 72

      index.add(["dddddddd", "dddddddd"])
      index.size.should eq 62
      index.bytesize.should eq 48
    end

    it "it leaves the table empty after attempting to add an entry larger than max_table_size" do
      index = HTTP2::HPACK::Index.new(80)

      index.add(["aa", "aa"])
      index.size.should eq 62
      index.bytesize.should eq 36

      index.add(["bb", "bb"])
      index.size.should eq 63
      index.bytesize.should eq 72

      index.add(["cccccccc", "0123456789012345678901234567890123456789012345"])
      index.size.should eq 61
      index.bytesize.should eq 0
    end
  end
end
