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
#pragma implementation "java/ClassLoader.hh"
#endif

#include <cstdio>
#include "adt/HashTable.hh"
#include "generic/String.hh"
#include "generic/Tuple.hh"
#include "generic/RootSet.hh"
#include "generic/Transients.hh"
#include "generic/ConcreteCode.hh"
#include "generic/Backtrace.hh"
#include "generic/Interpreter.hh"
#include "java/StackFrame.hh"
#include "java/ThrowWorker.hh"
#include "java/ClassLoader.hh"
#include "java/ClassFile.hh"

//--** check loading constraints

class ClassTable: private HashTable {
private:
  static const u_int initialTableSize = 19; //--** to be determined
public:
  using Block::ToWord;

  static ClassTable *ClassTable::New() {
    return static_cast<ClassTable *>
      (HashTable::New(HashTable::BLOCK_KEY, initialTableSize));
  }
  static ClassTable *FromWordDirect(word x) {
    return static_cast<ClassTable *>(HashTable::FromWordDirect(x));
  }

  word Lookup(JavaString *name) {
    word wName = name->ToArray()->ToWord();
    if (IsMember(wName))
      return GetItem(wName);
    else
      return word(0);
  }
  void Insert(JavaString *name, word wClass) {
    word wName = name->ToArray()->ToWord();
    Assert(!IsMember(wName));
    InsertItem(wName, wClass);
  }
};

//
// PreloadWorker
//
class PreloadWorker: public Worker {
public:
  static PreloadWorker *self;
private:
  PreloadWorker() {}
public:
  static void Init() {
    self = new PreloadWorker();
  }

  static void PushFrame(Thread *thread);

  virtual Result Run();
  virtual const char *Identify();
  virtual void DumpFrame(word wFrame);
};

class PreloadFrame: private StackFrame {
protected:
  enum { HOLE_POS, SIZE };
public:
  using Block::ToWord;

  static PreloadFrame *New() {
    StackFrame *frame =
      StackFrame::New(PRELOAD_FRAME, PreloadWorker::self, SIZE);
    return static_cast<PreloadFrame *>(frame);
  }
  static PreloadFrame *FromWordDirect(word x) {
    StackFrame *frame = StackFrame::FromWordDirect(x);
    Assert(frame->GetLabel() == PRELOAD_FRAME);
    return static_cast<PreloadFrame *>(frame);
  }

  void SetHole(Hole *hole) {
    ReplaceArg(HOLE_POS, hole->ToWord());
  }
  Hole *GetHole() {
    return static_cast<Hole *>(Store::DirectWordToTransient(GetArg(HOLE_POS)));
  }
};

PreloadWorker *PreloadWorker::self;

static word wPreloadQueue;

void PreloadWorker::PushFrame(Thread *thread) {
  thread->PushFrame(PreloadFrame::New()->ToWord());
}

Worker::Result PreloadWorker::Run() {
  PreloadFrame *frame = PreloadFrame::FromWordDirect(Scheduler::GetFrame());
  if (Scheduler::nArgs == Scheduler::ONE_ARG) { 
    Class *theClass = Class::FromWord(Scheduler::currentArgs[0]);
    Assert(theClass != INVALID_POINTER);
    Hole *hole = frame->GetHole();
    hole->Fill(theClass->ToWord());
  }
  Queue *preloadQueue = Queue::FromWordDirect(wPreloadQueue);
  if (preloadQueue->IsEmpty()) {
    Scheduler::PopFrame();
    Scheduler::nArgs = 0;
    return CONTINUE;
  }
  Tuple *tuple = Tuple::FromWordDirect(preloadQueue->Dequeue());
  String *string = String::FromWordDirect(tuple->Sel(0));
  JavaString *name =
    JavaString::New(reinterpret_cast<const char *>(string->GetValue()),
		    string->GetSize());
  Hole *hole =
    static_cast<Hole *>(Store::DirectWordToTransient(tuple->Sel(1)));
  frame->SetHole(hole);
  ClassLoader *classLoader = ClassLoader::GetBootstrapClassLoader();
  word wClass = classLoader->ResolveClass(name);
  Scheduler::nArgs = Scheduler::ONE_ARG;
  Scheduler::currentArgs[0] = wClass;
  if (Class::FromWord(wClass) == INVALID_POINTER) {
    Scheduler::currentData = wClass;
    return REQUEST;
  } else {
    return CONTINUE;
  }
}

