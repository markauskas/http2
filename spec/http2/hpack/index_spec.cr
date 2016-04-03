require "../../spec_helper"

describe HTTP2::HPACK::Index do
  describe "#add" do
    it "works" do
      index = HTTP2::HPACK::Index.new
      index.bytesize.should eq 0
      index.size.should eq 61

      index.add ":authority", "www.example.com"
      index.size.should eq 62
      index.bytesize.should eq 57
      index.index_of(":authority", "www.example.com").should eq 62
      index.index_of([":authority", "www.example.com"]).should eq 62
    end

    pending "it evicts oldest entries when needed" do
      # TODO
    end
  end
end
