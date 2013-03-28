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

    def safe_name(name)
      new_name = ''

      case name
      when 'new'; new_name = '$new'
      when 'class'; new_name = '$class'
      else
        name.chars.each do |ch|
          new_name << case ch
            when '+'; '$plus'
            when '-'; '$minus'
            when '*'; '$times'
            when '/'; '$div'
            when '<'; '$less'
            when '>'; '$greater'
            when '='; '$equal'
            when '&'; '$tilde'
            when '!'; '$bang'
            when '%'; '$percent'
            when '^'; '$up'
            when '?'; '$qmark'
            when '|'; '$bar'
            when '['; '$lbrack'
            when ']'; '$rbrack'
            else; ch;
          end
        end
      end

      new_name
    end

    def proper_class(name)
      case name
      when 'String'
        'RString'
      when 'Array'
        'RArray'
      when 'Fixnum'
        'RFixnum'
      when 'Boolean'
        'RBoolean'
      when 'Float'
        'RFloat'
      when 'Time'
        'RTime'
      when 'Object'
        'RObject'
      else
        name
      end
    end
  end
end
