FastRuby: a Ruby to Java compiler
----------------------------------

FasatRuby is a compiler that turns a Ruby codebase into a closed set of .java
source files suitable for running on any JVM with no additional runtime
requirement.

A .java file is produced for the toplevel of each file and for each Ruby class
declaration encountered. Methods are emitted as normal Java methods, but with
an abstract implementation on RObject so all dynamic calls can simply be
Java virtual calls. The rest of Ruby syntax maps to mostly what you'd expect
in Java code.

Usage
=====

Here's an example session for using FastRuby today:

```
# First need to build the compiler's jar
$ mvn package

# Provide the target dir to JRuby's -I flag along with -e or a group of files
# to compile
$ jruby -I target src/main/ruby/compiler.rb -e "def fib(a); a < 2 ? a : fib(a - 1) + fib(a - 2); end; puts fib(40)"

# The Ruby sources are translated to .java and all support code is copied out
# of FastRuby for the compilation step.
#
# A -e argument will produce a DashE.java file. A list of sources will produce
# a .java file for each.
$ javac DashE.java

# All files are now compiled and in cwd, and DashE can be run directly
$ java DashE
102334155
```

The resulting .class files can be packaged alone, with no runtime dependencies.
