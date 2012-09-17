require 'jruby'
require 'java'
Char = java.lang.Character
import org.jruby.ast.IfNode

module FastRuby
  BUILTINS = %w[puts]

  class Compiler
    def initialize(files)
      @files = files
      @visitor = Visitor.new
    end

    def compile
      @files.each do |file|
        ast = JRuby.parse(File.read(file))
        ast.accept(@visitor)
      end

      methods = @visitor.methods

      File.open("RObject.java", 'w') do |f|
        old_stdout = $stdout.dup
        $stdout.reopen(f)
        puts "public class RObject extends RKernel {"
        methods.each {|name, arity|
          next if BUILTINS.include? name
          args = arity > 0 ? (0..(arity - 1)).to_a.map {|i| "RObject arg#{i}"} : []
          puts "    public #{return_type(name)} #{name}(#{args.join(", ")}) {"
          puts "        throw new RuntimeException(\"#{name}\");"
          puts "    }"
        }
        puts "}"
        $stdout.reopen(old_stdout)
      end
    end
    
    def return_type(name)
      name == "initialize" ? "void" : "RObject"
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
        @class_name = node.cpath.name
        File.open("#{@class_name}.java", 'w') do |f|
          old_stdout = $stdout.dup
          $stdout.reopen(f)
          puts "public class #{@class_name} extends RObject {"
          node.child_nodes.each {|n| n.accept self}
          puts "}"
          $stdout.reopen(old_stdout)
        end
      end

      def visitCallNode(node)
        @methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
        node.receiver_node.accept(self)
        print ".#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self}
        print ")"
      end

      def visitFCallNode(node)
        @methods[safe_name(node.name)] = node.args_node ? node.args_node.child_nodes.size : 0
        print "#{safe_name(node.name)}("
        first = true
        node.args_node.child_nodes.each {|n| print ", " unless first; first = false; n.accept self}
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
        print "    public #{return_type(node.name)} "
#        print node.name == "initialize" ? "void " : "RObject "
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
        print "        __last = " if store_last(node)
        node.next_node.accept(self)
        print "; // #{node.position.start_line}" if store_last(node)
        puts
      end

      def visitNilNode(node)
        print "RNil"
      end

      def visitIfNode(node)
        print "if ("
        @in_def = false
        node.condition.accept(self)
        @in_def = true
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

      def store_last(node)
        @in_def unless { IfNode => true }[node.next_node.class]
      end

      def return_type(name)
        name == "initialize" ? "void" : "RObject"
      end

      def safe_name(name)
        name.gsub(/[^a-zA-Z0-9_]/) { |s| "__#{Char.getName(s[0].to_i).gsub(/[^a-zA-Z0-9_]/, '_')}" }
      end
    end
  end
end

if __FILE__ == $0
  FastRuby::Compiler.new(ARGV).compile
end