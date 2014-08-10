#!/usr/bin/ruby

require 'json'
require 'psych'
require 'yaml'

# usage:
#   whiz.rb verb args
#   whiz.rb parse_hw '{"in_file":"foo.yaml","out_file":"bar.json","book":"lm"}'
# args are normally a JSON structure, surrounded by ''

$label_to_num = {}

def fatal_error(message)
  $stderr.print "whiz.rb: fatal error: #{message}\n"
  exit(-1)
end


def parse_json_or_die(json)
  begin
    return JSON.parse(json)
  rescue JSON::ParserError
    fatal_error("syntax error in JSON string '#{json}'")
  end
end

# This can read either JSON or YAML (since JSON is a subset of YAML).
def get_yaml_data_from_file(file)
  parsed = begin
    YAML.load(File.open(file))
  rescue ArgumentError => e
    fatal_error("invalid YAML syntax in file #{file}")
  end
  return parsed
end

# returns contents or nil on error; for more detailed error reporting, see slurp_file_with_detailed_error_reporting()
def slurp_file(file)
  x = slurp_file_with_detailed_error_reporting(file)
  return x[0]
end

# returns [contents,nil] normally [nil,error message] otherwise
def slurp_file_with_detailed_error_reporting(file)
  begin
    File.open(file,'r') { |f|
      t = f.gets(nil) # nil means read whole file
      if t.nil? then t='' end # gets returns nil at EOF, which means it returns nil if file is empty
      return [t,nil]
    }
  rescue
    return [nil,"Error opening file #{file} for input: #{$!}."]
  end
end

# This can read either JSON or YAML (since JSON is a subset of YAML).
def get_yaml_data_from_file_or_die(file)
  parsed = begin
    YAML.load(File.open(file))
  rescue ArgumentError => e
    fatal_error("invalid YAML syntax in file #{file}")
  end
  return parsed
end

################################################################################################

def read_problems_csv(book)
  File.readlines(find_problems_csv(book)).each { |line|
    if line=~/(.*),(.*),(.*),(.*),(.*)/ then
      b,ch,num,label,soln = [$1,$2,$3,$4,$5]
      if b==book then
        $label_to_num[label] = [ch,num]
      end
   end
  }
end

def find_problems_csv(book)
  problems_csv = '/home/bcrowell/Documents/writing/books/physics/data/problems.csv'
  if book=='fund' then problems_csv = '/home/bcrowell/Documents/writing/books/fund/problems.csv' end
  return problems_csv
end

################################################################################################

def parse_hw_chunk(chunk)
  result = []
  chunk.gsub(/\s+/,'').split(/;/).each { |g|
    flags = {}
    if g=~/(.*):(.*)/ then
      f,g = [$1,$2]
      f.split('').each {|c| flags[c]=true }
    end
    g = g.split(/,/).map {|x| x.split(/\|/)}
    g.each { |a|
      a.map! { |b|
        parts = nil
        if b=~/(.*)\/(.*)/ then
          b,parts = [$1,$2]
        end
        if $label_to_num.has_key?(b) then 
          b=$label_to_num[b] 
        else
          $stderr.print "warning: name #{b} not found in problems.csv\n"
        end
        if !(parts.nil?) then b=b+"/"+parts end
        b
      }
    }
    result.push([flags,g])
  }
  return result
end

def parse_hw_stream(stream)
  stream['chunks'].map! { |chunk|
    parse_hw_chunk(chunk) # modifies the contents of the data structure, since this is by reference
  }
  return stream
end

def parse_hw(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  a = get_yaml_data_from_file_or_die(args['in_file'])
  b = a.clone

  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  read_problems_csv(book)

  b.map! { |stream|
    parse_hw_stream(stream)
  }

  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end
  File.open(args['out_file'],'w') { |f|
    f.print JSON.pretty_generate(b)
  }
end

################################################################################################


if ARGV.length!=2 then
  fatal_error("illegal arguments: #{ARGV.join(' ')}\nThere should be 2 arguments.\nusage:\n  whiz.rb verb 'json_args'")
end
$verb = ARGV[0]
$args = parse_json_or_die(ARGV[1])

if $verb=="parse_hw" then parse_hw($args); exit(0) end
fatal_error("unrecognized verb: $verb")
