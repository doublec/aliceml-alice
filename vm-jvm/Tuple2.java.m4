package de.uni_sb.ps.dml.runtime;

public class Tuple2 implements DMLTuple {

    protected DMLValue fst = null;
    protected DMLValue snd = null;

    public Tuple2(DMLValue eins,
		  DMLValue zwei) {
	fst=eins;
	snd=zwei;
    }

    public DMLValue get0() { return fst; }
    public DMLValue get1() { return snd; }
    public DMLValue get2() { throw new ArrayIndexOutOfBoundsException(); }
    public DMLValue get3() { throw new ArrayIndexOutOfBoundsException(); }
    public DMLValue get4() { throw new ArrayIndexOutOfBoundsException(); }

    final public boolean equals(Object val) {
	return (val instanceof Tuple2) &&
	    fst.equals(((Tuple2) val).fst) &&
	    snd.equals(((Tuple2) val).snd);
    }

    public String toString() {
	return "("+fst+", "+snd+")";
    }

    /** gibt den i-ten Eintrag des Tuples oder Records*/
    final public DMLValue getByIndex(int i){
	switch (i) {
	case 0: return fst;
	case 1: return snd;
	default: throw new ArrayIndexOutOfBoundsException();
	}
    }

    /** gibt die Stelligkeit des Tuples oder Records an */
    final public int getArity() {
	return 2;
    }

    final public DMLValue[] getVals() {
	DMLValue[] vals = {fst,snd};
	return vals;
    }

    final public DMLValue getValue() {
	return this;
    }

    final public DMLValue request() {
	return this;
    }

    final public DMLValue apply(DMLValue val) {
	return DMLConstants.runtimeError.apply(new DMLString("cannot apply "+this+" to "+val)).raise();
    }

    final public DMLValue raise() {
	throw new DMLExceptionWrapper(this);
    }
}