const char *PreloadWorker::Identify() {
  return "PreloadWorker";
}

void PreloadWorker::DumpFrame(word) {
  std::fprintf(stderr, "Preload classes\n");
}

//
// BuildClassWorker
//
class BuildClassWorker: public Worker {
public:
  static BuildClassWorker *self;
private:
  BuildClassWorker() {}
public:
  static void Init() {
    self = new BuildClassWorker();
  }

  static void PushFrame(ClassInfo *classInfo);

  virtual Result Run();
  virtual const char *Identify();
  virtual void DumpFrame(word wFrame);
};

class BuildClassFrame: private StackFrame {
protected:
  enum { CLASS_INFO_POS, SIZE };
public:
  using Block::ToWord;

  static BuildClassFrame *New(ClassInfo *classInfo) {
    StackFrame *frame =
      StackFrame::New(BUILD_CLASS_FRAME, BuildClassWorker::self, SIZE);
    frame->InitArg(CLASS_INFO_POS, classInfo->ToWord());
    return static_cast<BuildClassFrame *>(frame);
  }
  static BuildClassFrame *FromWordDirect(word x) {
    StackFrame *frame = StackFrame::FromWordDirect(x);
    Assert(frame->GetLabel() == BUILD_CLASS_FRAME);
    return static_cast<BuildClassFrame *>(frame);
  }

  ClassInfo *GetClassInfo() {
    return ClassInfo::FromWordDirect(GetArg(CLASS_INFO_POS));
  }
};

BuildClassWorker *BuildClassWorker::self;

void BuildClassWorker::PushFrame(ClassInfo *classInfo) {
  Scheduler::PushFrame(BuildClassFrame::New(classInfo)->ToWord());
}

Worker::Result BuildClassWorker::Run() {
  BuildClassFrame *frame =
    BuildClassFrame::FromWordDirect(Scheduler::GetFrame());
  ClassInfo *classInfo = frame->GetClassInfo();
  word wSuper = classInfo->GetSuper();
  if (Store::WordToTransient(wSuper) != INVALID_POINTER) {
    //--** detect ClassCircularityError
    Scheduler::currentData = wSuper;
    return REQUEST;
  }
  //--** if the class or interface named as the direct superclass of C is
  //--** in fact an interface, loading throws an IncompatibleClassChangeError
  Table *interfaces = classInfo->GetInterfaces();
  for (u_int i = interfaces->GetCount(); i--; ) {
    //--** detect ClassCircularityError
    word wInterface = interfaces->Get(i);
    if (Store::WordToTransient(wInterface) != INVALID_POINTER) {
      Scheduler::currentData = wInterface;
      return REQUEST;
    }
    //--** if any of the classes or interfaces named as direct
    //--** superinterfaces of C is not in fact an interface, loading
    //--** throws an IncompatibleClassChangeError
  }
  Scheduler::PopFrame();
  if (!classInfo->Verify()) {
    ThrowWorker::PushFrame(ThrowWorker::VerifyError, classInfo->GetName());
    Scheduler::nArgs = 0;
    return CONTINUE;
  }
  Scheduler::nArgs = Scheduler::ONE_ARG;
  Scheduler::currentArgs[0] = classInfo->Prepare()->ToWord();
  return CONTINUE;
}

const char *BuildClassWorker::Identify() {
  return "BuildClassWorker";
}

void BuildClassWorker::DumpFrame(word wFrame) {
  BuildClassFrame *frame = BuildClassFrame::FromWordDirect(wFrame);
  std::fprintf(stderr, "Build class %s\n",
	       frame->GetClassInfo()->GetName()->ExportC());
}

