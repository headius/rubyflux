public class RFloat extends RObject {
    public final double flo;
    
    public static class FloatMeta extends ObjectMeta {
        public FloatMeta() {
            super("Float");
        }
    }
    
    public RFloat(double flo) {
        this.flo = flo;
    }
    
    public RClass $class() {
        return RFloat;
    }
    
    public RObject to_s() {
        return new RString(Double.toString(flo));
    }

    public RObject to_int() {
        return new RFixnum((long)flo);
    }
    
    public RObject to_f() {
        return this;
    }
    
    public Object to_java() {
        return flo;
    }

    public RObject $plus(RObject other) {
        if (other instanceof RFixnum) {
            return new RFloat(flo + ((RFixnum)other).fix);
        } else {
            return new RFloat(flo + ((RFloat)other.to_f()).flo);
        }
    }

    public RObject $minus(RObject other) {
        if (other instanceof RFixnum) {
            return new RFloat(flo - ((RFixnum)other).fix);
        } else {
            return new RFloat(flo - ((RFloat)other.to_f()).flo);
        }
    }
    
    public RObject $div(RObject other) {
        if (other instanceof RFixnum) {
            return new RFloat(flo / ((RFixnum)other).fix);
        } else {
            return new RFloat(flo / ((RFloat)other.to_f()).flo);
        }
    }
    
    public RObject $times(RObject other) {
        if (other instanceof RFixnum) {
            return new RFloat(flo * ((RFixnum)other).fix);
        } else {
            return new RFloat(flo * ((RFloat)other.to_f()).flo);
        }
    }
    
    public RObject $times$times(RObject other) {
        if (other instanceof RFixnum) {
            return new RFloat(Math.pow(flo, ((RFixnum)other).fix));
        } else {
            return new RFloat(Math.pow(flo, ((RFloat)other.to_f()).flo));
        }
    }

    public RObject $equal$equal(RObject other) {
        if (other instanceof RFixnum) {
            return flo == ((RFixnum)other).fix ? RTrue : RFalse;
        } else {
            return flo == ((RFloat)other.to_f()).flo ? RTrue : RFalse;
        }
    }

    public RObject $less$equal$greater(RObject other) {
        if (other instanceof RFixnum) {
            return new RFixnum(Double.compare(flo, ((RFixnum)other).fix));
        } else {
            return new RFloat(Double.compare(flo, ((RFloat)other.to_f()).flo));
        }
    }

    public RObject $less(RObject other) {
        if (other instanceof RFixnum) {
            return flo < ((RFixnum)other).fix ? RTrue : RFalse;
        } else {
            return flo < ((RFloat)other.to_f()).flo ? RTrue : RFalse;
        }
    }

    public RObject $greater(RObject other) {
        if (other instanceof RFixnum) {
            return flo > ((RFixnum)other).fix ? RTrue : RFalse;
        } else {
            return flo > ((RFloat)other.to_f()).flo ? RTrue : RFalse;
        }
    }

    public RObject $greater$equal(RObject other) {
        if (other instanceof RFixnum) {
            return flo >= ((RFixnum)other).fix ? RTrue : RFalse;
        } else {
            return flo >= ((RFloat)other.to_f()).flo ? RTrue : RFalse;
        }
    }

    public RObject $less$equal(RObject other) {
        if (other instanceof RFixnum) {
            return flo <= ((RFixnum)other).fix ? RTrue : RFalse;
        } else {
            return flo <= ((RFloat)other.to_f()).flo ? RTrue : RFalse;
        }
    }
}
