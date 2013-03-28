require 'ruby_flux/jdt_utils'

module RubyFlux
  class ClassCompiler
    include JDTUtils

    def initialize(compiler, ast, source, class_name, node)
      @compiler, @ast, @source, @class_name, @node = compiler, ast, source, class_name, node
      @method_decls = []
      @class_decl = nil
    end

    attr_accessor :compiler, :ast, :source
    attr_accessor :class_decl, :class_name
    attr_accessor :metaclass_decl
    attr_accessor :imports

    def start
      @class_decl = ast.new_type_declaration
      @metaclass_decl = ast.new_type_declaration
      @imports = {}
      
      class_decl.interface = false
      class_decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
      class_decl.name = ast.new_simple_name(@class_name)
      class_decl.superclass_type = ast.new_simple_type(ast.new_simple_name("RObject"))
      
      metaclass_decl.interface = false
      metaclass_decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
      metaclass_decl.modifiers << ast.new_modifier(ModifierKeyword::STATIC_KEYWORD)
      metaclass_decl.name = ast.new_simple_name(@class_name + "Meta")
      metaclass_decl.superclass_type = ast.new_simple_type(ast.new_simple_name("ObjectMeta"))

      source.types << class_decl
      class_decl.body_declarations << metaclass_decl

      define_main if org.jruby.ast.RootNode === @node
      
      define_metaclass

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
      main_call.name = ast.new_simple_name("$main")
      new_obj = ast.new_class_instance_creation
      new_obj.type = ast.new_simple_type(ast.new_simple_name(@class_name))
      main_call.expression = new_obj
      body.statements << ast.new_expression_statement(main_call)
      main_method.body = body

      class_decl.body_declarations << main_method
    end
    
    def define_metaclass
      construct = ast.new_method_declaration
      construct.name = ast.new_simple_name(@class_name + "Meta")
      construct.constructor = true
      
      construct.body = ast.new_block.tap do |body|
        super_call = ast.new_super_constructor_invocation
        super_call.arguments << ast.new_string_literal.tap do |string_literal|
          string_literal.literal_value = @class_name
        end
        body.statements << super_call
      end
      
      allocate_method = ast.new_method_declaration
      allocate_method.name = ast.new_simple_name("allocate")
      allocate_method.return_type2 = ast.new_simple_type(ast.new_simple_name("RObject"))
      allocate_method.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
      
      allocate_method.body = ast.new_block.tap do |body|
        body.statements << ast.new_return_statement.tap do |return_statement|
          new_obj = ast.new_class_instance_creation
          new_obj.type = ast.new_simple_type(ast.new_simple_name(@class_name))
          return_statement.expression = new_obj
        end
      end
      
      class_method = ast.new_method_declaration
      class_method.name = ast.new_simple_name("$class")
      class_method.return_type2 = ast.new_simple_type(ast.new_simple_name("RClass"))
      class_method.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
      
      class_method.body = ast.new_block.tap do |body|
        body.statements << ast.new_return_statement.tap do |return_statement|
          new_obj = ast.new_simple_name(@class_name)
          return_statement.expression = new_obj
        end
      end

      metaclass_decl.body_declarations << construct
      metaclass_decl.body_declarations << allocate_method
      class_decl.body_declarations << class_method
      
      compiler.classes << @class_name
    end
  end
end
