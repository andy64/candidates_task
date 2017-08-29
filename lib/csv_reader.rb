require 'row'

module CSVOperations
  module CSVReader
    def read(file)
      CSV.read(file, {:col_sep => ';', :headers => true, :skip_blanks => true}).map do |r|
        Row.new(r.to_hash)
      end
    end

    def convert_acsii(str)
      #  Iconv.iconv('ascii//translit', 'utf-8', str).to_s.gsub(/[^\w^\s]/, '')
      str.encode("ascii//translit", :invalid => :replace, :undef => :replace, :replace => '').gsub(/[^\w^\s]/, '')
  end
end