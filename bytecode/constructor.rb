# The Constructor is the highest level piece of taking strings
# of code and creating structures capable of being executed.
require 'sydparse'
require 'bytecode/compiler'
require 'bytecode/encoder'
require 'bytecode/r18'
require 'cpu/simple_marshal'

STDOUT.sync = true

module Bytecode
  class Constructor
    
    def initialize(cpu)
      @cpu = cpu
      @enc = Bytecode::InstructionEncoder.new
      @sm = SimpleMarshal.new
      @newlines = true
    end
    
    attr_accessor :newlines
    
    def convert_to_sexp(code)
      o = GC.disable
      if IO === code
        syd = SydneyParser.load_file code
      else
        syd = SydneyParser.load_string(code.to_s)
      end
      #return [:newline, 1, "lib/kernel.rb", [:hash, [:lit, 1], [:str, ""], [:lit, 2], [:str, ""]]]
      result = syd.sexp(false, @newlines)
      GC.enable unless o
      return result
    end
        
    def compile(code)
      sexp = convert_to_sexp(code)
      comp = Bytecode::Compiler.new
      desc = comp.compile_as_script sexp, :__script__
      return desc.to_cmethod
    end
    
    def compile_file(path)
      fd = File.open(path)
      meth = compile(fd)
      fd.close
      return meth
    end
    
    def compiled_path(path)
      idx = path.index(".rb")
      if idx and idx == path.size - 3
        out = path[0, idx] + ".rbc"
        return out
      end
      
      return path + ".rbc"
    end
    
    def file_newer?(comp, orig)
      return false unless File.exists?(comp)
      return true  unless File.exists?(orig)
      
      cmt = File.mtime(comp)
      omt = File.mtime(orig)
            
      if cmt >= omt
        return true
      end
      
      return false
    end
    
    def refresh_file(path)
      cp = compiled_path(path)
      return if file_newer?(cp, path)
      compile_and_save(path)
    end
    
    def clear_precompiled(dir)
      Dir["#{dir}/*.rbc"].each do |path|
        File.unlink path
      end
    end
    
    def compile_and_save(path)
      cp = compiled_path(path)
      Log.info "(Compiling #{path}..)"
      cm = compile_file(path)
      fd = File.open(cp, "w")
      fd << "RBIS"
      Log.info "(Saving #{cp} to disk..)"
      fd << @sm.marshal(cm)
      fd.close
      return cm
    end
    
    def load_file(path, cached=true)
      cp = compiled_path(path)
      if cached and file_newer?(cp, path)
        fd = File.open(cp)
        magic = fd.read(4)
        if magic != "RBIS"
          raise "Invalid compiled file"
        end
        str = fd.read
        fd.close
        return @sm.unmarshal(str)
      end
      
      return compile_and_save(path)
    end
  end
end
