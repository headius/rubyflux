public class RFixnum extends RObject {
    public final long fix;
    public RFixnum(long fix) {
        this.fix = fix;
    }

    public RObject to_s() {
        return new RString(Long.toString(fix));
    }

    public RObject to_int() {
        return this;
    }

    public RObject _plus_(RObject other) {
        return new RFixnum(fix + ((RFixnum)other.to_int()).fix);
    }

    public RObject _minus_(RObject other) {
        return new RFixnum(fix - ((RFixnum)other.to_int()).fix);
    }

    public RObject _lt_(RObject other) {
        return fix < ((RFixnum)other.to_int()).fix ? RTrue : RFalse;
    }
}