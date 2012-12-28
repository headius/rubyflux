module RubyFlux
  module JDTUtils
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
  end
end
