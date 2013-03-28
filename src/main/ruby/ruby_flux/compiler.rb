require 'ruby_flux/jdt_utils'

module RubyFlux
  class Compiler
    include JDTUtils

    def initialize(files, source = nil)
      @files = files
      @source = source
      @sources = []
      @classes = []
      @methods = {}
    end

    attr_accessor :sources, :methods, :classes

    def compile
      if !@source
        @files.each do |file|
          ast = JRuby.parse(File.read(file))

          source = new_source
          sources << source

          jdt_ast = source.ast

          ClassCompiler.new(self, jdt_ast, source, File.basename(file).split('.')[0], ast).start
        end
      else
        ast = JRuby.parse(@source)

        source = new_source
        sources << source

        jdt_ast = source.ast

        ClassCompiler.new(self, jdt_ast, source, "DashE", ast).start
      end

      build_robject

      FileUtils.mkdir('build') unless Dir.exists?('build')

      # all generated sources
      sources.each do |source|
        type = source.types[0]
        File.open(File.join('build', type.name.to_s + ".java"), 'w') do |file|
          file.write(source_to_document(source).get)
        end
      end

      # all copied sources
      COPIED_SOURCES.each do |srcname|
        FileUtils.cp(File.join('src/main/java', srcname), "build/.")
      end
    end

    def build_robject
      source = new_source
      sources << source

      ast = source.ast

      robject_cls = ast.new_type_declaration
      robject_cls.interface = false
      robject_cls.name = ast.new_simple_name("RObject")

      robject_cls.superclass_type = ast.new_simple_type(ast.new_simple_name("RKernel"))
      source.types << robject_cls
      
      classes.each do |class_name|
        metaclass_fragment = ast.new_variable_declaration_fragment
        metaclass_fragment.name = ast.new_simple_name(class_name)
        metaclass_init = ast.new_class_instance_creation
        metaclass_init.type = ast.new_simple_type(ast.new_name([class_name, class_name + "Meta"].to_java(:string)))
        metaclass_fragment.initializer = metaclass_init
        metaclass_field = ast.new_field_declaration(metaclass_fragment)
        metaclass_field.type = ast.new_simple_type(ast.new_name([class_name, class_name + "Meta"].to_java(:string)))
        metaclass_field.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
        metaclass_field.modifiers << ast.new_modifier(ModifierKeyword::STATIC_KEYWORD)
        robject_cls.body_declarations << metaclass_field
      end

      methods.each do |name, arity|
        next if BUILTINS.include? name
        method_decl = ast.new_method_declaration

        method_decl.name = ast.new_simple_name name
        method_decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
        method_decl.return_type2 = ast.new_simple_type(ast.new_simple_name("RObject"))

        if arity > 0
          (0...arity).each do |i|
            arg = ast.new_single_variable_declaration
            arg.name = ast.new_simple_name("arg%02d" % i)
            arg.type = ast.new_simple_type(ast.new_simple_name("RObject"))
            method_decl.parameters << arg
          end
        end

        body = ast.new_block

        method_missing = ast.new_method_invocation.tap do |method_invocation|
          method_invocation.name = ast.new_simple_name("method_missing")

          name_arg = ast.new_class_instance_creation.tap do |construct|
            construct.type = ast.new_simple_type(ast.new_simple_name("RString"))
            construct.arguments << ast.new_string_literal.tap do |string_literal|
              string_literal.literal_value = name
            end
          end

          method_invocation.arguments << name_arg
          
          ary_arg = ast.new_class_instance_creation.tap do |ary|
            ary.type = ast.new_simple_type(ast.new_simple_name('RArray'))
            (0...arity).each do |i|
              arg = ast.new_name("arg%02d" % i)
              ary.arguments << arg
            end
          end

          method_invocation.arguments << ary_arg
        end

        return_mm = ast.new_return_statement.tap do |return_stmt|
          return_stmt.expression = method_missing
        end

        body.statements << return_mm

        method_decl.body = body

        robject_cls.body_declarations << method_decl
      end
    end
  end
end
