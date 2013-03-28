
import java.math.BigInteger;

public class RFixnum extends RObject {
    public final long fix;
    
    public static final RFixnum ZERO = new RFixnum(0);
    public static final RFixnum ONE = new RFixnum(1);
    public static final RFixnum TWO = new RFixnum(2);
    
    public static final class FixnumMeta extends ObjectMeta {
        public FixnumMeta() {
            super("Fixnum");
        }
    }
    
    public RFixnum(long fix) {
        this.fix = fix;
    }
    
    public RClass $class() {
        return RFixnum;
    }

    public RObject to_s() {
        return new RString(Long.toString(fix));
    }

    public RObject to_i() {
        return this;
    }
    
    public Object to_java() {
        return fix;
    }

    public RObject $plus(RObject other) {
        if (other instanceof RFloat) {
            return new RFloat(fix + ((RFloat)other).flo);
        } else {
            return new RFixnum(fix + ((RFixnum)other.to_i()).fix);
        }
    }

    public RObject $minus(RObject other) {
        if (other instanceof RFloat) {
            return new RFloat(fix - ((RFloat)other).flo);
        } else {
            return new RFixnum(fix - ((RFixnum)other.to_i()).fix);
        }
    }
    
    public RObject $div(RObject other) {
        if (other instanceof RFloat) {
            return new RFloat(fix / ((RFloat)other).flo);
        } else {
            return new RFixnum(fix / ((RFixnum)other.to_i()).fix);
        }
    }
    
    public RObject $times(RObject other) {
        if (other instanceof RFloat) {
            return new RFloat(fix * ((RFloat)other).flo);
        } else {
            return new RFixnum(fix * ((RFixnum)other.to_i()).fix);
        }
    }
    
    public RObject $times$times(RObject other) {
        if (other instanceof RFloat) {
            return new RFloat(Math.pow(fix, ((RFloat)other).flo));
        } else {
            return new RFixnum(new BigInteger(Long.toString(fix)).pow((int)((RFixnum)other.to_i()).fix).longValue());
        }
    }

    public RObject $equal$equal(RObject other) {
        if (other instanceof RFloat) {
            return fix == ((RFloat)other).flo ? RTrue : RFalse;
        } else {
            return fix == ((RFixnum)other.to_i()).fix ? RTrue : RFalse;
        }
    }

    public RObject $less$equal$greater(RObject other) {
        if (other instanceof RFloat) {
            return new RFixnum(Long.valueOf(fix).compareTo((long)((RFloat)other).flo));
        } else {
            return new RFixnum(Long.valueOf(fix).compareTo(((RFixnum)other.to_i()).fix));
        }
    }

    public RObject $less(RObject other) {
        if (other instanceof RFloat) {
            return fix < ((RFloat)other).flo ? RTrue : RFalse;
        } else {
            return fix < ((RFixnum)other.to_i()).fix ? RTrue : RFalse;
        }
    }

    public RObject $greater(RObject other) {
        if (other instanceof RFloat) {
            return fix > ((RFloat)other).flo ? RTrue : RFalse;
        } else {
            return fix > ((RFixnum)other.to_i()).fix ? RTrue : RFalse;
        }
    }

    public RObject $less$equal(RObject other) {
        if (other instanceof RFloat) {
            return fix <= ((RFloat)other).flo ? RTrue : RFalse;
        } else {
            return fix <= ((RFixnum)other.to_i()).fix ? RTrue : RFalse;
        }
    }

    public RObject $greater$equal(RObject other) {
        if (other instanceof RFloat) {
            return fix >= ((RFloat)other).flo ? RTrue : RFalse;
        } else {
            return fix >= ((RFixnum)other.to_i()).fix ? RTrue : RFalse;
        }
    }
}