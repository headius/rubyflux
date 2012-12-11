require 'fast_ruby/jdt_utils'

module FastRuby
  class ClassCompiler
    include JDTUtils

    def initialize(compiler, ast, source, class_name, node)
      @compiler, @ast, @source, @class_name, @node = compiler, ast, source, class_name, node
      @method_decls = []
      @class_decl = nil
    end

    attr_accessor :compiler, :ast, :source
    attr_accessor :class_decl

    def start
	@class_decl = ast.new_type_declaration
	class_decl.interface = false
      class_decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
	class_decl.name = ast.new_simple_name(@class_name)
	class_decl.superclass_type = ast.new_simple_type(ast.new_simple_name("RObject"))

	source.types << class_decl

      define_main

	MethodCompiler.new(ast, self, @node).start
    end

    def define_constructor
      construct = ast.new_method_declaration
      construct.name = ast.new_simple_name(@class_name)
      construct.constructor = true
      
      construct.body = ast.new_block.tap do |body|
        initialize_call = ast.new_method_invocation
        initialize_call.name = ast.new_simple_name("initialize")
        body.statements << ast.new_expression_statement(initialize_call)
      end

      class_decl.body_declarations << construct
    end

    def define_main
      main_method = ast.new_method_declaration
      main_method.name = ast.new_simple_name("main")
      main_method.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
      main_method.modifiers << ast.new_modifier(ModifierKeyword::STATIC_KEYWORD)
      args_var = ast.new_single_variable_declaration
      args_var.type = ast.new_array_type(ast.new_simple_type(ast.new_simple_name("String")))
      args_var.name = ast.new_simple_name("args")
      main_method.parameters << args_var

      body = ast.new_block
      main_call = ast.new_method_invocation
      main_call.name = ast.new_simple_name("_main_")
      new_obj = ast.new_class_instance_creation
      new_obj.type = ast.new_simple_type(ast.new_simple_name(@class_name))
      main_call.expression = new_obj
      body.statements << ast.new_expression_statement(main_call)
      main_method.body = body

      class_decl.body_declarations << main_method
    end
  end
end