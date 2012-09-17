public class RString extends RObject implements CharSequence {
    private final String str;

    public RString(String str) {
        this.str = str;
    }

    public String toString() {
        return str;
    }

    //public RObject _aref_(RObject index) {
    //
    //}

    public char charAt(int index) {
        return str.charAt(index);
    }

    public int length() {
        return str.length();
    }

    public CharSequence subSequence(int start, int end) {
        return str.subSequence(start, end);
    }

}
