unless defined?(RUBY_ENGINE) and RUBY_ENGINE == 'rbx'
  require File.join(File.dirname(__FILE__), '..', 'compiler', 'mri_shim')
end

require 'pp'

# "Interactive" mode
def interactive()
  require 'readline'

  c = Compiler.new(Compiler::TextGenerator)
  puts "Enter ? for help, ^D to exit."

  while code = Readline.readline("rbx:describe> ")
    if code == "?"
      puts "Enter any valid Ruby expression to see its compilation process."
      next
    end

    code = code.to_sexp

    pp code
    puts ""
    puts c.into_script(code).to_description.generator.text
    puts ""
  end

  exit
end

def describe_compiled_method(cm)
  extra = cm.literals.to_a.find_all { |l| l.kind_of? CompiledMethod }

  name = cm.name ? cm.name.inspect : 'anonymous'
  markers = (36 - name.size) / 2
  heading = "#{'=' * markers} #{name} #{'=' * (markers + name.size % 2)}"
  puts heading
  puts "contains #{extra.size} CompiledMethods" unless extra.empty?
  puts "object_id: 0x#{cm.object_id.to_s(16)}"
  puts "total args: #{cm.total_args} required: #{cm.required_args}"
  print " (splatted)" if cm.splat
  puts "stack size: #{cm.stack_size}, local count: #{cm.local_count}"
  puts ""
  puts cm.decode
  puts "-" * 38

  until extra.empty?
    puts ""
    sub = extra.shift
    describe_compiled_method(sub)
    extra += sub.literals.to_a.find_all { |l| l.kind_of? CompiledMethod }
  end
end


if __FILE__ == $0 then
  flags = []
  file = nil

  while arg = ARGV.shift
    case arg
    when /-I(.+)/ then
      other_paths = $1[2..-1].split(":")
      other_paths.each { |n| $:.unshift n }
    when /-f(.+)/ then
      flags << $1
    else
      file = arg
      break
    end
  end

  unless file
    interactive()
    exit 0
  end

  begin
    puts "Enabled flags: #{flags.join(', ')}" unless flags.empty?
    puts "File: #{file}"

    puts "Sexp:"
    pp File.to_sexp(file)

    puts "\nCompiled output:"
    top = Compiler.compile_file(file, flags)
    describe_compiled_method(top)
  rescue SyntaxError
    exit 1
  end
end
