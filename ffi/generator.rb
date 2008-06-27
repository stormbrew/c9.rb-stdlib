module FFI
  class Generator

    def initialize(ffi_name, rb_name)
      @ffi_name = ffi_name
      @rb_name = rb_name

      @name = File.basename rb_name, '.rb'

      file = File.read @ffi_name

      new_file = file.gsub(/^( *)@@@(.*?)@@@/m) do
        @constants = []
        @structs = []

        indent = $1
        original_lines = $2.count("\n") - 1

        instance_eval $2

        new_lines = []
        @constants.each { |c| new_lines << c.to_ruby }
        @structs.each { |s| new_lines << s.generate_layout }

        new_lines = new_lines.join("\n").split "\n" # expand multiline blocks
        new_lines = new_lines.map { |line| indent + line }

        padding = original_lines - new_lines.length
        new_lines += [nil] * padding if padding >= 0

        new_lines.join "\n"
      end

      open @rb_name, 'w' do |f|
        f.puts "# This file is generated by rake. Do not edit."
        f.puts
        f.puts new_file
      end
    end

    def constants(&block)
      @constants << FFI::ConstGenerator.new(@name, &block)
    end

    def struct(&block)
      @structs << FFI::StructGenerator.new(@name, &block)
    end

  end
end

