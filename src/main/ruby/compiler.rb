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
      @visitor = Visitor.new
    end

    def compile
      @files.each do |file|
        ast = JRuby.parse(File.read(file))
        @visitor.start_class(File.basename(file).split('.')[0], ast.child_nodes, true)
      end

      @visitor.sources.each do |source|
        puts source_to_document(source).get
      end
      
      robject_doc = build_robject(@visitor.methods)

      puts robject_doc.get
    end

    def build_robject(methods)
      source = new_source

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

      document = source_to_document(source)
    end

    class Visitor
      include JDTUtils

      include org.jruby.ast.visitor.NodeVisitor

      attr_accessor :sources
      attr_accessor :method_decls
      attr_accessor :class_decl

      def initialize
        @methods = {}
        @classes = []
        @sources = []
        @method_decls = []
        @class_decl = nil
      end

      attr_accessor :methods

      def method_missing(name, node)
        node.child_nodes.each {|n| n.accept self}
      end

      def visitClassNode(node)
        start_class(node.cpath.name, node.child_nodes)
      end

      def start_class(name, nodes, main = false)
        @class_name = name

        new_source.tap do |source|
          sources.push source
          ast = source.ast
          @class_decl = ast.new_type_declaration
          class_decl.interface = false
          class_decl.name = ast.new_simple_name(@class_name)
          class_decl.superclass_type = ast.new_simple_type(ast.new_simple_name("RObject"))

          source.types << class_decl

          if main
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

            ruby_main = ast.new_method_declaration
            ruby_main.name = ast.new_simple_name "_main_"
            ruby_main.return_type2 = ast.new_simple_type(ast.new_simple_name("RObject"))

            body = ast.new_block
            last_var = ast.new_single_variable_declaration
            last_var.name = ast.new_simple_name("$last")
            last_var.type = ast.new_simple_type(ast.new_simple_name("ROBject"))
            nil_load = ast.new_field_access
            nil_load.name = ast.new_simple_name("RNil")
            last_assignment = ast.new_assignment
            last_assignment.left_hand_side = ast.new_simple_name("$last")
            last_assignment.right_hand_side = nil_load
            body.statements << ast.new_expression_statement(last_assignment)

            ruby_main.body = body

            method_decls.push ruby_main
            class_decl.body_declarations << ruby_main

            @in_def = true
          end

          nodes.each {|n| n.accept self}

          if main
            ruby_main = method_decls.pop
            return_last = ast.new_return_statement
            return_last.expression = ast.new_simple_name("$last")
            @in_def = false
          end
        end
      end

      def visitCallNode(node)
        @methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
        node.receiver_node.accept(self)
        print ".#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self} if node.args_node
        print ")"
      end

      def visitFCallNode(node)
        @methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
        print "#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self} if node.args_node
        print ")"
      end

      def visitVCallNode(node)
        @methods[safe_name(node.name)] = 0
        print "#{safe_name(node.name)}();"
      end

      def visitDefnNode(node)
        @in_def = true

        arity = node.args_node.pre ? node.args_node.pre.child_nodes.size : 0;
        proper_name = safe_name(node.name)
        @methods[proper_name] = arity
        args = arity > 0 ? node.args_node.pre.child_nodes.to_a.map(&:name) : []
        args.map! {|a| "RObject #{a}"}
        source = sources.last
        ast = source.ast

        method_decl = ast.new_method_declaration
        method_decl.name = ast.new_simple_name(proper_name)

        class_decl.body_declarations << method_decl
        method_decl.modifiers << ast.new_modifier(ModifierKeyword::PUBLIC_KEYWORD)
        robject_type = ast.new_simple_type(ast.new_simple_name("ROBject"))

        unless node.name == "initialize"
          method_decl.return_type2 = robject_type
        end

        args.each do |a|
          arg_decl = ast.new_single_variable_declaration
          arg_decl.name = ast.new_simple_name('a')
          arg_decl.type = ast.new_simple_type(ast.new_simple_name("ROBject"))
          method_decl.parameters << arg_decl
        end

        body = ast.new_block
        last_var = ast.new_single_variable_declaration
        last_var.name = ast.new_simple_name("$last")
        last_var.type = ast.new_simple_type(ast.new_simple_name("ROBject"))
        nil_load = ast.new_field_access
        nil_load.name = ast.new_simple_name("RNil")
        last_assignment = ast.new_assignment
        last_assignment.left_hand_side = ast.new_simple_name("$last")
        last_assignment.right_hand_side = nil_load
        body.statements << ast.new_expression_statement(last_assignment)

        method_decl.body = body

        method_decls << method_decl

        node.body_node.accept(self) if node.body_node

        unless node.name == "initialize"
          return_last = ast.new_return_statement
          return_last.expression = ast.new_simple_name("$last")
          body.statements << return_last
        end

        @in_def = false
      end

      def visitStrNode(node)
        print "new RString(\"#{node.value}\")"
      end

      def visitFixnumNode(node)
        print "new RFixnum(#{node.value})"
      end

      def visitNewlineNode(node)
        print "        __last = " if @in_def
        node.next_node.accept(self)
        print ";" if @in_def
        puts
      end

      def visitNilNode(node)
        print "RNil"
      end

      def visitIfNode(node)
        print "if ("
        node.condition.accept(self)
        print ".toBoolean()) {\n"
        node.then_body.accept(self)
        if node.else_body
          print "} else {\n"
          node.else_body.accept(self)
        end
        print "}"
      end

      def visitLocalVarNode(node)
        print node.name
      end

      def visitConstDeclNode(node)
        print "    #{node.name} = "
        node.valueNode.accept(self)
      end

      def visitConstNode(node)
        print node.name
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