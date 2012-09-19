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
        old_stdout = $stdout.dup
        $stdout.reopen(f)
        puts "public class RObject extends RKernel {"
        methods.each {|name, arity|
          next if BUILTINS.include? name
          args = arity > 0 ? (0..(arity - 1)).to_a.map {|i| "RObject arg#{i}"}.join(", ") : ""
          puts "    public RObject #{safe_name(name)}(#{args}) {"
          puts "        throw new UnsupportedOperationException(\"#{name} (a.k.a. #{safe_name(name)})\");"
          puts "    }"
        }
        puts "}"
        $stdout.reopen(old_stdout)
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
      end

      attr_accessor :methods

      def method_missing(name, node)
        node.child_nodes.each {|n| n.accept self}
      end

      def visitClassNode(node)
        @node_stack.push node
        @class_name = node.cpath.name
        File.open("#{@class_name}.java", 'w') do |f|
          old_stdout = $stdout.dup
          $stdout.reopen(f)
          puts "public class #{@class_name} extends RObject {"
          node.child_nodes.each {|n| n.accept self}
          puts
          @fields.uniq.sort!.each { |f| puts "    private RObject #{safe_name(f)};" }
          puts "}"
          $stdout.reopen(old_stdout)
        end
        @node_stack.pop
      end

      def visitCallNode(node)
        @node_stack.push node
        node.receiver_node.accept(self)
        print "."
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
        print "#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self}
        print ")"
        @node_stack.pop
      end

      def visitVCallNode(node)
        @node_stack.push node
        @methods[node.name] = 0
        print "#{safe_name(node.name)}();"
        @node_stack.pop
      end

      def visitDefnNode(node)
        @node_stack.push node
        arity = node.args_node.pre ? node.args_node.pre.child_nodes.size : 0;
        args = arity > 0 ? "RObject " + node.args_node.pre.child_nodes.to_a.map(&:name).join(", RObject ") : ""
        if in_ctor?
          puts "    public #{safe_name(current_class.cpath.name)}(#{args}) {"
          node.body_node.accept(self) if node.body_node
        elsif
          @methods[node.name] = arity
          puts "    public RObject #{safe_name(node.name)}(#{args}) {"
          puts "        RObject __last = RNil;"
          node.body_node.accept(self) if node.body_node
          puts "        return __last;"
        end
        puts "    }"
        @node_stack.pop
      end

      def visitStrNode(node)
        print "new RString(\"#{node.value}\")"
      end

      def visitFixnumNode(node)
        print "new RFixnum(#{node.value})"
      end

      def visitNewlineNode(node)
        print "        __last = " if in_method? && statement?(node.next_node)
        node.next_node.accept(self)
        print "; // #{node.position.start_line}" if ((in_method? or in_ctor?) and statement?(node.next_node))
        puts
      end

      def visitNilNode(node)
        print "RNil"
      end

      def visitIfNode(node)
        @node_stack.push node
        print "if ("
        @stmt_stack.push false
        node.condition.accept(self)
        @stmt_stack.pop
        print ".toBoolean()) {\n"
        node.then_body.accept(self)
        if node.else_body
          print "} else {\n"
          node.else_body.accept(self)
        end
        print "}"
        @node_stack.pop
      end

      def visitInstAsgnNode(node)
        @node_stack.push node
        name = node.name[1..-1]
        @fields.push name
        print "(" unless in_ctor?
        print "this.#{name} = "
        node.child_nodes.each { |n| n.accept self }
        print ")" unless in_ctor?
        @node_stack.pop
      end

      def visitLocalVarNode(node)
        print node.name
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