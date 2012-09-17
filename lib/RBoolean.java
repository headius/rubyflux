public class RBoolean extends RObject {
    public final boolean bool;
    public RBoolean(boolean bool) {
        this.bool = bool;
    }

    public RObject to_s() {
        return new RString(Boolean.toString(bool));
    }
}