//
// ResolveInterpreter
//
class ResolveInterpreter: public Interpreter {
public:
  enum type {
    RESOLVE_CLASS, RESOLVE_FIELD, RESOLVE_METHOD, RESOLVE_INTERFACE_METHOD
  };
  static ResolveInterpreter *self;
private:
  ResolveInterpreter() {}
public:
  static void Init() {
    self = new ResolveInterpreter();
  }

  virtual Result Run();
  virtual const char *Identify();
  virtual void DumpFrame(word wFrame);
  virtual void PushCall(Closure *closure);
};

class ResolveFrame: private StackFrame {
protected:
  enum {
    CLASS_LOADER_POS, RESOLVE_TYPE_POS, CLASS_POS, NAME_POS, DESCRIPTOR_POS,
    SIZE
  };
public:
  using Block::ToWord;

  static ResolveFrame *New(ClassLoader *classLoader, JavaString *name) {
    StackFrame *frame =
      StackFrame::New(RESOLVE_FRAME, ResolveInterpreter::self, SIZE);
    frame->InitArg(CLASS_LOADER_POS, classLoader->ToWord());
    frame->InitArg(RESOLVE_TYPE_POS, ResolveInterpreter::RESOLVE_CLASS);
    frame->InitArg(NAME_POS, name->ToWord());
    return static_cast<ResolveFrame *>(frame);
  }
  static ResolveFrame *New(ClassLoader *classLoader,
			   ResolveInterpreter::type resolveType,
			   word theClass, JavaString *name,
			   JavaString *descriptor) {
    StackFrame *frame =
      StackFrame::New(RESOLVE_FRAME, ResolveInterpreter::self, SIZE);
    frame->InitArg(CLASS_LOADER_POS, classLoader->ToWord());
    frame->InitArg(RESOLVE_TYPE_POS, resolveType);
    frame->InitArg(CLASS_POS, theClass);
    frame->InitArg(NAME_POS, name->ToWord());
    frame->InitArg(DESCRIPTOR_POS, descriptor->ToWord());
    return static_cast<ResolveFrame *>(frame);
  }
  static ResolveFrame *FromWordDirect(word x) {
    StackFrame *frame = StackFrame::FromWordDirect(x);
    Assert(frame->GetLabel() == RESOLVE_FRAME);
    return static_cast<ResolveFrame *>(frame);
  }

  ClassLoader *GetClassLoader() {
    return ClassLoader::FromWordDirect(GetArg(CLASS_LOADER_POS));
  }
  ResolveInterpreter::type GetResolveType() {
    return static_cast<ResolveInterpreter::type>
      (Store::DirectWordToInt(GetArg(RESOLVE_TYPE_POS)));
  }
  word GetClass() {
    Assert(GetResolveType() != ResolveInterpreter::RESOLVE_CLASS);
    return GetArg(CLASS_POS);
  }
  void SetClass(Class *theClass) {
    Assert(GetResolveType() != ResolveInterpreter::RESOLVE_CLASS);
    ReplaceArg(CLASS_POS, theClass->ToWord());
  }
  JavaString *GetName() {
    return JavaString::FromWordDirect(GetArg(NAME_POS));
  }
  JavaString *GetDescriptor() {
    Assert(GetResolveType() != ResolveInterpreter::RESOLVE_CLASS);
    return JavaString::FromWordDirect(GetArg(DESCRIPTOR_POS));
  }
};

ResolveInterpreter *ResolveInterpreter::self;

