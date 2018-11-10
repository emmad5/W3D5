require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = params.keys.map {|key| "#{key} = ?"}
    where_line = where_line.join(' AND ')
   array = DBConnection.execute(<<-SQL, params.values)
    SELECT
      *
    FROM
      #{table_name}
    WHERE
      #{where_line}
    SQL
    result = []
    array.each do |hash|
      result << self.new(hash)
    end
    result
  end

end

class SQLObject
  extend Searchable
end
