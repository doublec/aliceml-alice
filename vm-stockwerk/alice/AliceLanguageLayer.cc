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
#pragma implementation "alice/AliceLanguageLayer.hh"
#endif

#include "generic/RootSet.hh"
#include "generic/Transients.hh"
#include "generic/Unpickler.hh"
#include "alice/AliceLanguageLayer.hh"
#include "alice/PrimitiveTable.hh"
#include "alice/Guid.hh"
#include "alice/LazySelInterpreter.hh"
#include "alice/AbstractCodeInterpreter.hh"
#include "alice/AliceConcreteCode.hh"

word AliceLanguageLayer::functionTransformName;
word AliceLanguageLayer::constructorTransformName;

static word AliceFunctionHandler(word x) {
  return AliceConcreteCode::New(TagVal::FromWordDirect(x))->ToWord();
}

static word AliceConstructorHandler(word x) {
  Tuple *tuple = Tuple::FromWordDirect(x);
  tuple->AssertWidth(2);
  Constructor *constructor =
    Constructor::New(tuple->Sel(0), Store::WordToBlock(tuple->Sel(1)));
  return constructor->ToWord();
}

void AliceLanguageLayer::Init() {
  String *aliceFunction = String::New("Alice.function");
  functionTransformName = aliceFunction->ToWord();
  RootSet::Add(functionTransformName);
  Unpickler::RegisterHandler(static_cast<Chunk *>(aliceFunction),
			     AliceFunctionHandler);

  String *aliceConstructor = String::New("Alice.constructor");
  constructorTransformName = aliceConstructor->ToWord();
  RootSet::Add(constructorTransformName);
  Unpickler::RegisterHandler(static_cast<Chunk *>(aliceConstructor),
			     AliceConstructorHandler);

  Constructor::Init();
  Guid::Init();
  LazySelInterpreter::Init();
  AbstractCodeInterpreter::Init();

  Hole::InitExceptions(); //--** should not be here
  PrimitiveTable::Init();
}