Worker::Result ResolveInterpreter::Run() {
  ResolveFrame *frame = ResolveFrame::FromWordDirect(Scheduler::GetFrame());
  switch (frame->GetResolveType()) {
  case RESOLVE_CLASS:
    {
      JavaString *name = frame->GetName();
      std::fprintf(stderr, "resolving class %s\n", name->ExportC());
      JavaString *filename = name->Concat(JavaString::New(".class"));
      ClassFile *classFile = ClassFile::NewFromFile(filename);
      if (classFile == INVALID_POINTER) {
	ThrowWorker::PushFrame(ThrowWorker::NoClassDefFoundError, name);
	Scheduler::nArgs = 0;
	return CONTINUE;
      }
      ClassInfo *classInfo = classFile->Parse(frame->GetClassLoader());
      if (classInfo == INVALID_POINTER) {
	ThrowWorker::PushFrame(ThrowWorker::ClassFormatError, name);
	Scheduler::nArgs = 0;
	return CONTINUE;
      }
      if (!classInfo->GetName()->Equals(name)) {
	ThrowWorker::PushFrame(ThrowWorker::NoClassDefFoundError, name);
	Scheduler::nArgs = 0;
	return CONTINUE;
      }
      Scheduler::PopFrame();
      BuildClassWorker::PushFrame(classInfo);
      return CONTINUE;
    }
  case RESOLVE_FIELD:
    {
      word wClass = frame->GetClass();
      Class *theClass = Class::FromWord(wClass);
      if (theClass == INVALID_POINTER) {
	Scheduler::currentData = wClass;
	return REQUEST;
      }
      JavaString *name = frame->GetName();
      JavaString *descriptor = frame->GetDescriptor();
      std::fprintf(stderr, "resolving field %s#%s:%s\n",
		   theClass->GetClassInfo()->GetName()->ExportC(),
		   name->ExportC(), descriptor->ExportC());
      //--** look for field definitions in implemented interfaces
      ClassInfo *classInfo = theClass->GetClassInfo();
      Table *fields = classInfo->GetFields();
      u_int sIndex = 0, iIndex = 0, nFields = fields->GetCount();
      word wSuper = classInfo->GetSuper();
      if (wSuper != null)
	iIndex = Class::FromWord(wSuper)->GetNumberOfInstanceFields();
      for (u_int i = 0; i < nFields; i++) {
	FieldInfo *fieldInfo = FieldInfo::FromWordDirect(fields->Get(i));
	if (fieldInfo->IsTheField(name, descriptor)) {
	  u_int nSlots = fieldInfo->GetNumberOfRequiredSlots();
	  Scheduler::PopFrame();
	  Scheduler::nArgs = Scheduler::ONE_ARG;
	  Scheduler::currentArgs[0] = fieldInfo->IsStatic()?
	    StaticFieldRef::New(theClass, sIndex, nSlots)->ToWord():
	    InstanceFieldRef::New(iIndex, nSlots)->ToWord();
	  return CONTINUE;
	} else {
	  if (fieldInfo->IsStatic())
	    sIndex++;
	  else
	    iIndex++;
	}
      }
      if (wSuper == null) {
	ThrowWorker::PushFrame(ThrowWorker::NoSuchFieldError, name);
	Scheduler::nArgs = 0;
	return CONTINUE;
      }
      frame->SetClass(Class::FromWord(wSuper));
      return CONTINUE;
    }
  case RESOLVE_METHOD:
    {
      word wClass = frame->GetClass();
      Class *theClass = Class::FromWord(wClass);
      if (theClass == INVALID_POINTER) {
	Scheduler::currentData = wClass;
	return REQUEST;
      }
      ClassInfo *classInfo = theClass->GetClassInfo();
      if (classInfo->IsInterface()) {
	ThrowWorker::PushFrame(ThrowWorker::IncompatibleClassChangeError,
			       classInfo->GetName());
	Scheduler::nArgs = 0;
	return CONTINUE;
      }
      JavaString *name = frame->GetName();
      JavaString *descriptor = frame->GetDescriptor();
      std::fprintf(stderr, "resolving method %s#%s%s\n",
		   theClass->GetClassInfo()->GetName()->ExportC(),
		   name->ExportC(), descriptor->ExportC());
      HashTable *methodHashTable = theClass->GetMethodHashTable();
      word wKey = Class::MakeMethodKey(name, descriptor);
      if (methodHashTable->IsMember(wKey)) {
	word wMethodRef = methodHashTable->GetItem(wKey);
	//--** is the method is abstract, but C is not abstract,
	//--** throw AbstractMethodError
	Scheduler::PopFrame();
	Scheduler::nArgs = Scheduler::ONE_ARG;
	Scheduler::currentArgs[0] = wMethodRef;
	return CONTINUE;
      }
      word wSuper = classInfo->GetSuper();
      if (wSuper == null) {
	//--** we must attempt to locate the method in the superinterfaces
	//--** of the original class
	ThrowWorker::PushFrame(ThrowWorker::NoSuchMethodError, name);
	Scheduler::nArgs = 0;
	return CONTINUE;
      }
      frame->SetClass(Class::FromWord(wSuper));
      return CONTINUE;
    }
  case RESOLVE_INTERFACE_METHOD:
    Error("interface methods not implemented yet"); //--**
  default:
    Error("invalid resolution type");
  }
}

