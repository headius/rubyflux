public class RBoolean extends RObject {
    public final boolean bool;
    
    public static class BooleanMeta extends ObjectMeta {
        public BooleanMeta() {
            super("Boolean");
        }
    }
    
    public RBoolean(boolean bool) {
        this.bool = bool;
    }
    
    public RClass $class() {
        return RBoolean;
    }

    public RObject to_s() {
        return new RString(Boolean.toString(bool));
    }
}