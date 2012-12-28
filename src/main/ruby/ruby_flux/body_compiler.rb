module RubyFlux
  class BodyCompiler
    def initialize(ast, method_compiler, node, do_declare, do_return)
      @ast, @method_compiler, @node, @do_declare, @do_return = ast, method_compiler, node, do_declare, do_return
    end

    attr_accessor :ast, :method_compiler, :node, :body, :do_declare, :do_return

    def start
      @body = ast.new_block

      if do_declare
        last_var = ast.new_variable_declaration_fragment
        last_var.name = ast.new_simple_name("$last")
        last_var.initializer = ast.new_name("RNil")
        last_var_assign = ast.new_variable_declaration_statement(last_var)
        last_var_assign.type = ast.new_simple_type(ast.new_simple_name("RObject"))
        body.statements << last_var_assign

        scope = case method_compiler.node
        when org.jruby.ast.MethodDefNode, org.jruby.ast.ClassNode
          method_compiler.node.scope
        when org.jruby.ast.RootNode
          method_compiler.node.scope.static_scope
        else
          fail 'declare for unknown node' + method_compiler.node.node_type.to_s
        end

        scope.variables[scope.required_args..-1].each do |name|
          var = ast.new_variable_declaration_fragment
          var.name = ast.new_simple_name(name)

          var.initializer = ast.new_name("RNil")
          var_assign = ast.new_variable_declaration_statement(var)
          var_assign.type = ast.new_simple_type(ast.new_simple_name("RObject"))

          body.statements << var_assign
        end
      end

      children = org.jruby.ast.BlockNode == node ? node.child_nodes : [node]
      children.each do |child_node|
        statement = StatementCompiler.new(ast, self, child_node).start

        body.statements << statement if statement
      end

      if do_return
        return_last = ast.new_return_statement
        return_last.expression = ast.new_simple_name("$last")
        body.statements << return_last
      end

      body
    end
  end
end
