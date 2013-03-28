require 'ruby_flux/jdt_utils'

module RubyFlux
  class ExpressionCompiler
    include JDTUtils

    include org.jruby.ast.visitor.NodeVisitor

    def initialize(ast, body_compiler, node)
      @ast, @body_compiler, @node = ast, body_compiler, node
    end

    attr_accessor :ast, :body_compiler, :node

    def start
      expression = node.accept(self)

      expression
    end

    def method_compiler
      body_compiler.method_compiler
    end

    def class_compiler
      method_compiler.class_compiler
    end

    def nil_expression(*args)
      ast.new_name('RNil')
    end
    alias method_missing nil_expression

    def empty_expression
      nil
    end

    def last_expression
      ast.new_name('$last')
    end
    
    def visitAndNode(node)
      and_expr = ast.new_infix_expression
      
      left_expr = call_toBoolean do |call|
        call.expression = ExpressionCompiler.new(ast, body_compiler, node.first_node).start
      end
      right_expr = call_toBoolean do |call|
        call.expression = ExpressionCompiler.new(ast, body_compiler, node.second_node).start
      end
      
      and_expr.left_operand = left_expr
      and_expr.right_operand = right_expr
      and_expr.operator = InfixOperator::CONDITIONAL_AND
      
      new_boolean = ast.new_class_instance_creation
      new_boolean.type = ast.new_simple_type(ast.new_simple_name('RBoolean'))
      new_boolean.arguments << and_expr
      
      new_boolean
    end
    
    def call_toBoolean
      call = ast.new_method_invocation
      call.name = ast.new_simple_name('toBoolean')
      yield call if block_given?
      call
    end

    def visitArrayNode(node)
      visitZArrayNode(node).tap do |ary|
        node.child_nodes.each do |element|
          ary.arguments << ExpressionCompiler.new(ast, body_compiler, element).start
        end
      end
    end

    def visitCallNode(node)
#      method_invocation = case node.name
#      when "new"
#        ast.new_class_instance_creation.tap do |construct|
#          construct.type = ast.new_simple_type(ast.new_simple_name(proper_class(node.receiver_node.name)))
#        end
#      else
        method_invocation = ast.new_method_invocation.tap do |method_invocation|
          method_invocation.name = ast.new_simple_name(safe_name(node.name))
          if org.jruby.ast.ConstNode === node.receiver_node
            method_invocation.expression = ast.new_name(proper_class(node.receiver_node.name))
          else
            class_compiler.compiler.methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
            method_invocation.expression = ExpressionCompiler.new(ast, body_compiler, node.receiver_node).start
          end
        end
#      end
        
      node.args_node && node.args_node.child_nodes.each do |arg|
        arg_expression = ExpressionCompiler.new(ast, body_compiler, arg).start
        method_invocation.arguments << arg_expression
      end

      method_invocation
    end
    
    def visitClassNode(node)
      source = new_source
      class_compiler.compiler.sources << source

      new_ast = source.ast

      new_class_compiler = ClassCompiler.new(class_compiler.compiler, new_ast, source, node.cpath.name, node)
      new_class_compiler.start

      nil
    end

    def visitConstDeclNode(node)
      nil_fragment = ast.new_variable_declaration_fragment
      nil_fragment.name = ast.new_simple_name(node.name)
      nil_fragment.initializer = ast.new_name('RNil')

      declaration = ast.new_field_declaration(nil_fragment).tap do |decl|
        decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
        decl.modifiers << ast.new_modifier(ModifierKeyword::STATIC_KEYWORD)
        decl.type = ast.new_simple_type(ast.new_simple_name('RObject'))
      end

      class_compiler.class_decl.body_declarations << declaration

      const_asgn = ast.new_assignment
      const_asgn.left_hand_side = visitConstNode(node)
      const_asgn.right_hand_side = ExpressionCompiler.new(ast, body_compiler, node.value_node).start

      const_asgn
    end

    def visitConstNode(node)
