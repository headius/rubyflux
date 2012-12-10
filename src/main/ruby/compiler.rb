require 'jruby'
require 'java'
require 'fastruby-1.0-SNAPSHOT.jar'

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

    def initialize(files)
      @files = files
      @sources = []
      @methods = {}
    end

    attr_accessor :sources, :methods

    def compile
      @files.each do |file|
        ast = JRuby.parse(File.read(file))

        source = new_source
        sources << source

        jdt_ast = source.ast

        @visitor = ClassVisitor.new(self, jdt_ast, source, File.basename(file).split('.')[0], ast)
        @visitor.start
      end

      build_robject

      sources.each do |source|
        puts source_to_document(source).get
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
        method_decl = ast.new_method_declaration
        method_decl.name = ast.new_simple_name name
        method_decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)

        if arity > 0
          (0..arity).each do |i|
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

    class ClassVisitor
      include JDTUtils

      include org.jruby.ast.visitor.NodeVisitor

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
	class_decl.name = ast.new_simple_name(@class_name)
	class_decl.superclass_type = ast.new_simple_type(ast.new_simple_name("RObject"))

	source.types << class_decl

        define_main

	@method_visitor = MethodVisitor.new(ast, self, @node)
	@method_visitor.start
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

    class MethodVisitor
      include JDTUtils

      include org.jruby.ast.visitor.NodeVisitor

      def initialize(ast, class_visitor, node)
        @ast, @class_visitor, @node = ast, class_visitor, node
      end

      attr_accessor :ast, :class_visitor, :node, :body

      def method_missing(name, node)
        node.child_nodes.each {|n| n.accept self}
      end

      def start
        do_return = false

        case node
        when org.jruby.ast.RootNode
          # no name; it's the main body of a script
          ruby_method = ast.new_method_declaration
          ruby_method.name = ast.new_simple_name "_main_"
          ruby_method.return_type2 = ast.new_simple_type(ast.new_simple_name("RObject"))

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
          class_visitor.compiler.methods[proper_name] = arity

          ruby_method.name = ast.new_simple_name proper_name

          robject_type = ast.new_simple_type(ast.new_simple_name("ROBject"))

          unless proper_name == "initialize"
            ruby_method.return_type2 = robject_type
            do_return = true
          end

          body_node = node.body_node
        end

        class_decl.body_declarations << ruby_method
        ruby_method.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)

        @body = ast.new_block
        last_var = ast.new_single_variable_declaration
        last_var.name = ast.new_simple_name("$last")
        last_var.type = ast.new_simple_type(ast.new_simple_name("ROBject"))
        nil_load = ast.new_field_access
        nil_load.name = ast.new_simple_name("RNil")
        last_assignment = ast.new_assignment
        last_assignment.left_hand_side = ast.new_simple_name("$last")
        last_assignment.right_hand_side = nil_load
        body.statements << ast.new_expression_statement(last_assignment)

        ruby_method.body = body

        body_node.accept self if body_node

        if do_return
          return_last = ast.new_return_statement
          return_last.expression = ast.new_simple_name("$last")
          body.statements << return_last
        end
      end

      def class_decl
        class_visitor.class_decl
      end

      def visitClassNode(node)
        source = new_source
        class_visitor.compiler.sources << source

        ast = source.ast

        new_class_visitor = ClassVisitor.new(class_visitor.compiler, ast, source, node.cpath.name, node)
        new_class_visitor.start
      end

      def visitCallNode(node)
=begin
        @methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
        node.receiver_node.accept(self)
        print ".#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self} if node.args_node
        print ")"
=end
      end

      def visitFCallNode(node)
=begin
        @methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
        print "#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self} if node.args_node
        print ")"
=end
      end

      def visitVCallNode(node)
=begin
        @methods[safe_name(node.name)] = 0
        print "#{safe_name(node.name)}();"
=end
      end

      def visitDefnNode(node)
        method_visitor = MethodVisitor.new(ast, class_visitor, node)
        method_visitor.start
      end

      def define_args(method_decl)
        arity = 0

        if node.kind_of? org.jruby.ast.DefnNode
          args_node = node.args_node.pre
          arity = args_node ? args_node.child_nodes.size : 0;
          args = args_node ? args_node.child_nodes : []

          args && args.each do |a|
            arg_decl = ast.new_single_variable_declaration
            arg_decl.name = ast.new_simple_name(a.name)
            arg_decl.type = ast.new_simple_type(ast.new_simple_name("ROBject"))
            method_decl.parameters << arg_decl
          end
        end

        arity
      end

      def visitStrNode(node)
        #print "new RString(\"#{node.value}\")"
      end

      def visitFixnumNode(node)
        #print "new RFixnum(#{node.value})"
      end

      def visitNewlineNode(node)
        node.next_node.accept(self)
      end

      def visitNilNode(node)
        #print "RNil"
      end

      def visitIfNode(node)
        # print "if ("
        node.condition.accept(self)
        #print ".toBoolean()) {\n"
        node.then_body.accept(self)
        if node.else_body
        #  print "} else {\n"
          node.else_body.accept(self)
        end
        #print "}"
      end

      def visitLocalVarNode(node)
        #print node.name
      end

      def visitConstDeclNode(node)
        #print "    #{node.name} = "
        node.value_node.accept(self)
      end

      def visitConstNode(node)
        #print node.name
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
  end
end

if __FILE__ == $0
  FastRuby::Compiler.new(ARGV).compile
end
