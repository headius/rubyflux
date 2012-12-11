module FastRuby
  class BodyCompiler
    def initialize(ast, method_compiler, node, do_declare, do_return)
      @ast, @method_compiler, @node, @do_declare, @do_return = ast, method_compiler, node, do_declare, do_return
      @declared_vars = method_compiler.argument_names.dup
    end

    attr_accessor :ast, :method_compiler, :node, :body, :do_declare, :do_return, :declared_vars

    def start
      @body = ast.new_block

      if do_declare
        last_var = ast.new_variable_declaration_fragment
        last_var.name = ast.new_simple_name("$last")
        last_var.initializer = ast.new_name("RNil")
        last_var_assign = ast.new_variable_declaration_statement(last_var)
        last_var_assign.type = ast.new_simple_type(ast.new_simple_name("RObject"))
        body.statements << last_var_assign
      end

      children = defined?(node.child_nodes) ? node.child_nodes : node
      children && children.each do |child_node|
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