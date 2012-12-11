public class RKernel {
    public static final RObject RNil = new RObject();
    public static final RObject RTrue = new RBoolean(true);
    public static final RObject RFalse = new RBoolean(false);

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
        return new RString("#<" + getClass().getName() + ">");
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
}