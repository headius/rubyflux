require 'ruby_flux-1.0-SNAPSHOT.jar'

java_import org.eclipse.jdt.core.dom.AST
java_import org.eclipse.jdt.core.dom.ASTParser
java_import org.eclipse.jdt.core.dom.rewrite.ASTRewrite
java_import org.eclipse.jface.text.Document

parser = ASTParser.newParser(AST::JLS3)
parser.source = ''.to_java.to_char_array

cu = parser.create_ast(nil)
cu.record_modifications

parser2 = ASTParser.newParser(AST::JLS3)
parser2.source = ''.to_java.to_char_array

cu2 = parser2.create_ast(nil)
cu2.record_modifications

ast = cu.ast
package = ast.new_package_declaration
package.name = ast.new_simple_name 'com'

cu.package = package

type = ast.new_type_declaration
type.interface = false
type.name = ast.new_simple_name('Hello')

cu.types.add(type)

ast2 = cu2.ast
package = ast2.new_package_declaration
package.name = ast2.new_name('foo.bar')

cu2.package = package

document = Document.new
text_edit = cu.rewrite(document, nil)

text_edit.apply document

puts document.get

document = Document.new
text_edit = cu2.rewrite(document, nil)

text_edit.apply document

puts document.get
