//
// Author:
//   Leif Kornstaedt <kornstae@ps.uni-sb.de>
//
// Copyright:
//   Leif Kornstaedt, 2002
//
// Last Change:
//   $Date$ by $Author$
//   $Revision$
//

#if defined(INTERFACE)
#pragma implementation "java/ClassInfo.hh"
#endif

#include "java/ClassInfo.hh"

u_int FieldInfo::GetNumberOfRequiredSlots() {
  JavaString *descriptor = GetDescriptor();
  switch (descriptor->CharAt(0)) {
  case 'B': case 'C': case 'F':
  case 'I': case 'S': case 'Z':
  case 'L': case '[':
    return 1;
  case 'J': case 'D':
    return 2;
  default:
    Error("invalid field descriptor");
  }
}

u_int MethodInfo::GetNumberOfArguments() {
  JavaString *descriptor = GetDescriptor();
  Assert(descriptor->CharAt(0) == '(');
  u_int index = 1;
  u_int nArgs = 0;
  while (descriptor->CharAt(index) != ')') {
    while (descriptor->CharAt(index) == '[') index++;
    switch (descriptor->CharAt(index)) {
    case 'B': case 'C': case 'F':
    case 'I': case 'S': case 'Z':
      index++;
      break;
    case 'J': case 'D':
      index++;
      nArgs++;
      break;
    case 'L':
      while (descriptor->CharAt(index++) != ';');
      break;
    default:
      Error("invalid method descriptor");
    }
    nArgs++;
  }
  return nArgs;
}

bool ClassInfo::Verify() {
  return true; //--** implement verifier
}
