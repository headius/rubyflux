public class RNil extends RObject {
    public static class NilMeta extends RClass {
        public NilMeta(String name) {
            super(name);
        }
        
        public NilMeta() {
            super("NilClass");
        }
    }
    
    public RClass $class() {
        return NilClass;
    }
    
    @Override
    public RString to_s() {
        return new RString("nil");
    }
    
    public RFixnum to_i() {
        return new RFixnum(0);
    }
}
