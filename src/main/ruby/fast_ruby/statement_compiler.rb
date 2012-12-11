require 'fast_ruby/jdt_utils'

module FastRuby
  class StatementCompiler
    include JDTUtils

    include org.jruby.ast.visitor.NodeVisitor

    def initialize(ast, body_compiler, node)
      @ast, @body_compiler, @node = ast, body_compiler, node
    end

    attr_accessor :ast, :body_compiler, :node

    def start
      expression = ExpressionCompiler.new(ast, body_compiler, node).start

      if expression
        last_assignment = ast.new_assignment
        last_assignment.left_hand_side = ast.new_simple_name("$last")
        last_assignment.right_hand_side = expression

        ast.new_expression_statement(last_assignment)
      else
        ast.new_empty_statement
      end
    end
  end
end