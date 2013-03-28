public class RKernel {
    public static final RObject RNil = new RNil();
    public static final RObject RTrue = new RBoolean(true);
    public static final RObject RFalse = new RBoolean(false);
    public static final RString.StringMeta RString = new RString.StringMeta();
    public static final RArray.ArrayMeta RArray = new RArray.ArrayMeta();
    public static final RTime.TimeMeta RTime = new RTime.TimeMeta();
    public static final RBoolean.BooleanMeta RBoolean = new RBoolean.BooleanMeta();
    public static final RFixnum.FixnumMeta RFixnum = new RFixnum.FixnumMeta();
    public static final RFloat.FloatMeta RFloat = new RFloat.FloatMeta();
    public static final RNil.NilMeta NilClass = new RNil.NilMeta();
    
    public static final RObject[] NULL_ARRAY = new RObject[0];
    
    public static class ObjectMeta extends RClass {
        public ObjectMeta(String name) {
            super(name);
        }
        
        public ObjectMeta() {
            super("Object");
        }
        
        public RObject allocate() {
            return new RObject();
        }
    }
    public static final ObjectMeta RObject = new ObjectMeta();

    public RObject puts(RObject... objects) {
        if (objects.length == 0) {
            System.out.println();
        } else {
            for (RObject object : objects) {
                System.out.println(object.to_s());
            }
        }
        return RNil;
    }

    public RObject print(RObject object) {
        System.out.print(object.to_s());
        return RNil;
    }

    public RObject $equal$equal(RObject other) {
        return this == other ? RTrue : RFalse;
    }

    public RObject to_i() {
        throw new RuntimeException("can't convert to Fixnum: " + getClass().getName());
    }
    
    public RObject to_int() {
        return to_i();
    }

    public RObject to_f() {
        throw new RuntimeException("can't convert to Float: " + getClass().getName());
    }

    public RObject to_s() {
        return new RString("#<" + $class().name() + ">");
    }
    
    public Object to_java() {
        return this;
    }

    public String toString() {
        return to_s().toString();
    }

    public boolean toBoolean() {
        if (this == RNil || this == RFalse) return false;
        return true;
    }

    public RObject method_missing(RObject name, RObject args) {
        throw new RuntimeException("Method '" + name + "' not defined on type " + getClass().getName());
    }
    
    public RClass $class() {
        Thread.dumpStack();
        System.out.println(getClass());
        return RObject;
    }
    
    public RObject initialize() {
        return RNil;
    }
    
    public RObject initialize(RObject... args) {
        throw new RuntimeException("too many args for #initialize (" + args.length + " for 0)");
    }
}
