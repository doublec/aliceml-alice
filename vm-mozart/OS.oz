%%%
%%% Author:
%%%   Leif Kornstaedt <kornstae@ps.uni-sb.de>
%%%
%%% Copyright:
%%%   Leif Kornstaedt, 2000
%%%
%%% Last change:
%%%   $Date$ by $Author$
%%%   $Revision$
%%%

functor
import
   BootValue(byNeedFail: ByNeedFail) at 'x-oz://boot/Value'
   OS(system getEnv)
   Application(exit)
export
   'OS$': OS_Module
define
   OS_Module =
   'OS'('Process$':
	   'Process'('$status': {ByNeedFail rttNotImplemented}
		     'success': 0
		     'failure': 1
		     'system': OS.system
		     'exit':
			proc {$ N _}
			   {Application.exit N}
			end
		     'getEnv':
			fun {$ S}
			   case {OS.getEnv S} of false then 'NONE'
			   elseof S2 then 'SOME'({ByteString.make S2})
			   end
			end))
end
