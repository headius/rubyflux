public abstract class RClass extends RObject {
    protected final RString name;
    
    public RClass(String name) {
        this.name = new RString(name);
    }
    
    public String toString() {
        return name.toString();
    }
    
    public RObject to_s() {
        return name;
    }
    
    public RObject $new(RObject... args) {
        RObject object = allocate();
        object.initialize(args);
        return object;
    }
    
    public RObject $new() {
        RObject object = allocate();
        object.initialize();
        return object;
    }
    
    public RObject $new(RObject arg) {
        RObject object = allocate();
        object.initialize(arg);
        return object;
    }
    
    public RObject allocate() {
        throw new RuntimeException("not allocatable: " + name);
    }
        
    public RObject name() {
        return new RString(name);
    }
}
