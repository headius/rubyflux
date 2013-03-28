require 'ruby_flux/jdt_utils'

module RubyFlux
  class MethodCompiler
    include JDTUtils

    def initialize(ast, class_compiler, node)
      @ast, @class_compiler, @node = ast, class_compiler, node
      @argument_names = []
    end

    attr_accessor :ast, :class_compiler, :node, :body, :argument_names

    def start
      do_return = false

      case node
      when org.jruby.ast.RootNode
        # no name; it's the main body of a script
        ruby_method = ast.new_method_declaration
        ruby_method.name = ast.new_simple_name "$main"

        body_node = node
      when org.jruby.ast.ClassNode
        ruby_method = ast.new_method_declaration
        proper_name = node.cpath.name + "$body"
        ruby_method.name = ast.new_simple_name proper_name

        body_node = node.body_node
      else
        ruby_method = ast.new_method_declaration

        arity = define_args(ruby_method)

        proper_name = safe_name(node.name)
        class_compiler.compiler.methods[proper_name] = arity

        ruby_method.name = ast.new_simple_name proper_name

        robject_type = ast.new_simple_type(ast.new_simple_name("RObject"))

        unless proper_name == "initialize"
          ruby_method.return_type2 = robject_type
          do_return = true
        end

        body_node = node.body_node
      end

      class_decl.body_declarations << ruby_method
      ruby_method.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)

      body = BodyCompiler.new(ast, self, node.body_node, true, do_return).start

      ruby_method.body = body

      if proper_name == "initialize"
        class_compiler.define_constructor
      end
    end

    def class_decl
      class_compiler.class_decl
    end

    def define_args(method_decl)
      arity = 0

      if node.kind_of? org.jruby.ast.DefnNode
        args_node = node.args_node.pre
        arity = args_node ? args_node.child_nodes.size : 0;
        args = args_node ? args_node.child_nodes : []

        args && args.each do |a|
          argument_names << a.name
          arg_decl = ast.new_single_variable_declaration
          arg_decl.name = ast.new_simple_name(a.name)
          arg_decl.type = ast.new_simple_type(ast.new_simple_name("RObject"))
          method_decl.parameters << arg_decl
        end
      end

      arity
    end
  end
end