void ResolveInterpreter::PushCall(Closure *closure) {
  ClassLoader *classLoader = ClassLoader::FromWordDirect(closure->Sub(0));
  ResolveInterpreter::type resolveType =
    static_cast<ResolveInterpreter::type>
    (Store::DirectWordToInt(closure->Sub(1)));
  if (resolveType == ResolveInterpreter::RESOLVE_CLASS) {
    JavaString *name = JavaString::FromWordDirect(closure->Sub(2));
    Scheduler::PushFrame(ResolveFrame::New(classLoader, name)->ToWord());
  } else {
    word theClass = closure->Sub(2);
    JavaString *name = JavaString::FromWordDirect(closure->Sub(3));
    JavaString *descriptor = JavaString::FromWordDirect(closure->Sub(4));
    Scheduler::PushFrame(ResolveFrame::New(classLoader, resolveType, theClass,
					   name, descriptor)->ToWord());
  }
}

const char *ResolveInterpreter::Identify() {
  return "ResolveInterpreter";
}

void ResolveInterpreter::DumpFrame(word wFrame) {
  ResolveFrame *frame = ResolveFrame::FromWordDirect(wFrame);
  std::fprintf(stderr, "Resolve class %s\n", frame->GetName()->ExportC());
}

//
// ClassLoader Implementation
//
word ClassLoader::wBootstrapClassLoader;

static const u_int PRELOAD_QUEUE_INITIAL_SIZE = 2; //--** to be determined

void ClassLoader::Init() {
  wBootstrapClassLoader = ClassLoader::New()->ToWord();
  RootSet::Add(wBootstrapClassLoader);
  wPreloadQueue = Queue::New(PRELOAD_QUEUE_INITIAL_SIZE)->ToWord();
  RootSet::Add(wPreloadQueue);
  PreloadWorker::Init();
  BuildClassWorker::Init();
  ResolveInterpreter::Init();
}

ClassLoader *ClassLoader::New() {
  Block *b = Store::AllocBlock(JavaLabel::ClassLoader, SIZE);
  b->InitArg(CLASS_TABLE_POS, ClassTable::New()->ToWord());
  return static_cast<ClassLoader *>(b);
}

ClassTable *ClassLoader::GetClassTable() {
  return ClassTable::FromWordDirect(GetArg(CLASS_TABLE_POS));
}

word ClassLoader::PreloadClass(const char *name) {
  Hole *hole = Hole::New();
  Tuple *tuple = Tuple::New(2);
  tuple->Init(0, String::New(name)->ToWord());
  tuple->Init(1, hole->ToWord());
  Queue::FromWordDirect(wPreloadQueue)->Enqueue(tuple->ToWord());
  return hole->ToWord();
}

void ClassLoader::PushPreloadFrame(Thread *thread) {
  PreloadWorker::PushFrame(thread);
}

