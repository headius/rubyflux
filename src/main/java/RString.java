public class RString extends RObject implements CharSequence {
    private final String str;
    
    public static class StringMeta extends ObjectMeta {
        public StringMeta() {
            super("String");
        }
        
        @Override
        public RObject $new(RObject... args) {
            return new RString(args);
        }
        
        @Override
        public RObject $new(RObject arg) {
            return new RString(arg);
        }
    }

    public RString(String str) {
        this.str = str;
    }
    
    public RString(RObject arg) {
        this.str = arg.toString();
    }
    
    public RString(RObject... args) {
        if (args.length > 1) {
            throw new RuntimeException("too many arguments for String.new (" + args.length + " for 1)");
        }
        this.str = args[0].toString();
    }
    
    public RClass $class() {
        return RString;
    }

    public String toString() {
        return str;
    }

    public char charAt(int index) {
        return str.charAt(index);
    }

    public int length() {
        return str.length();
    }

    public CharSequence subSequence(int start, int end) {
        return str.subSequence(start, end);
    }
    
    public RObject to_s() {
        return this;
    }
    
    public Object to_java() {
        return str;
    }
    
    public RObject $percent(RObject arg) {
        return new RString(String.format(str, arg.to_java()));
    }

}
