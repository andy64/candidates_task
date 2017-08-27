require 'row'
module CSVOperations
  module CSVReader
    def read(file)
      CSV.read(file, {:col_sep => ';', :headers => true, :skip_blanks => true}).map do |r|
        Row.new(r.to_hash)
      end
    end
  end
end