word ClassLoader::ResolveClass(JavaString *name) {
  ClassTable *classTable = GetClassTable();
  word wClass = classTable->Lookup(name);
  if (wClass == (word) 0) {
    ConcreteCode *concreteCode =
      ConcreteCode::New(ResolveInterpreter::self, 0);
    Closure *closure = Closure::New(concreteCode->ToWord(), 3);
    closure->Init(0, ToWord());
    closure->Init(1, Store::IntToWord(ResolveInterpreter::RESOLVE_CLASS));
    closure->Init(2, name->ToWord());
    wClass = Byneed::New(closure->ToWord())->ToWord();
    classTable->Insert(name, wClass);
  }
  return wClass;
}

word ClassLoader::ResolveType(JavaString *name) {
  //--** cache results
  u_int n = name->GetLength();
  u_int index = 0;
  u_int dimensions = 0;
  while (dimensions < n && name->CharAt(dimensions) == '[') dimensions++;
  index += dimensions;
  n -= dimensions;
  Assert(n > 0);
  word wClass;
  switch (n--, name->CharAt(index++)) {
  case 'B':
    wClass = PrimitiveType::New(PrimitiveType::Byte)->ToWord();
    break;
  case 'C':
    wClass = PrimitiveType::New(PrimitiveType::Char)->ToWord();
    break;
  case 'D':
    wClass = PrimitiveType::New(PrimitiveType::Double)->ToWord();
    break;
  case 'F':
    wClass = PrimitiveType::New(PrimitiveType::Float)->ToWord();
    break;
  case 'I':
    wClass = PrimitiveType::New(PrimitiveType::Int)->ToWord();
    break;
  case 'J':
    wClass = PrimitiveType::New(PrimitiveType::Long)->ToWord();
    break;
  case 'S':
    wClass = PrimitiveType::New(PrimitiveType::Short)->ToWord();
    break;
  case 'Z':
    wClass = PrimitiveType::New(PrimitiveType::Boolean)->ToWord();
    break;
  case 'L':
    {
      u_int endIndex = index;
      while (n--, name->CharAt(endIndex++) != ';');
      wClass = ResolveClass(name->Substring(index, endIndex - 1));
      break;
    }
  default:
    Error("invalid descriptor"); //--** return failed future?
  }
  while (dimensions--) wClass = ArrayType::New(wClass)->ToWord();
  Assert(n == 0);
  return wClass;
}

word ClassLoader::ResolveFieldRef(word theClass, JavaString *name,
				  JavaString *descriptor) {
  ConcreteCode *concreteCode = ConcreteCode::New(ResolveInterpreter::self, 0);
  Closure *closure = Closure::New(concreteCode->ToWord(), 5);
  closure->Init(0, ToWord());
  closure->Init(1, Store::IntToWord(ResolveInterpreter::RESOLVE_FIELD));
  closure->Init(2, theClass);
  closure->Init(3, name->ToWord());
  closure->Init(4, descriptor->ToWord());
  return Byneed::New(closure->ToWord())->ToWord();
}

word ClassLoader::ResolveMethodRef(word theClass, JavaString *name,
				   JavaString *descriptor) {
  ConcreteCode *concreteCode = ConcreteCode::New(ResolveInterpreter::self, 0);
  Closure *closure = Closure::New(concreteCode->ToWord(), 5);
  closure->Init(0, ToWord());
  closure->Init(1, Store::IntToWord(ResolveInterpreter::RESOLVE_METHOD));
  closure->Init(2, theClass);
  closure->Init(3, name->ToWord());
  closure->Init(4, descriptor->ToWord());
  return Byneed::New(closure->ToWord())->ToWord();
}

word ClassLoader::ResolveInterfaceMethodRef(word theClass, JavaString *name,
					    JavaString *descriptor) {
  ConcreteCode *concreteCode = ConcreteCode::New(ResolveInterpreter::self, 0);
  Closure *closure = Closure::New(concreteCode->ToWord(), 5);
  closure->Init(0, ToWord());
  u_int resolveType = ResolveInterpreter::RESOLVE_INTERFACE_METHOD;
  closure->Init(1, Store::IntToWord(resolveType));
  closure->Init(2, theClass);
  closure->Init(3, name->ToWord());
  closure->Init(4, descriptor->ToWord());
  return Byneed::New(closure->ToWord())->ToWord();
}
