require 'row'
require 'stringex/unidecoder'

module CSVOperations
  module CSVReader
    def read(file)
      CSV.read(file, {:col_sep => ';', :headers => true, :skip_blanks => true}).map do |r|
        Row.new(r.to_hash)
      end
    end

    def self.convert_acsii(str)
      #  Iconv.iconv('ascii//translit', 'utf-8', str).to_s.gsub(/[^\w^\s]/, '')
      Stringex::Unidecoder.decode(str)
    end
  end
end