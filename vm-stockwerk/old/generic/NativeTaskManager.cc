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

#if defined(INTERFACE)
#pragma implementation "builtin/Primitive.hh"
#endif

#include <cstdio>
#include "scheduler/RootSet.hh"
#include "scheduler/Closure.hh"
#include "scheduler/TaskStack.hh"
#include "builtins/Primitive.hh"
#include "builtins/GlobalPrimitives.hh"

//
// PrimitiveInterpreter: An interpreter that runs primitives
//

class PrimitiveInterpreter: public Interpreter {
private:
  Primitive::function function;
  int arity;
  u_int frameSize;
public:
  PrimitiveInterpreter(Primitive::function f, int n, u_int m):
    function(f), arity(n == 1? -1: n), frameSize(m + 1) {}

  virtual void PushCall(TaskStack *taskStack, Closure *closure);
  virtual void PopFrame(TaskStack *taskStack);
  virtual Result Run(TaskStack *taskStack, int nargs);
};

void PrimitiveInterpreter::PushCall(TaskStack *taskStack, Closure *closure) {
  Assert(closure->GetConcreteCode()->GetInterpreter() == this);
  taskStack->PushFrame(1);
  taskStack->PutUnmanagedPointer(0, this);
}

void PrimitiveInterpreter::PopFrame(TaskStack *taskStack) {
  taskStack->PopFrame(frameSize);
}

Interpreter::Result
PrimitiveInterpreter::Run(TaskStack *taskStack, int nargs) {
  if (arity != nargs) {
    if (nargs == -1) {
      word suspendWord = taskStack->GetWord(0);
      if (arity == 0) { // await unit
	if (Store::WordToInt(suspendWord) == INVALID_INT) {
	  taskStack->PopFrame(1);
	  taskStack->
	    PushCall(Closure::FromWordDirect(GlobalPrimitives::Future_await));
	  taskStack->PushFrame(1);
	  taskStack->PutWord(0, suspendWord);
	  return Result(Result::CONTINUE, 1);
	}
	Assert(Store::WordToInt(suspendWord) == 0); // unit
      } else { // deconstruct
	Tuple *tuple = Tuple::FromWord(suspendWord);
	if (tuple == INVALID_POINTER) {
	  taskStack->PopFrame(1);
	  taskStack->
	    PushCall(Closure::FromWordDirect(GlobalPrimitives::Future_await));
	  taskStack->PushFrame(1);
	  taskStack->PutWord(0, suspendWord);
	  return Result(Result::CONTINUE, 1);
	}
	taskStack->PushFrame(arity - 1);
	Assert(tuple->GetWidth() == arity);
	for (u_int i = arity; i--; )
	  taskStack->PutWord(i, tuple->Sel(i));
      }
    } else if (nargs == 0) {
      taskStack->PushFrame(1);
      taskStack->PutWord(0, 0); // unit
    } else { // construct
      Tuple *tuple = Tuple::New(nargs);
      for (u_int i = nargs; i--; )
	tuple->Init(i, taskStack->GetWord(i));
      taskStack->PopFrame(nargs - 1);
      taskStack->PutWord(0, tuple->ToWord());
    }
  }
  return function(taskStack);
}

//
// Implementation of `Primitive' methods
//

word Primitive::table;

void Primitive::Init() {
  table = HashTable::New(HashTable::BLOCK_KEY, 19)->ToWord();
  RootSet::Add(table);
  RegisterInternal();
  RegisterUnqualified();
  RegisterArray();
  RegisterChar();
  RegisterFuture();
  RegisterGeneral();
  RegisterGlobalStamp();
  RegisterHole();
  RegisterInt();
  RegisterList();
  RegisterMath();
  RegisterOption();
  RegisterReal();
  RegisterString();
  RegisterThread();
  RegisterUnsafe();
  RegisterVector();
  RegisterWord();
}

void Primitive::Register(const char *name, word value) {
  HashTable::FromWordDirect(table)->
    InsertItem(String::New(name)->ToWord(), value);
}

void Primitive::Register(const char *name, function value, u_int arity,
			 u_int frameSize) {
  word abstractCode = Store::IntToWord(0); //--** this has to be revisited
  ConcreteCode *concreteCode =
    ConcreteCode::New(abstractCode,
		      new PrimitiveInterpreter(value, arity, frameSize), 0);
  Closure *closure = Closure::New(concreteCode, 0);
  Register(name, closure->ToWord());
}

void Primitive::Register(const char *name, function value, u_int arity) {
  Register(name, value, arity, 0);
}

void Primitive::RegisterUniqueConstructor(const char *name) {
  Register(name, UniqueConstructor::New(String::New(name))->ToWord());
}

word Primitive::Lookup(String *name) {
  word key = name->ToWord();
  HashTable *t = HashTable::FromWordDirect(table);
  if (!t->IsMember(key)) {
    char message[80 + name->GetSize()];
    sprintf(message, "Primitive::Lookup: unknown primitive `%.*s'",
	    static_cast<int>(name->GetSize()), name->GetValue());
    Error(message);
  }
  return t->GetItem(key);
}
