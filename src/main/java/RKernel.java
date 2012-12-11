public class RKernel {
    public static final RObject RNil = new RObject();
    public static final RObject RTrue = new RBoolean(true);
    public static final RObject RFalse = new RBoolean(false);

    public RObject puts(RObject... objects) {
        for (RObject object : objects) System.out.println(object);
        return RNil;
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

    public String toString() {
        return to_s().toString();
    }

    public boolean toBoolean() {
        if (this == RNil || this == RFalse) return false;
        return true;
    }
}