
import java.util.Calendar;
import java.util.GregorianCalendar;

public class RTime extends RObject {
    public final Calendar cal;
    
    public RTime() {
        this(new GregorianCalendar());
    }
    
    public RTime(Calendar cal) {
        this.cal = cal;
    }
    
    public RObject to_s() {
        return new RString(cal.toString());
    }

    public RObject to_int() {
        return new RFixnum(cal.getTimeInMillis());
    }
    
    public RObject to_f() {
        return new RFloat(cal.getTimeInMillis() / 1000.0);
    }
    
    public Object to_java() {
        return cal;
    }
    
    public RObject $minus(RObject other) {
        if (other instanceof RTime) {
            return new RFloat(cal.getTimeInMillis() / 1000.0 - ((RTime)other).cal.getTimeInMillis() / 1000.0);
        }
        
        throw new RuntimeException(other.getClass().getName() + " is not a Time object");
    }
}
