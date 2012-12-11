require 'jruby'
require 'java'
require 'fastruby-1.0-SNAPSHOT.jar'
require 'fileutils'

require 'fast_ruby/compiler'
require 'fast_ruby/class_compiler'
require 'fast_ruby/method_compiler'
require 'fast_ruby/body_compiler'
require 'fast_ruby/statement_compiler'
require 'fast_ruby/expression_compiler'

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
end

if __FILE__ == $0
  if ARGV[0] == '-e'
    FastRuby::Compiler.new('-e', ARGV[1]).compile
  else
    FastRuby::Compiler.new(ARGV).compile
  end
end
