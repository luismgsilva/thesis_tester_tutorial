require 'terminal-table'
require 'json'

require_relative "#{__FILE__}/../lib/table.rb"
require_relative "#{__FILE__}/../lib/rules.rb"

FAILING_SENARIOS = ["FAIL", "UNSUPPORTED", "XPASS", "UNRESOLVED"]
PASSING_SENARIOS = ["PASS", "XFAIL"]
@filters = {}
def parse_sum(filename)
  # valid_results = ['PASS', 'FAIL', 'XFAIL', 'XPASS', 'UNRESOLVED', 'UNSUPPORTED']
  valid_results = FAILING_SENARIOS + PASSING_SENARIOS
  content = File.read(filename)
  data = {}
  content.each_line do |l|
    if(l =~ /([A-Z]+): (.+)/)
      if(data[$2] == nil)
        data[$2] = $1 if(valid_results.include?($1))
      elsif(valid_results.include?($1))
        count = 1
        tmp = "#{$2} (#{count})"
        while(data[tmp] != nil)
          count += 1
          tmp = "#{$2} (#{count})"
        end
        data[tmp] = data[$2] = $1
      end
    end
  end
  return data
end



@ret = {
  changes: {
    new_fail: {},
    new_pass: {},
    add_test: {},
    rem_test: {}
    },

  baseline_results: {
    pass: 0,
    fail: 0,
    not_considered: 0
  },
  results: {
    pass: 0,
    fail: 0,
    not_considered: 0
  },
  results_delta: {
    new_fail: 0,
    new_pass: 0,
    add_test: 0,
    rem_test: 0
  },
  filtered_results: {
    changes: {
      new_fail: {},
      new_pass: {},
      add_test: {},
      rem_test: {}
      },
    new_fail: 0,
    new_pass: 0,
    add_test: 0,
    rem_test: 0
  },
  files: {}
}


def analyse_test(test, r1, r2, filter)
  entry = nil

  filter["known_to_fail"] = filter["known_to_fail"] || {}
  filter["flacky_tests"] = filter["flacky_tests"] || {}
  filter["filter_out"] = {} unless filter["filter_out"]
  filter_report = filter["filter_out"][test]
  reason_filter = ""
  reason_filter += filter["filter_out"][test].to_s if filter["filter_out"]
  reason_filter += filter["comments"][test].to_s if filter["comments"]

  if(filter_report)
    changes_dict = @ret[:filtered_results][:changes]
    count_dict = @ret[:filtered_results]
  else
    changes_dict = @ret[:changes]
    count_dict = @ret[:results_delta]
  end

  if(r1 != nil)
    @ret[:baseline_results][:pass] += 1 if (PASSING_SENARIOS.include?(r1))
    @ret[:baseline_results][:fail] += 1 if (FAILING_SENARIOS.include?(r1))
    @ret[:baseline_results][:not_considered] += 1 if ((!PASSING_SENARIOS.include?(r1) && !FAILING_SENARIOS.include?(r1)))
    puts "#{test} = OTHER #{r1}" unless (PASSING_SENARIOS.include?(r1) || FAILING_SENARIOS.include?(r1))
  end
  if(r2 != nil)
    @ret[:results][:pass] += 1 if (PASSING_SENARIOS.include?(r2))
    @ret[:results][:fail] += 1 if (FAILING_SENARIOS.include?(r2))
    @ret[:baseline_results][:not_considered] += 1 if ((!PASSING_SENARIOS.include?(r2) && !FAILING_SENARIOS.include?(r2)))
    puts "#{test} = OTHER #{r1}" unless (PASSING_SENARIOS.include?(r2) || FAILING_SENARIOS.include?(r2))
  end

  if(r2 == nil && r1 != nil)
    puts "REM_TEST: #{test}    (#{r1} => (null))" if @enable_logging
    changes_dict[:rem_test][test] = { before: r1, after: "(null)", comments: reason_filter }
    count_dict[:rem_test] += 1
  elsif(r1 == nil && r2 != nil)
    puts "ADD_TEST: #{test}   ((null) => #{r2})" if @enable_logging
    changes_dict[:add_test][test] = { before: "(null)", after: r2, comments: reason_filter }
    count_dict[:add_test] += 1
  end

  if((r1 == 'FAIL' || r1 == 'UNRESOLVED' || r1 == nil) && r2 == 'PASS')
    puts "NEWLY_PASS: #{test}   (#{r1} => #{r2})" if @enable_logging
    changes_dict[:new_pass][test] = { before: r1 || "(null)", after: r2, comments: reason_filter }
    count_dict[:new_pass] += 1
  elsif((r1 == 'PASS' || r1 == nil) && (r2 == 'FAIL' || r2 == 'UNRESOLVED'))
    puts "NEWLY_FAIL: #{test}   (#{r1} => #{r2})" if @enable_logging
    changes_dict[:new_fail][test] = { before: r1 || "(null)", after: r2, comments: reason_filter }
    count_dict[:new_fail] += 1
  elsif(r1 == 'UNSUPPORTED' && r1 != r2)
    puts "ADD_TEST: #{test}   (#{r1} => #{r2})" if @enable_logging
    changes_dict[:add_test][test] = { before: r1, after: r2 || "(null)", comments: reason_filter }
    count_dict[:add_test] += 1
  elsif(r2 == 'UNSUPPORTED' && r1 != r2)
    puts "REM_TEST: #{test}   (#{r1} => #{r2})" if @enable_logging
    changes_dict[:rem_test][test] = { before: r1 || "(null)", after: r2, comments: reason_filter }
    count_dict[:rem_test] += 1
  end
