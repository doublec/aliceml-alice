package de.uni_sb.ps.DML.DMLRuntime;

public class DMLByNeedFuture extends DMLFuture {
    // von Future: DMLValue ref = null;
    // ref kann hier nur DMLFunction : unit -> 'a  sein.
    // diese Bedingung wird nicht gepr�ft

    private DMLValue closure = null;
    private DMLLVar ref = null;

    public DMLByNeedFuture(DMLValue v) {
	closure=v;
	ref = new DMLLVar();
    }

    synchronized public DMLValue request() {
	if (closure==null)
	    return ref.request();
	else {
	    DMLValue temp = closure;
	    closure = null;
	    ref.bind(temp.apply(DMLConstants.dmlunit));
	    return ref.request();
	}
    }

    public String toString() {
	DMLValue val=this.getValue();
	if (val instanceof DMLLVar)
	    return "<unresolved>: byneed-future";
	else
	    return val.toString();
    }
}
