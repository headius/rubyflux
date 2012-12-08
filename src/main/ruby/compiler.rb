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

  class Compiler
    def initialize(files)
      @files = files
      @visitor = Visitor.new
    end

    def compile
      @files.each do |file|
        ast = JRuby.parse(File.read(file))
        @visitor.start_class(File.basename(file).split('.')[0], ast.child_nodes, true)
      end

      methods = @visitor.methods
      
      robject_doc = build_robject(methods)
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

      puts document.get
    end

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

    class Visitor
      include org.jruby.ast.visitor.NodeVisitor

      def initialize
        @methods = {}
        @classes = []
      end

      attr_accessor :methods

      def method_missing(name, node)
        node.child_nodes.each {|n| n.accept self}
      end

      def visitClassNode(node)
        start_class(node.cpath.name, node.child_nodes)
      end

      def start_class(name, nodes, main = false)
=begin
        @class_name = name
        @cls = @model._class(@class_name)
        @cls._extends model.direct_class "RObject"

        if main
          main = @model.method(JMod::PUBLIC | JMod::STATIC, model.direct_class "void", "main")
          main.param(model.direct_class "String[]", "args")
          main.direct_statement "new #{@class_name}()._main_();"

          @method = @model.method(JMod::PUBLIC, model.direct_class "RObject", "main")
          @__last = @method.body.decl model.direct_class("RObject"), "__last"
          @method.body.assign(@__last, )
        end

        nodes.each {|n| n.accept self}

          methods.each do |name, arity|
            cls.method(JMod::PUBLIC, cls, name).tap do |method|
              if arity > 0
                (0..(arity - 1)).to_a.map {|i| method.param(cls, "arg#{i}")}
              end

              method.body.tap do |body|
                body.direct_statement "throw new RuntimeException(\"#{name}\");"
              end
            end
          end
        end

        model.build(java.io.File.new('.'))
        File.open("#{@class_name}.java", 'w') do |f|
          old_stdout = $stdout.dup
          $stdout.reopen(f)
          puts "public class #{@class_name} extends RObject {"
          if main
            puts "    public static void main(String[] args) {"
            puts "        new #{@class_name}()._main_();"
            puts "    }"
            puts
            puts "    public RObject _main_() {"
            puts "        RObject __last = RNil;"
            @in_def = true
          end
          nodes.each {|n| n.accept self}
          if main
            puts "        return __last;"
            puts "    }"
            @in_def = false
          end
          puts "}"
          $stdout.reopen(old_stdout)
        end
=end
        nodes.each {|n| n.accept self}
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
        @methods[safe_name(node.name)] = arity
        args = arity > 0 ? node.args_node.pre.child_nodes.to_a.map(&:name) : []
        args.map! {|a| "RObject #{a}"}
        print "    public "
        print "RObject " unless node.name == "initialize"
        puts "#{safe_name(node.name)}(#{args.join(", ")}) {"
        puts "        RObject __last = RNil;"
        node.body_node.accept(self) if node.body_node
        puts "        return __last;" unless node.name == "initialize"
        puts "    }"
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