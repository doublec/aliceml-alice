//
// Author:
//   Leif Kornstaedt <kornstae@ps.uni-sb.de>
//
// Copyright:
//   Leif Kornstaedt, 2000-2002
//
// Last Change:
//   $Date$ by $Author$
//   $Revision$
//

#include "generic/Transients.hh"
#include "generic/Closure.hh"
#include "generic/ByneedInterpreter.hh"
#include "generic/PushCallInterpreter.hh"
#include "generic/Scheduler.hh"
#include "generic/SignalHandler.hh"
#include "alice/primitives/Authoring.hh"

DEFINE1(Future_alarmQuote) {
  DECLARE_INT(nanos, x0);
  Future *future = Future::New();
  // Register expects milliseconds
  SignalHandler::Register(SIGALRM, future->ToWord(), nanos / 1000);
  RETURN(future->ToWord());
} END

DEFINE1(Future_await) {
  if (Store::WordToTransient(x0) != INVALID_POINTER) {
    REQUEST(x0);
  } else {
    RETURN(x0);
  }
} END

DEFINE1(Future_byneed) {
  RETURN(Byneed::New(x0)->ToWord());
} END

DEFINE1(Future_concur) {
  Future *future = Future::New();
  Thread *thread = Scheduler::NewThread(0, Store::IntToWord(0));
  ByneedInterpreter::PushFrame(thread, future);
  PushCallInterpreter::PushFrame(thread, x0);
  RETURN(future->ToWord());
} END

DEFINE1(Future_isFailed) {
  Transient *transient = Store::WordToTransient(x0);
  RETURN_BOOL(transient != INVALID_POINTER &&
	      transient->GetLabel() == CANCELLED_LABEL);
} END

DEFINE1(Future_isFuture) {
  Transient *transient = Store::WordToTransient(x0);
  RETURN_BOOL(transient != INVALID_POINTER &&
	      transient->GetLabel() == FUTURE_LABEL);
} END

void PrimitiveTable::RegisterFuture() {
  PrimitiveTable::Future_Future =
    UniqueConstructor::New(String::New("Future.Future"))->ToWord();
  Register("Future.Future", PrimitiveTable::Future_Future);
  Register("Future.alarm'", Future_alarmQuote, 1);
  Register("Future.await", Future_await, 1);
  Register("Future.byneed", Future_byneed, 1);
  Register("Future.concur", Future_concur, 1);
  Register("Future.isFailed", Future_isFailed, 1);
  Register("Future.isFuture", Future_isFuture, 1);
}
