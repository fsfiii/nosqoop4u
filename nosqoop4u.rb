#!/usr/bin/env jruby

require 'java'
require 'rubygems'
require 'getoptlong'

def usage
  puts <<-EOF
usage: #$0 options
  -h, --help
  -o, --output      # output file (hdfs://, file://, - for stdout)
  -c, --connect url # jdbc connection url (env NS4U_URL)
  -u, --user        # db username         (env NS4U_USER)
  -p, --pass        # db password         (env NS4U_PASS)
  -e, --query       # sql query to run
  -F, --delim       # delimiter (default: ^A)
EOF
end

class NoSqoop
  def initialize cfg
    @db_user = cfg[:db_user] || ENV['NS4U_USER']
    @db_pass = cfg[:db_pass] || ENV['NS4U_PASS']
    @db_url  = cfg[:db_url]  || ENV['NS4U_URL']

    case @db_url
      when /jdbc:mysql:/
        Java::com.mysql.jdbc.Driver
      when /jdbc:oracle:/
        Java::oracle.jdbc.OracleDriver
      when /jdbc:postgresql:/
        Java::org.postgresql.Driver
      else
        raise "error: unknown database type"
    end

    @conn = java.sql.DriverManager.get_connection(@db_url, @db_user, @db_pass)

    case @db_url
      when /jdbc:mysql:/
        # by default, the mysql jdbc driver will read the entire table
        # into memory ... this will cause only one row at a time
        @stmt = @conn.create_statement java.sql.ResultSet.TYPE_FORWARD_ONLY,
          java.sql.ResultSet.CONCUR_READ_ONLY
        @stmt.set_fetch_size java.lang.Integer.const_get 'MIN_VALUE'
      else
        @stmt = @conn.create_statement
    end
  end

  def table_info r
    meta = r.getMetaData
    cols = meta.getColumnCount
    colnames = []
    cols.times do |i|
      colnames[i] = meta.getColumnName(i+1)
    end

    {:cols => cols, :colnames => colnames}
  end
  private :table_info

  def query sql, opts = {}
    output = opts[:output] || STDOUT
    delim  = opts[:delim] || "\001"

    res = @stmt.execute_query sql
    tbl = table_info res
    while res.next do
      tbl[:cols].times do |i|
        data = res.getString(i+1)
        output.print "#{data}#{delim}"
      end
      output.puts
    end
  end
end

# main

opts = {}
output = '-'
sql = nil

gopts = GetoptLong.new(
  [ '--output',  '-o', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--connect', '-c', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--user',    '-u', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--pass',    '-p', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--query',   '-e', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--delim',   '-F', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--help',    '-h', GetoptLong::NO_ARGUMENT ]
)

gopts.each do |opt, arg|
  case opt
    when '--output'
      output = arg
    when '--connect'
      opts[:db_url] = arg
    when '--user'
      opts[:db_user] = arg
    when '--pass'
      opts[:db_pass] = arg
    when '--delim'
      opts[:delim] = arg
    when '--query'
      sql = arg
    when '--help'
      usage
      exit
  end
end

if opts[:db_url].nil? or opts[:db_user].nil? or opts[:db_pass].nil? \
  or sql.nil?
  usage
  exit 1
end

ns = NoSqoop.new opts

#File.open('/tmp/nsout.txt', 'w') {|f| ns.query sql, f}
ns.query sql, opts
