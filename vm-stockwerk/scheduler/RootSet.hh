//
// Author:
//   Leif Kornstaedt <kornstae@ps.uni-sb.de>
//
// Copyright:
//   Leif Kornstaedt, 2000
//
// Last Change:
//   $Date$ by $Author$
//   $Revision$
//

#ifndef __SCHEDULER__ROOT_SET_HH__
#define __SCHEDULER__ROOT_SET_HH__

#if defined(INTERFACE)
#pragma interface "scheduler/RootSet.hh"
#endif

#include "store/Store.hh"

class RootSet {
public:
  static void Init();
  static void Add(word &root);
  static void Remove(word &root);
  static void DoGarbageCollection();
};

#endif __SCHEDULER__ROOT_SET_HH__
