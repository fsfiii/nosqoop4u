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

    load_driver
    connect
    hack_jdbc
  end

  def hack_jdbc
    case @db_url
    when /jdbc:mysql:/
      # by default, the mysql jdbc driver will read the entire table
      # into memory ... this will change to only one row at a time
      @stmt = @conn.create_statement java.sql.ResultSet.TYPE_FORWARD_ONLY,
        java.sql.ResultSet.CONCUR_READ_ONLY
      @stmt.fetch_size = java.lang.Integer.const_get 'MIN_VALUE'
      # handle 0000-00-00 timestamps without an exception, lulz
      @db_url << '?zeroDateTimeBehavior=round' if @db_url !~
        /zeroDateTimeBehavior/
    when /jdbc:postgresql:/
      @conn.set_auto_commit false
      @stmt = @conn.create_statement
      @stmt.fetch_size = 50
    else
      @stmt = @conn.create_statement
    end
  end

  def load_driver
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
  end

  def connect
    @conn = java.sql.DriverManager.get_connection(@db_url, @db_user, @db_pass)
  end

  def table_info r
    meta = r.meta_data
    cols = meta.column_count
    colnames = []
    cols.times do |i|
      colnames[i] = meta.column_name(i+1)
    end

    {:cols => cols, :colnames => colnames}
  end
  private :table_info

  def query sql, opts = {}
    output = opts[:output] || STDOUT
    delim  = opts[:delim] || "\001"
    first  = true
    recs   = 0
    bytes  = 0
    s = ''

    begin_ts = Time.now.to_i

    res = @stmt.execute_query sql
    tbl = table_info res

    while res.next do
      tbl[:cols].times do |i|
        data = res.get_string(i+1)
        s << delim if not first
        s << data if data
        first = false
      end
      output.puts s
      bytes  += s.length
      recs +=1
      s = ''
      if recs % 10000 == 0
        end_ts = Time.now.to_i
        mb_out = bytes  / 1024 / 1024
        elapsed = end_ts - begin_ts
        elapsed = 1 if elapsed < 1
        rate   = mb_out / elapsed.to_f
        rate_r = recs / elapsed
        puts "#{recs} records (#{rate_r} recs/s), #{mb_out}MB (%.02f MB/s)" %
          rate
      end
    end
    end_ts = Time.now.to_i
    mb_out = bytes  / 1024 / 1024
    elapsed = end_ts - begin_ts
    elapsed = 1 if elapsed < 1
    rate   = mb_out / elapsed.to_f
    rate_r = recs / elapsed
    puts
    puts "= total time: #{elapsed} seconds"
    puts "= records:    #{recs} records #{rate_r} recs/s"
    puts "= data size:  #{mb_out}MB (%.02f MB/s)" % rate
  end
end

def hdfs_open_write filename
  c = org.apache.hadoop.conf.Configuration.new
  u = java.net.URI.create filename
  p = org.apache.hadoop.fs.Path.new u
  f = org.apache.hadoop.fs.FileSystem.get u, c

  o = f.create p

  def o.puts s
    s = "#{s}\n" if s.to_s[-1].chr != "\n"
    self.write_bytes s
  end

  return o if not block_given?

  yield o
  o.close
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

case output
when '-' # STDOUT
  ns.query sql, opts
when /^hdfs:/
  hdfs_open_write(output) {|f| opts[:output] = f ; ns.query sql, opts}
else     # unix file path with or without leading file://
  output.sub!(%r|^file://|, '')
  File.open(output, 'w') {|f| opts[:output] = f ; ns.query sql, opts}
end
