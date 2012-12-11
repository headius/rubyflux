public class RString extends RObject implements CharSequence {
    private final String str;

    public RString(String str) {
        this.str = str;
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