#      if class_compiler.imports.include? node.name
#        # java import; handle via RJavaClass
#        ast.new_class_instance_creation.tap do |construct|
#          construct.type = ast.new_simple_type(ast.new_simple_name('RJavaClass'))
#          construct.arguments << ast.new_type_literal
#            arg_expression = ExpressionCompiler.new(ast, body_compiler, arg).start
#            method_invocation.arguments << arg_expression
#          end
#        end
#        ast.new_qualified_name( ast.new_simple_name(node.name))
#      end
      ast.new_qualified_name(ast.new_simple_name(class_compiler.class_name), ast.new_simple_name(node.name))
    end

    def visitDefnNode(node)
      method_compiler = MethodCompiler.new(ast, class_compiler, node)
      method_compiler.start

      nil
    end

    def visitFalseNode(node)
      ast.new_name("RFalse")
    end

    def visitFCallNode(node)
      case node.name
      when "import"
        class_name = node.args_node.child_nodes[0].value
        class_elts = class_name.split('.')
        
        class_compiler.imports[short_name] = class_name
        ast.new_import_declaration.tap do |import_declaration|
          import_declaration.name = ast.new_name(class_elts.to_java(:string))
          class_compiler.compiler.sources[0].imports.add 0, import_declaration
        end
        
        return nil
      end
      
      class_compiler.compiler.methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0

      ast.new_method_invocation.tap do |method_invocation|
        method_invocation.name = ast.new_simple_name(safe_name(node.name))
        
        node.args_node && node.args_node.child_nodes.each do |arg|
          arg_expression = ExpressionCompiler.new(ast, body_compiler, arg).start
          method_invocation.arguments << arg_expression
        end
      end
    end

    def visitFixnumNode(node)
      ast.new_class_instance_creation.tap do |construct|
        construct.type = ast.new_simple_type(ast.new_simple_name("RFixnum"))
        construct.arguments << ast.new_number_literal(node.value.to_s + "L")
      end
    end

    def visitFloatNode(node)
      ast.new_class_instance_creation.tap do |construct|
        construct.type = ast.new_simple_type(ast.new_simple_name("RFloat"))
        construct.arguments << ast.new_number_literal(node.value.to_s)
      end
    end

    def visitIfNode(node)
      conditional = ast.new_if_statement
      
      condition_expr = ExpressionCompiler.new(ast, body_compiler, node.condition).start
      java_boolean = ast.new_method_invocation
      java_boolean.expression = condition_expr
      java_boolean.name = ast.new_simple_name("toBoolean")

      conditional.expression = java_boolean

      if node.then_body
        then_body_compiler = BodyCompiler.new(ast, method_compiler, node.then_body, false, false)
        then_body_compiler.start
        conditional.then_statement = then_body_compiler.body
      end

      if node.else_body
        else_body_compiler = BodyCompiler.new(ast, method_compiler, node.else_body, false, false)
        else_body_compiler.start
        conditional.else_statement = else_body_compiler.body
      end

      body_compiler.body.statements << conditional

      last_expression
    end

    def visitLocalAsgnNode(node)
      var_assign = ast.new_assignment
      var_assign.left_hand_side = ast.new_name(node.name)
      var_assign.right_hand_side = ExpressionCompiler.new(ast, body_compiler, node.value_node).start

      var_assign
    end

    def visitLocalVarNode(node)
      ast.new_name(node.name)
    end

    def visitNewlineNode(node)
      node.next_node.accept(self)
    end

    def visitNilNode(node)
      nil_expression
    end
    
    def visitOrNode(node)
      and_expr = ast.new_infix_expression
      
      left_expr = call_toBoolean do |call|
        call.expression = ExpressionCompiler.new(ast, body_compiler, node.first_node).start
      end
      right_expr = call_toBoolean do |call|
        call.expression = ExpressionCompiler.new(ast, body_compiler, node.second_node).start
      end
      
      and_expr.left_operand = left_expr
      and_expr.right_operand = right_expr
      and_expr.operator = InfixOperator::CONDITIONAL_OR
      
      new_boolean = ast.new_class_instance_creation
      new_boolean.type = ast.new_simple_type(ast.new_simple_name('RBoolean'))
      new_boolean.arguments << and_expr
      
      new_boolean
    end

    def visitReturnNode(node)
      return_expr = ExpressionCompiler.new(ast, body_compiler, node.value_node).start

      [:return, return_expr]
    end

    def visitStrNode(node)
      ast.new_class_instance_creation.tap do |construct|
        construct.type = ast.new_simple_type(ast.new_simple_name("RString"))
        construct.arguments << ast.new_string_literal.tap do |string_literal|
          string_literal.literal_value = node.value.to_s
        end
      end
    end

    def visitTrueNode(node)
      ast.new_name("RTrue")
    end

    def visitVCallNode(node)
      class_compiler.compiler.methods[safe_name(node.name)] = 0

      ast.new_method_invocation.tap do |method_invocation|
        method_invocation.name = ast.new_simple_name(safe_name(node.name))
      end
    end

    def visitWhileNode(node)
      ast.new_while_statement.tap do |while_stmt|
        condition_expr = ExpressionCompiler.new(ast, body_compiler, node.condition_node).start
        java_boolean = ast.new_method_invocation
        java_boolean.expression = condition_expr
        java_boolean.name = ast.new_simple_name("toBoolean")

        while_stmt.expression = java_boolean

        if node.body_node
          new_body_compiler = BodyCompiler.new(ast, method_compiler, node.body_node, false, false)
          new_body_compiler.start

          while_stmt.body = new_body_compiler.body
        end

        body_compiler.body.statements << while_stmt
      end

      nil_expression
    end

    def visitZArrayNode(node)
      ast.new_class_instance_creation.tap do |ary|
        ary.type = ast.new_simple_type(ast.new_simple_name('RArray'))
      end
    end
  end
end
