require 'jruby'
require 'java'
Char = java.lang.Character

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
        @visitor.start_class(File.basename(file).split('.')[0], ast.child_nodes, true)
      end

      methods = @visitor.methods

      File.open("RObject.java", 'w') do |f|
        old_stdout = $stdout.dup
        $stdout.reopen(f)
        puts "public class RObject extends RKernel {"
        methods.each {|name, arity|
          next if BUILTINS.include? name
          args = arity > 0 ? (0..(arity - 1)).to_a.map {|i| "RObject arg#{i}"} : []
          puts "    public RObject #{name}(#{args.join(", ")}) {"
          puts "        throw new RuntimeException(\"#{name}\");"
          puts "    }"
        }
        puts "}"
        $stdout.reopen(old_stdout)
      end
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
        @class_name = name
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