require 'jruby'
require 'java'
require 'ruby_flux-1.0-SNAPSHOT.jar'
require 'fileutils'

require 'ruby_flux/compiler'
require 'ruby_flux/class_compiler'
require 'ruby_flux/method_compiler'
require 'ruby_flux/body_compiler'
require 'ruby_flux/statement_compiler'
require 'ruby_flux/expression_compiler'

module RubyFlux
  BUILTINS = %w[puts print $class to_i to_int to_s to_f initialize $new $equal$equal]

  Char = java.lang.Character
  java_import org.eclipse.jdt.core.dom.AST
  java_import org.eclipse.jdt.core.dom.ASTParser
  java_import org.eclipse.jdt.core.dom.rewrite.ASTRewrite
  java_import org.eclipse.jface.text.Document
  java_import org.eclipse.jdt.core.dom.Modifier
  ModifierKeyword = Modifier::ModifierKeyword
  java_import org.eclipse.jdt.core.JavaCore
  java_import org.eclipse.jdt.core.formatter.DefaultCodeFormatterConstants
  java_import org.eclipse.jdt.core.dom.InfixExpression
  InfixOperator = InfixExpression::Operator

  COPIED_SOURCES = %w[
    RNil.java
    RKernel.java
    RFixnum.java
    RBoolean.java
    RString.java
    RFloat.java
    RArray.java
    RTime.java
    RClass.java
  ]
end

if __FILE__ == $0
  if ARGV[0] == '-e'
    RubyFlux::Compiler.new('-e', ARGV[1]).compile
  else
    RubyFlux::Compiler.new(ARGV).compile
  end
end
