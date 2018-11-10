require_relative 'db_connection'
require 'active_support/inflector'
require "byebug"
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    unless @table
        @table = DBConnection.execute2(<<-SQL)
        SELECT
          *
        FROM
          #{table_name}
      SQL
    end
    @table[0].map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |name|
      define_method(name) do
        attributes[name]
      end

      define_method("#{name}=") do |value|
        attributes[name] = value
      end
    end

  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    table = self.to_s.downcase
    "#{table}s"
  end

  def self.all
      result = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      #{table_name}
    SQL
    parse_all(result)
  end

  def self.parse_all(results)
    arr = []
    results.each do |hash|
      arr << self.new(hash)
    end
    arr
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
    SQL
    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      raise Exception.new("unknown attribute '#{attr_name}'") unless self.class.columns.include?(attr_name)

      self.send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    arr = []
    self.class.columns.each do |col|
      arr << send(col)
    end
    arr
  end

  def insert
    col_names = self.class.columns.join(", ")
    n = self.class.columns.length
    question_mark = (["?"] * n)
    question_mark = question_mark.join(', ')
    attribute_values = self.attribute_values
        DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO #{self.class.table_name} (#{col_names})
      VALUES (#{question_mark});
      SQL
      self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map { |attr_name| "#{attr_name} = ?"}
    set_line = set_line.join(', ')
    attribute_values = self.attribute_values
    attribute_values << self.id
    DBConnection.execute(<<-SQL, *attribute_values)
      UPDATE #{self.class.table_name}
      SET #{set_line}
      WHERE id = ?
    SQL
  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end

end
