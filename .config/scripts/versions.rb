require 'json'
DEBUG = false

def debug(str)
  p (str)
end

def make_absolute_path(path)
  if File.absolute_path?(path)
    return path
  else
    return File.expand_path(path)
  end
end

def validate_path(path)
  absolute_path = make_absolute_path(path)
  if !Dir.exists?(absolute_path)
    abort("#{path} directory does not exist.")
  end
  return absolute_path
end
def validate_file(path)
  absolute_path = make_absolute_path(path)
  if !File.exists?(absolute_path)
    abort("#{path} file does not exist.")
  end
  return absolute_path
end

def traverse_directory(options, directory, arr)
  paths = []
  Dir.foreach(directory) do |entry|
    next if entry == "." || entry == ".."
    next if entry == options[:ignore_glibc]
    next if entry == options[:ignore_newlib]

    entry_path = File.join(directory, entry)
    if File.exists?("#{entry_path}/.git")
      if !arr.map {|path| File.basename(path) }.include?(entry)  
        paths << entry_path
      end
    end
  end

  return paths
end

def write_content_to_file(content, file_path)
  File.open(file_path, "w") do |file|
    file.write(content)
  end
end


def retrieve_toolchain_paths(options, config_log)
  arr = []
  configure   = `head #{config_log} | grep '\s$\s'`.chomp
  source_path = configure.scan(/\$\s(.*?)configure/).flatten
    
  if !File.absolute_path?(source_path.first)
    source_path = File.join(File.dirname(config_log), source_path.first)
  else
    source_path = source_path.first
  end

  arr << validate_path(source_path)
  arr.concat(configure.scan(/--with-\w+-src=([^\s]+)/).flatten)
  configure = configure.gsub(/^\s*\$\s*/,"")

  if !options[:ignore_parent]

    parent_path = options[:parent] || arr[0]
    parent_path = validate_path(parent_path)
    arr = arr + traverse_directory(options, parent_path, arr)
  end

  return arr, configure
end

def retrieve_qemu_paths(options, config_log)
  arr = []
  configure   = `head #{config_log} | grep '#\sConfigured\swith:\s'`.chomp
  source_path = configure.scan(/\#\sConfigured\swith:\s'(.*?)configure/).flatten
    
  if !File.absolute_path?(source_path.first)
    source_path = File.join(File.dirname(config_log), source_path.first)
  else
    source_path = source_path.first
  end
    
  arr << validate_path(source_path)
  configure = configure.gsub(/^\s*\#\sConfigured\swith:\s*/,"")

  return arr, configure
end

def retrieve_repository_information(options)

  arr = []
  repo_info = {}

  if options[:config_file]
    config_log = validate_file(options[:config_file])
    if `cat #{config_log}` =~ /QEMU configure/
      arr, repo_info[:configure] = retrieve_qemu_paths(options, config_log)
      build_name = options[:build_name] || File.basename(arr[0])
    else
      arr, repo_info[:configure] = retrieve_toolchain_paths(options, config_log)
      build_name = options[:build_name] || File.basename(arr[0])
    end
  elsif options[:parent]
    arr << validate_path(options[:parent])
    build_name = options[:build_name] || File.basename(arr[0])
  else
    help()
  end


  repo_info[:build_data] = `date +"%Y-%m-%d %T"`.chomp
  arr.each do |path|
    debug(path) if DEBUG
    git_output = `git -C #{path} remote -v`
    repo_url   = git_output.lines.first[/origin\s+(\S+)\s+\(fetch\)/ || "", 1]
    git_branch = `git -C #{path} rev-parse --abbrev-ref HEAD`.strip
    git_hash   = `git -C #{path} rev-parse HEAD`.strip
    git_patch  = `git -C #{path} diff`

    repo_info[File.basename(path)] = { 
      repository: repo_url,
      branch: git_branch,
      hash: git_hash,
      patch: !git_patch.empty?
    }
    
    if options[:output_patch]
      output_patch = "#{validate_path(options[:output_patch])}/#{File.basename(path)}.patch"
      write_content_to_file(git_patch, output_patch)
    end
  end

  puts JSON.pretty_generate({ "#{build_name}": repo_info })
end

def help()
  puts <<-EOF

Usage: ruby <script_name.rb> [options...]
  
Global options:
  -h  | --help                   Print usage and exit.

  -f  | --config-file            Specify config log file.

  -p  | --parent                 Specify sources' parent directory.
                                   (Otherwise main repository path is used)

  -n  | --name                   Specify build name. (Otherwise base name is used)

  -op | --output-patch           Specify output path to patches.

  -ip | --ignore-parent          Ignore sources' parent directory.

  -newlib | --ignore-glibc       Ignore glibc source

  -glibc  | --ignore-newlib      Ignore newlib source
  EOF
  exit()
end

def option_parser(argv)
  options = {}
  
  while argv.any?
    case argv.shift
    when "-f", "--config-file"
      options[:config_file] = argv.shift
    when "-p", "--parent"
      options[:parent] = argv.shift
    when "-n", "--name"
      options[:build_name] = argv.shift
    when "-op", "--output-patch"
      options[:output_patch] = argv.shift
    when "-ip", "--ignore-parent"
      options[:ignore_parent] = "--ignore-parent"
    when "-glibc", "--ignore-newlib"
      options[:ignore_newlib] = "newlib"
    when "-newlib", "--ignore-glibc"
      options[:ignore_newlib] = "glibc"
    when "-h", "--help"
      help()
    else
      help()
    end
  end
  
  return options
end

def main(argc, argv)
  if argc < 1
    help()
  end
  options = option_parser(argv)
  retrieve_repository_information(options)
end

if __FILE__ == $PROGRAM_NAME
  main(ARGV.length, ARGV)
end


