#  tc_Flate.rb

require 'test/unit'
require 'Flate'

class TestFlate < Test::Unit::TestCase

  def make_data(size = 10000) 
    srand # intitialize the random seed...
    data = ""
    i = 0
    while i < size
      # not efficicent, but this will have to do ;-) !
      data += [rand(256)].pack("C")
      i += 1
    end
    return data
  end

  def test_compression_decompression
    data = make_data
    data_compressed = Flate.compress(data)
    data_second = Flate.expand(data_compressed)
    assert_equal(data_second, data)
  end

end



















