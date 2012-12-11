
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Iterator;
import java.util.List;
import java.util.ListIterator;

public class RArray extends RObject implements List<RObject> {
    public final ArrayList<RObject> impl;
    
    public RArray() {
        impl = new ArrayList<RObject>();
    }
    
    public RArray(RObject... args) {
        impl = new ArrayList<RObject>(Arrays.asList(args));
    }
    
    public RArray(List<RObject> impl) {
        this.impl = new ArrayList<RObject>(impl);
    }
    
    public RObject $less$less(RObject what) {
        add(what);
        
        return this;
    }
    
    public RObject $lbrack$rbrack(RObject where) {
        int index = (int)((RFixnum)where.to_i()).fix;
        
        if (index < size()) {
            return get(index);
        }
        
        return RNil;
    }
    
    public RObject $lbrack$rbrack$equal(RObject where, RObject what) {
        int index = (int)((RFixnum)where.to_i()).fix;
        
        // TODO index >= size
        impl.set(index, what);
        
        return this;
    }

    public int size() {
        return impl.size();
    }

    public boolean isEmpty() {
        return impl.isEmpty();
    }

    public boolean contains(Object o) {
        return impl.contains(o);
    }

    public Iterator<RObject> iterator() {
        return impl.iterator();
    }

    public Object[] toArray() {
        return impl.toArray();
    }

    public <T> T[] toArray(T[] a) {
        return impl.toArray(a);
    }

    public boolean add(RObject e) {
        return impl.add(e);
    }

    public boolean remove(Object o) {
        return impl.remove(o);
    }

    public boolean containsAll(Collection<?> c) {
        return impl.containsAll(c);
    }

    public boolean addAll(Collection<? extends RObject> c) {
        return impl.addAll(c);
    }

    public boolean addAll(int index, Collection<? extends RObject> c) {
        return impl.addAll(index, c);
    }

    public boolean removeAll(Collection<?> c) {
        return impl.removeAll(c);
    }

    public boolean retainAll(Collection<?> c) {
        return impl.retainAll(c);
    }

    public void clear() {
        impl.clear();
    }

    public RObject get(int index) {
        return impl.get(index);
    }

    public RObject set(int index, RObject element) {
        return impl.set(index, element);
    }

    public void add(int index, RObject element) {
        impl.add(index, element);
    }

    public RObject remove(int index) {
        return impl.remove(index);
    }

    public int indexOf(Object o) {
        return impl.indexOf(o);
    }

    public int lastIndexOf(Object o) {
        return impl.lastIndexOf(o);
    }

    public ListIterator<RObject> listIterator() {
        return impl.listIterator();
    }

    public ListIterator<RObject> listIterator(int index) {
        return impl.listIterator(index);
    }

    public List<RObject> subList(int fromIndex, int toIndex) {
        return new RArray(impl.subList(fromIndex, toIndex));
    }
}
