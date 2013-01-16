RubyFlux: a Ruby to Java compiler
----------------------------------

RubyFlux is a compiler that turns a Ruby codebase into a closed set of .java
source files suitable for running on any JVM with no additional runtime
requirement.

A .java file is produced for the toplevel of each file and for each Ruby class
declaration encountered. Methods are emitted as normal Java methods, but with
an abstract implementation on RObject so all dynamic calls can simply be
Java virtual calls. The rest of Ruby syntax maps to mostly what you'd expect
in Java code.

On the Net
==========

Github repository: https://github.com/headius/rubyflux

Mailing list: https://groups.google.com/forum/?fromgroups#!forum/ruby_flux

Getting Started
===============

1. Clone the repository
2. From the repo dir, run "mvn package". You only need to do this once.
3. Compile and/or run a target .rb file in one of several ways
    * Generate Java sources directly, compile, and run
        * `jruby -I target:src/main/ruby src/main/ruby/ruby\_flux.rb target.rb`
        * `javac target.java`
        * `java target`
    * Generate Java sources via the Rakefile
        * `rake compile[target.rb]
        * Sources are output to build/ in the same dir as target.rb
    * Generate, compile, and run via the Rakefile
        * `rake run[target.rb]

Usage
=====

Here's an example session for using RubyFlux today:

```
# The file we want to compile

$ cat fib.rb
def fib(a)
  if a < 2
    a
  else
    fib(a - 1) + fib(a - 2)
  end
end

puts fib(40)

# First need to build the compiler's jar

$ mvn package
<maven noise>

# Provide the target file to 'rake run'.
#
# The Ruby sources are translated to .java and all support code is copied out
# of RubyFlux for the compilation step. That source is then compiled and run.
# to compile

$ rake run[fib.rb]
jruby -I target:src/main/ruby src/main/ruby/ruby_flux.rb fib.rb
javac fib.java
java fib
102334155
```
