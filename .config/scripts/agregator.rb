require 'terminal-table'
require 'json'

require_relative "#{__FILE__}/../lib/table.rb"
require_relative "#{__FILE__}/../lib/rules.rb"

def helper()
  puts <<-EOF

Usage: ruby <script_name.rb> [options...]

Global options:
  --help                         Print usage and exit.

  -h  | --hash                   Specify path and hash. (<path>:<hash>)

  -f  | --file                   Specify file name to compare.

  -v  | --verbose                Enable verbose mode.

  -vv                            Specify verbose filter and enable verbose mode.
                                 ( npass | nfail | atest | rtest | passfail | failpass )

  -o  | --output                 Specify output mode.
                                 ( json | text | html )
  EOF
  exit()
end

if ARGV.length < 1
  helper()
end

include Rules

to_json do |opts| 
  puts JSON.pretty_generate @ret
end

to_text do |opts|
  data = {}
  table = create_table(@ret, data, opts, @filter)
  puts table
  print_compare(data) if @verbose
end

to_html do |opts|
  data = {}
  compare_html = nil
  table = create_table(@ret, data, opts, @filter)
  compare_html = generate_compare_html(data) if @verbose
  table_html = convert_table_html(table, compare_html)
  puts table_html
end

process_opts1 do |opts|
  while opts.any?
    case opts.shift
    when "--help"
      helper()
    when "-f", "--file"
      @ret =JSON.parse(File.read(opts.shift))
    when "-v", "--verbose"
      @verbose = true
    when "-vv"
      tmp = opts.shift
      if !(%w[npass nfail atest rtest passfail failpass] & [tmp]).any?
        abort("ERROR: Option not valid")
      end
      @verbose = true
      @filter ||= []
      @filter << tmp
    end
  end
end

set_default(:text)

execute()
