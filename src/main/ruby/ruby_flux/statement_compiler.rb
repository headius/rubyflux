require 'ruby_flux/jdt_utils'

module RubyFlux
  class StatementCompiler
    include JDTUtils

    include org.jruby.ast.visitor.NodeVisitor

    def initialize(ast, body_compiler, node)
      @ast, @body_compiler, @node = ast, body_compiler, node
    end

    attr_accessor :ast, :body_compiler, :node

    def start
      if org.jruby.ast.BlockNode === node
        node.child_nodes.each do |line|
          statement = StatementCompiler.new(ast, body_compiler, line).start
          body_compiler.body.statements << statement if statement
        end
        ast.new_empty_statement
      else
        expression = ExpressionCompiler.new(ast, body_compiler, node).start

        if expression
          if Array === expression
            type, expression = expression
          end

          last_assignment = ast.new_assignment
          last_assignment.left_hand_side = ast.new_simple_name("$last")
          last_assignment.right_hand_side = expression

          case type
          when :return
            body_compiler.body.statements << ast.new_expression_statement(last_assignment)
            ast.new_return_statement.tap do |return_stmt|
              return_stmt.expression = ast.new_name('$last')
            end
          else
            ast.new_expression_statement(last_assignment)
          end
        else
          nil
        end
      end
    end
  end
end