end

def make_absolute_path(path)
  if File.absolute_path?(path)
    return path
  else
    return File.expand_path(path)
  end
end

def main(args)
  file1 = File.join(args[0][:file], @file)
  file2 = File.join(args[1][:file], @file)

  file1 = make_absolute_path(file1)
  file2 = make_absolute_path(file2)

  @ret[:files][args[0][:hash]] = read_results(file1)
  @ret[:files][args[1][:hash]] = read_results(file2)

  data1 = File.exists?(file1) ? parse_sum(file1) : {}
  data2 = File.exists?(file2) ? parse_sum(file2) : {}

  tests1 = data1.keys.sort
  tests2 = data2.keys.sort

  tests_added = tests2 - tests1
  tests_removed = tests1 - tests2

  compare = !data1.empty? && !data2.empty?

  if compare
    (tests1 + tests2).uniq.each do |test|
      if tests_added.include?(test)
        analyse_test(test, nil, data2[test], @filters)
      elsif tests_removed.include?(test)
        analyse_test(test, data1[test], nil, @filters)
      else
        analyse_test(test, data1[test], data2[test], @filters)
      end
    end
  end


  @ret = { @name => @ret }
end

def read_results(sum_file)
  
  return { 
	"PASS" => "ND",
	"FAIL" => "ND",
	"XPASS" => "ND",
	"XFAIL" => "ND",
	"UNRESOLVED" => "ND",
	"UNSUPPORTED" => "ND"
  } if !File.exists? sum_file


  mapping = {
    "expected passes" => "PASS",
    "unexpected failures" => "FAIL",
    "unexpected successes" => "XPASS",
    "expected failures" => "XFAIL",
    "unresolved testcases" => "UNRESOLVED",
    "unsupported tests" => "UNSUPPORTED"
  }

  ret = {}
  `tail -n 100 #{sum_file}`.split("\n").each do |l|
    if (l =~ /^# of/)
      l = l.split(/( |\t)/).select { |a| a != " " && a != "\t" && a != "" }
      name = l[2..-2].join(" ")
      num = l[-1].to_i

      ret[mapping[name]] = num
    end
  end
  return ret
end


def helper()
  puts <<-EOF

Usage: ruby <script_name.rb> [options...]

Global options:
  --help                         Print usage and exit.

  -h  | --hash                   Specify path and hash. (<path>:<hash>)

  -f  | --file                   Specify file name to compare.

  -t  | --target                 Specify target name. (Otherwise "" is used)

  -v  | --verbose                 Enable verbose mode.

  -vv                            Specify verbose filter and enable verbose mode.
                                 ( npass | nfail | atest | rtest | passfail | failpass )

  -o  | --output                  Specify output mode.
                                 ( json | text | html )
  EOF
  exit()
end


if ARGV.length < 1
  helper()
end

include Rules

to_json do |opts|
  main(opts)
  puts JSON.pretty_generate @ret
end

to_text do |opts|
 main(opts)
 data = {}
 table = create_table(@ret, data, opts, @filter)
 puts table
 print_compare(data) if @verbose
end

to_html do |opts|
  main(opts)
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
      @file = opts.shift
    when "-t", "--target"
      @name = opts.shift
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


