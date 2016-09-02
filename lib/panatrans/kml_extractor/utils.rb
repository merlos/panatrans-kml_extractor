require 'csv'

module Panatrans
  module KmlExtractor
    module Utils

      # Converts to csv an array
      # it expects all rows to have the same columns
      def self.to_csv(arr, file_path)
        CSV.open(file_path, 'w') do |csv|
          csv << arr[0].keys
          arr.each do |row|
            csv << row.values
          end
        end
      end


    end
  end
end
