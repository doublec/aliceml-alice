//
// Authors:
//   Thorsten Brunklaus <brunklaus@ps.uni-sb.de>
//
// Copyright:
//   Thorsten Brunklaus, 2002
//
// Last Change:
//   $Date$ by $Author$
//   $Revision$
//

#ifndef __GENERIC__PICKLER_HH__
#define __GENERIC__PICKLER_HH__

#if defined(INTERFACE)
#pragma interface "generic/Pickler.hh"
#endif

#include "generic/Interpreter.hh"

class Pickler {
public:
  // Exceptions
  static word Sited;

  // Pickler Static Constructor
  static void Init();
  static void InitExceptions();

  // Pickler Functions
  static Interpreter::Result Pack(word x, TaskStack *taskStack);
  static Interpreter::Result Save(Chunk *filename, word x,
				  TaskStack *taskStack);
};

#endif
