require 'jruby'
require 'java'
require 'fastruby-1.0-SNAPSHOT.jar'
require 'fileutils'

module FastRuby
  BUILTINS = %w[puts]

  Char = java.lang.Character
  java_import org.eclipse.jdt.core.dom.AST
  java_import org.eclipse.jdt.core.dom.ASTParser
  java_import org.eclipse.jdt.core.dom.rewrite.ASTRewrite
  java_import org.eclipse.jface.text.Document
  java_import org.eclipse.jdt.core.dom.Modifier
  ModifierKeyword = Modifier::ModifierKeyword
  java_import org.eclipse.jdt.core.JavaCore
  java_import org.eclipse.jdt.core.formatter.DefaultCodeFormatterConstants

  COPIED_SOURCES = %w[
    RKernel.java
    RFixnum.java
    RBoolean.java
    RString.java
    RFloat.java
    RArray.java
  ]

  module JDTUtils
    def source_to_document(source)
      document = Document.new

      options = JavaCore.options

      options[DefaultCodeFormatterConstants::FORMATTER_INDENTATION_SIZE] = '4'
      options[DefaultCodeFormatterConstants::FORMATTER_TAB_CHAR] = 'space'
      options[DefaultCodeFormatterConstants::FORMATTER_TAB_SIZE] = '4'
      text_edit = source.rewrite(document, options)
      text_edit.apply document

      document
    end

    def new_source
      parser = ASTParser.newParser(AST::JLS3)
      parser.source = ''.to_java.to_char_array

      cu = parser.create_ast(nil)
      cu.record_modifications

      cu
    end
  end

  class Compiler
    include JDTUtils

    def initialize(files, source = nil)
      @files = files
      @source = source
      @sources = []
      @methods = {}
    end

    attr_accessor :sources, :methods

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

      # all generated sources
      sources.each do |source|
        type = source.types[0]
        File.open(type.name.to_s + ".java", 'w') do |file|
          file.write(source_to_document(source).get)
        end
      end

      # all copied sources
      COPIED_SOURCES.each do |srcname|
        FileUtils.cp(File.join('src/main/java', srcname), ".")
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
        throw_statement = ast.new_throw_statement
        expression = ast.new_class_instance_creation
        expression.type = ast.new_simple_type(ast.new_simple_name("RuntimeException"))
        expression.arguments << ast.new_string_literal.tap {|s| s.literal_value = name}
        throw_statement.expression = expression
        body.statements << throw_statement
        method_decl.body = body

        robject_cls.body_declarations << method_decl
      end
    end

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
          ruby_method.name = ast.new_simple_name "_main_"

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

        body = BodyCompiler.new(ast, self, node.body_node, do_return).start

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

      def safe_name(name)
        case name
          when '+'; '_plus_'
          when '-'; '_minus_'
          when '*'; '_times_'
          when '/'; '_divide_'
          when '<'; '_lt_'
          when '>'; '_gt_'
          when '<='; '_le_'
          when '>='; '_ge_'
          when '=='; '_equal_'
          when '<=>'; '_cmp_'
          else; name
        end
      end
    end

    class BodyCompiler
      def initialize(ast, method_compiler, node, do_return)
        @ast, @method_compiler, @node, @do_return = ast, method_compiler, node, do_return
        @declared_vars = method_compiler.argument_names.dup
      end

      attr_accessor :ast, :method_compiler, :node, :body, :do_return, :declared_vars

      def start
        @body = ast.new_block
        last_var = ast.new_variable_declaration_fragment
        last_var.name = ast.new_simple_name("$last")
        last_var.initializer = ast.new_name("RNil")
        last_var_assign = ast.new_variable_declaration_statement(last_var)
        last_var_assign.type = ast.new_simple_type(ast.new_simple_name("RObject"))
        body.statements << last_var_assign

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
      
      def visitClassNode(node)
        source = new_source
        class_compiler.compiler.sources << source

        new_ast = source.ast

        new_class_compiler = ClassCompiler.new(class_compiler.compiler, new_ast, source, node.cpath.name, node)
        new_class_compiler.start

        empty_expression
      end

      def visitCallNode(node)
        class_compiler.compiler.methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0

        method_invocation = case node.name
        when "new"
          ast.new_class_instance_creation.tap do |construct|
            construct.type = ast.new_simple_type(ast.new_simple_name(node.receiver_node.name))
          end
        else
          ast.new_method_invocation.tap do |method_invocation|
            method_invocation.name = ast.new_simple_name(safe_name(node.name))
            method_invocation.expression = ExpressionCompiler.new(ast, body_compiler, node.receiver_node).start
          end
        end
          
        node.args_node && node.args_node.child_nodes.each do |arg|
          arg_expression = ExpressionCompiler.new(ast, body_compiler, arg).start
          method_invocation.arguments << arg_expression
        end

        method_invocation
      end

      def visitFCallNode(node)
        class_compiler.compiler.methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0

        ast.new_method_invocation.tap do |method_invocation|
          method_invocation.name = ast.new_simple_name(node.name)
          method_invocation.expression = ast.new_this_expression
          
          node.args_node && node.args_node.child_nodes.each do |arg|
            arg_expression = ExpressionCompiler.new(ast, body_compiler, arg).start
            method_invocation.arguments << arg_expression
          end
        end
      end

      def visitVCallNode(node)
        class_compiler.compiler.methods[safe_name(node.name)] = 0

        ast.new_method_invocation.tap do |method_invocation|
          method_invocation.name = ast.new_simple_name(node.name)
          method_invocation.expression = ast.new_this_expression
        end
      end

      def visitDefnNode(node)
        method_compiler = MethodCompiler.new(ast, class_compiler, node)
        method_compiler.start

        empty_expression
      end

      def visitStrNode(node)
        ast.new_class_instance_creation.tap do |construct|
          construct.type = ast.new_simple_type(ast.new_simple_name("RString"))
          construct.arguments << ast.new_string_literal.tap do |string_literal|
            string_literal.literal_value = node.value.to_s
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

      def visitNewlineNode(node)
        node.next_node.accept(self)
      end

      def visitNilNode(node)
        nil_expression
      end

      def visitLocalVarNode(node)
        ast.new_name(node.name)
      end

      def visitLocalAsgnNode(node)
        unless body_compiler.declared_vars.include? node.name
          body_compiler.declared_vars << node.name
          var = ast.new_variable_declaration_fragment
          var.name = ast.new_simple_name(node.name)
        
          var.initializer = ast.new_name("RNil")
          var_assign = ast.new_variable_declaration_statement(var)
          var_assign.type = ast.new_simple_type(ast.new_simple_name("RObject"))

          body_compiler.body.statements << var_assign
        end

        var_assign = ast.new_assignment
        var_assign.left_hand_side = ast.new_name(node.name)
        var_assign.right_hand_side = ExpressionCompiler.new(ast, body_compiler, node.value_node).start

        var_assign
      end

      def visitIfNode(node)
        conditional = ast.new_if_statement
        
        condition_expr = ExpressionCompiler.new(ast, body_compiler, node.condition).start
        java_boolean = ast.new_method_invocation
        java_boolean.expression = condition_expr
        java_boolean.name = ast.new_simple_name("toBoolean")

        conditional.expression = java_boolean

        if node.then_body
          then_stmt = StatementCompiler.new(ast, body_compiler, node.then_body).start
          conditional.then_statement = then_stmt
        end

        if node.else_body
          else_stmt = StatementCompiler.new(ast, body_compiler, node.else_body).start
          conditional.else_statement = else_stmt
        end

        body_compiler.body.statements << conditional

        nil
      end

      def visitZArrayNode(node)
        ast.new_class_instance_creation.tap do |ary|
          ary.type = ast.new_simple_type(ast.new_simple_name('RArray'))
        end
      end

      def visitArrayNode(node)
        visitZArrayNode(node).tap do |ary|
          node.child_nodes.each do |element|
            ary.arguments << ExpressionCompiler.new(ast, body_compiler, element).start
          end
        end
      end

=begin
      def visitConstDeclNode(node)
        #print "    #{node.name} = "
        node.value_node.accept(self)
      end

      def visitConstNode(node)
        #print node.name
      end
=end

      def safe_name(name)
        new_name = ''

        name.chars.each do |ch|
          new_name << case ch
            when '+'; '$plus'
            when '-'; '$minus'
            when '*'; '$times'
            when '/'; '$div'
            when '<'; '$less'
            when '>'; '$greater'
            when '='; '$equal'
            when '&'; '$tilde'
            when '!'; '$bang'
            when '%'; '$percent'
            when '^'; '$up'
            when '?'; '$qmark'
            when '|'; '$bar'
            when '['; '$lbrack'
            when ']'; '$rbrack'
            else; ch;
          end
        end

        new_name
      end
    end
  end
end

if __FILE__ == $0
  if ARGV[0] == '-e'
    FastRuby::Compiler.new('-e', ARGV[1]).compile
  else
    FastRuby::Compiler.new(ARGV).compile
  end
end
