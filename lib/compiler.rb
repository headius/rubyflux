require 'jruby'
require 'java'

module FastRuby
  import java.lang.Character
  BUILTINS = %w[puts]

  @@safe_names = {} # ruby name -> java/safe name

  def safe_name(name)
    @@safe_names[name] || @@safe_names[name] = name.gsub(/[^a-zA-Z0-9_]/) do |s|
      "__#{Character.getName(s[0].to_i).gsub(/[^a-zA-Z0-9_]/, '_').downcase!}"
    end
  end

  def safe_name?(name)
    safe_name(name) == name
  end

  class JavaWriter
    def initialize(file, indent = 4)
      @f = file
      @indent = indent
      @lpad = ""
      @on_newline = true
    end
    def emit(line, dedent = false, indent = false)
      @lpad = ' '.*(@lpad.length - @indent) if dedent
      @f << (@on_newline ? @lpad : '') << line
      @on_newline = line.end_with? "\n"
      @lpad = ' '.*(@lpad.length + @indent) if indent
    end
    def <<(arg)
      case arg
      when /\}\s*else\s*\{\s*$/
        # @lpad = ' '.*(@lpad.length - @indent);
        emit arg + "\n", true, true
        # @lpad = ' '.*(@lpad.length + @indent)
      when /\{\s*$/
        emit arg + "\n", false, true
        # @lpad = ' '.*(@lpad.length + @indent)
      when /\}\s*$/
        # @lpad = ' '.*(@lpad.length - @indent)
        emit arg + "\n", true
      when /\;\s*$/
        emit arg + "\n"
      else
        emit arg
      end
      self
    end
  end

  class Compiler
    include FastRuby
    def initialize(files, dump_ast = false)
      @files = files
      @visitor = Visitor.new
      @dump_ast = dump_ast
    end

    def compile
      @files.each do |file|
        ast = JRuby.parse(File.read(file))
        puts ast if @dump_ast
        ast.accept(@visitor)
      end

      methods = @visitor.methods

      File.open("RObject.java", 'w') do |f|
        w = JavaWriter.new f
        w << "public class RObject extends RKernel {"
        methods.each do |name, arity|
          next if BUILTINS.include? name
          args = arity > 0 ? (0..(arity - 1)).to_a.map {|i| "RObject arg#{i}"}.join(', ') : ''
          w << "public RObject #{safe_name(name)}(#{args}) {"
          aka = safe_name?(name) ? " (#{safe_name(name)})" : ""
          w << "throw new UnsupportedOperationException(\"#{name}#{aka}\");"
          w << "}"
        end
        w << "}"
      end
    end
    
    class Visitor
      include FastRuby, org.jruby.ast.visitor.NodeVisitor
      import "org.jruby.ast"

      def initialize
        @methods = {} # ruby name -> arity
        @fields  = [] # ruby_name
        @node_stack = []
        @stmt_stack = [true] # assume true unless suppressed
        @w = ""
      end

      attr_accessor :methods
      
      def method_missing(name, node)
        node.child_nodes.each {|n| n.accept self}
      end

      def visitClassNode(node)
        @node_stack.push node
        @class_name = node.cpath.name
        File.open("#{@class_name}.java", 'w') do |f|
          @w = JavaWriter.new f
          @w << "public class #{@class_name} extends RObject {"
          node.child_nodes.each {|n| n.accept self}
          @fields.uniq.sort!.each { |f| @w << "private RObject #{safe_name(f)};" }
          @w << "}"
          @w = nil
        end
        @node_stack.pop
      end

      def visitCallNode(node)
        @node_stack.push node
        node.receiver_node.accept(self)
        @w << "."
        do_call_node(node)
        @node_stack.pop
      end

      def visitFCallNode(node)
        @node_stack.push node
        do_call_node(node)
        @node_stack.pop
      end

      def do_call_node(node)
        @node_stack.push node
        @methods[node.name] = node.args_node ? node.args_node.child_nodes.size : 0
        @w << "#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self}
        @w << ")"
        @node_stack.pop
      end

      def visitVCallNode(node)
        @node_stack.push node
        @methods[node.name] = 0
        @w << "#{safe_name(node.name)}();"
        @node_stack.pop
      end

      def visitDefnNode(node)
        @node_stack.push node
        arity = node.args_node.pre ? node.args_node.pre.child_nodes.size : 0;
        args = arity > 0 ? "RObject " + node.args_node.pre.child_nodes.to_a.map(&:name).join(", RObject ") : ""
        if in_ctor?
          @w << "public #{safe_name(current_class.cpath.name)}(#{args}) {"
          node.body_node.accept(self) if node.body_node
        elsif
          @methods[node.name] = arity
          @w << "public RObject #{safe_name(node.name)}(#{args}) {"
          @w << "RObject __last = RNil;"
          node.body_node.accept(self) if node.body_node
          @w << "return __last;"
        end
        @w << "}"
        @node_stack.pop
      end

      def visitStrNode(node)
        @w << "new RString(\"#{node.value}\")"
      end

      def visitFixnumNode(node)
        @w << "new RFixnum(#{node.value})"
      end

      def visitNewlineNode(node)
        @w << "__last = " if in_method? and statement?(node.next_node)
        node.next_node.accept(self)
        @w << ";" if ((in_method? or in_ctor?) and statement?(node.next_node))
      end

      def visitNilNode(node)
        @w << "RNil"
      end

      def visitIfNode(node)
        @node_stack.push node
        @w << "if ("
        @stmt_stack.push false
        node.condition.accept(self)
        @stmt_stack.pop
        @w << ".toBoolean()) {"
        node.then_body.accept(self)
        if node.else_body
          @w << "} else {"
          node.else_body.accept(self)
        end
        @w << "}"
        @node_stack.pop
      end

      def visitInstAsgnNode(node)
        @node_stack.push node
        name = node.name[1..-1]
        @fields.push name
        @w << "(" unless in_ctor?
        @w << "this.#{name} = "
        node.child_nodes.each { |n| n.accept self }
        @w << ")" unless in_ctor?
        @node_stack.pop
      end

      def visitLocalVarNode(node)
        @w << node.name
      end

      def current_class
        @node_stack.reverse.find { |n| n.is_a? ClassNode }
      end

      def in_ctor?
        @node_stack.any? { |n| n.is_a? DefnNode and n.name == "initialize" }
      end

      def in_method?
        @node_stack.any? { |n| n.is_a? DefnNode and n.name != "initialize" }
      end

      def statement?(node)
        @stmt_stack.last and [IfNode].none? { |c| node.is_a? c }
      end
    end
  end
end

if __FILE__ == $0
  require 'getoptlong'
  opts = GetoptLong.new(
    ["--ast", "-a", GetoptLong::NO_ARGUMENT],
    ["--help", "-h", GetoptLong::NO_ARGUMENT]
  )
  ast = false
  
  opts.each do |opt,arg|
    case opt
    when '--ast'
      ast = true
    when '--help'
      puts "jruby compiler.rb [options] file...
      --ast   dump the abstract syntax tree to stdout.
      --help  display this help message and exit."
      exit 0
    end
  end
  
  FastRuby::Compiler.new(ARGV, ast).compile unless ARGV.empty?
end