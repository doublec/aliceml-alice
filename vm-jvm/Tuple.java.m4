/*
 * Author:
 *      Daniel Simon, <dansim@ps.uni-sb.de>
 *
 * Copyright:
 *      Daniel Simon, 1999
 *
 * Last change:
 *    $Date$ by $Author$
 * $Revision$
 *
 */
package de.uni_sb.ps.dml.runtime;

import java.rmi.RemoteException;

/** Tuple-Darstellung in DML.
 *  @see Record
 */
public class Tuple implements DMLTuple {

    public DMLValue vals[];

    public Tuple() {}

    public Tuple(DMLValue[] v) {
	vals=v;
    }

    final public DMLValue get0() { return vals[0]; }
    final public DMLValue get1() { return vals[1]; }
    final public DMLValue get2() { return vals[2]; }
    final public DMLValue get3() { return vals[3]; }

    final public boolean equals(Object val) {
	if (val instanceof DMLTuple) {
	    if (val instanceof Record) {
		return false;
	    } else if (val instanceof Tuple) {
		Tuple r = (Tuple) val;
		if (r.vals.length != this.vals.length)
		    return false;
		int length=vals.length;
		for(int i=0; i<length; i++) {
		    if (!vals[i].equals(r.vals[i])) {
			return false;
		    }
		}
		return true;
	    } else { // kann nur noch Tuple<i> sein
		return false;
	    }
	} else if (val instanceof DMLTransient) {
	    return val.equals(this);
	} else {
	    return false;
	}
    }

    final public java.lang.String toString() {
	java.lang.String s="(";
	int i;
	for (i=0; i<vals.length;i++) {
	    if (i>0) s+=", ";
	    s+=vals[i];
	}
	return s+")/"+getArity();
    }

    final public java.lang.String toString(int level) throws java.rmi.RemoteException {
	if (level<1) {
	    return "...";
	} else {
	    java.lang.String s="(";
	    int i;
	    for (i=0; i<vals.length;i++) {
		if (i>0) s+=", ";
		s+=vals[i].toString(level-1);
	    }
	    return s+")/"+getArity();
	}
    }

    /** gibt den i-ten Eintrag des Tuples oder Records*/
    final public DMLValue get(int i){
	return vals[i];
    }

    final public DMLValue get(java.lang.String i) {
	try {
	    _RAISE(runtimeError,new STRING ("no such label in tuple: "+i));
	} catch (RemoteException r) {
	    System.err.println(r);
	    r.printStackTrace();
	    return null;
	}
    }

    /** gibt die Stelligkeit des Tuples oder Records an */
    final public int getArity() {
	return vals.length;
    }

    final public DMLValue[] getVals() {
	return vals;
    }
    _apply_fails ;
}
