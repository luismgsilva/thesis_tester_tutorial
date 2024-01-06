#!/usr/bin/env ruby
require 'json'

def parsing_gcc(str)
  config = {}
  name = $1 if str =~ /COLLECT_GCC=(.+)/ 
  if str =~ /gcc version ([0-9.]+) ([0-9.]+)/
    config[:build_version] = $1
    config[:build_date] = $2
  end
  puts JSON.pretty_generate({ name || "gcc" => config })
end

def parsing_nsim(str)
  config = {}
  if str =~ /Version: (.+)/
    config[:build_version] = $1
  end
  puts JSON.pretty_generate( { "nsim" => config } )
end

def parsing_qemu(str)
  config = {}
  if str =~ /version ([0-9.]+)/
    config[:build_version] = $1
  end
  puts JSON.pretty_generate( { "qemu" => config } )
end

def parsing_dejagnu(str)
  config = {}
  str = str.gsub("\t", " ")
  str = str.gsub("\n", " | ")
  config[:build_version] = str
  puts JSON.pretty_generate( { "dejagnu" => config } )
end

def option_parser(argv)
  options = {}

  while argv.any?
    opt = argv.shift
    case opt
    when "-h", "--help"
      abort("Usage: ruby script_name.rb <target> <version>")
    else
      options[:target]  = opt
      options[:version] = argv.shift
    end
  end
  return options
end

def main(argc, argv)
  if argc < 2
    abort("Usage: ruby script_name.rb <target> <version>")
  end
  options = option_parser(argv)
  case options[:target]
  when "gcc"
    parsing_gcc(options[:version])
  when "nsim"
    parsing_nsim(options[:version])
  when "qemu"
    parsing_qemu(options[:version])
  when "dejagnu"
    parsing_dejagnu(options[:version])
  else
    abort("Supported targets: <gcc>, <nsim>, <qemu>, <dejagnu>")
  end
end

if __FILE__ == $PROGRAM_NAME
  main(ARGV.length, ARGV)
end

