//
// Authors:
//   Thorsten Brunklaus <brunklaus@ps.uni-sb.de>
//   Leif Kornstaedt <kornstae@ps.uni-sb.de>
//
// Copyright:
//   Thorsten Brunklaus, 2002
//   Leif Kornstaedt, 2002
//
// Last Change:
//   $Date$ by $Author$
//   $Revision$
//

#if defined(INTERFACE)
#pragma implementation "alice/Data.hh"
#endif

#include "adt/HashTable.hh"
#include "generic/RootSet.hh"
#include "generic/Tuple.hh"
#include "generic/Transform.hh"
#include "generic/ConcreteRepresentationHandler.hh"
#include "alice/Data.hh"
#include "alice/Guid.hh"
#include "alice/AliceLanguageLayer.hh"

static const u_int initialTableSize = 16; // to be checked

//
// ConstructorHandler
//

class ConstructorHandler: public ConcreteRepresentationHandler {
public:
  virtual Block *GetAbstractRepresentation(Block *blockWithHandler);
};

Block *ConstructorHandler::GetAbstractRepresentation(Block *blockWithHandler) {
  Constructor *constructor = static_cast<Constructor *>(blockWithHandler);
  return static_cast<Block *>(constructor->GetTransform());
}

//
// Constructor
//

static word constructorTable;

ConcreteRepresentationHandler *Constructor::handler;

void Constructor::Init() {
  handler = new ConstructorHandler();
  constructorTable =
    HashTable::New(HashTable::BLOCK_KEY, initialTableSize)->ToWord();
  RootSet::Add(constructorTable);
}

static Transform *MakeConstructorTransform(String *name, word key) {
  Tuple *tuple = Tuple::New(2);
  tuple->Init(0, name->ToWord());
  tuple->Init(1, key);
  Chunk *transformName = static_cast<Chunk *>
    (String::FromWordDirect(AliceLanguageLayer::TransformNames::constructor));
  return Transform::New(transformName, tuple->ToWord());
}

Constructor *Constructor::New(String *name, Block *guid) {
  Assert(guid != INVALID_POINTER);
  HashTable *hashTable = HashTable::FromWordDirect(constructorTable);
  word key = guid->ToWord();
  if (hashTable->IsMember(key)) {
    return Constructor::FromWordDirect(hashTable->GetItem(key));
  } else {
    ConcreteRepresentation *b = ConcreteRepresentation::New(handler, SIZE);
    b->Init(NAME_POS, name->ToWord());
    b->Init(TRANSFORM_POS, MakeConstructorTransform(name, key)->ToWord());
    hashTable->InsertItem(key, b->ToWord());
    return static_cast<Constructor *>(b);
  }
}

Transform *Constructor::GetTransform() {
  word transformWord = Get(TRANSFORM_POS);
  if (transformWord == Store::IntToWord(0)) {
    Transform *transform =
      MakeConstructorTransform(GetName(), Guid::New()->ToWord());
    Replace(TRANSFORM_POS, transform->ToWord());
    return transform;
  } else {
    return Transform::FromWordDirect(transformWord);
  }
}

//
// Record
//

void Record::Init(const char *s, word value) {
  UniqueString *label = UniqueString::New(String::New(s));
  u_int n = Store::DirectWordToInt(GetArg(WIDTH_POS));
  Assert(n != 0);
  u_int index = label->Hash() % n;
  u_int i = index;
  while (true) {
    if (Store::WordToInt(GetArg(BASE_SIZE + i * 2)) != INVALID_INT) {
      InitArg(BASE_SIZE + i * 2, label->ToWord());
      InitArg(BASE_SIZE + i * 2 + 1, value);
      return;
    }
    i = (i + 1) % n;
    Assert(i != index);
  }
}
