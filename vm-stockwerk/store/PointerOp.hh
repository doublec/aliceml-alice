//
// Author:
//   Thorsten Brunklaus <brunklaus@ps.uni-sb.de>
//
// Copyright:
//   Thorsten Brunklaus, 2000
//
// Last Change:
//   $Date$ by $Author$
//   $Revision$
//
#ifndef __STORE__POINTEROP_HH__
#define __STORE__POINTEROP_HH__

#if defined(INTERFACE)
#pragma interface "store/PointerOp.hh"
#endif

class PointerOp {
public:
  // Core Tag Operations
  static word EncodeTag(Block *p, u_int tag) {
    return (word) ((u_int) p | tag);
  }
  static u_int DecodeTag(word p) {
    return ((u_int) p & (u_int) TAGMASK);
  }
  static Block *RemoveTag(word p) {
    return (Block *) ((u_int) p & ~((u_int) TAGMASK));
  }
  // Block<->Word Conversion
  static word EncodeBlock(Block *p) {
    AssertStore(((u_int) p & (u_int) TAGMASK) == (u_int) EMPTYTAG);
    return (word) ((u_int) p | (u_int) BLKTAG);
  }
  static Block *DecodeBlock(word p) {
    return (Block *) ((((u_int) p & (u_int) TAGMASK) == (u_int) BLKTAG) ?
		      ((char *) p - (u_int) BLKTAG) : INVALID_POINTER);
  }
  static Chunk *DecodeChunk(word p) {
    if (((u_int) p & (u_int) TAGMASK) == (u_int) BLKTAG) {
      Block *bp = (Block *) ((char *) p - (u_int) BLKTAG);
      return (Chunk *) ((HeaderOp::DecodeLabel(bp) == CHUNK_LABEL) ? bp : INVALID_POINTER);
    }
    return (Chunk *) INVALID_POINTER;
  }
  // Transient<->Word Conversion
  static word EncodeTransient(Transient *p) {
    AssertStore(((u_int) p & (u_int) TAGMASK) == (u_int) EMPTYTAG);
    return (word) ((u_int) p | (u_int) TRTAG);
  }
  static Transient *DecodeTransient(word p) {
    return (Transient *) ((((u_int) p & (u_int) TAGMASK) == (u_int) TRTAG) ?
			  ((char *) p - (u_int) TRTAG) : INVALID_POINTER);
  }
  // int Test
  static int IsInt(word v) {
    return ((u_int) v & (u_int) INTMASK);
  }
  // int<->Word Conversion
  static word EncodeInt(int v) {
    AssertStore(v >= MIN_VALID_INT);
    AssertStore(v <= MAX_VALID_INT);
    return (word) ((((u_int) v) << 1) | (u_int) INTTAG);
  }
  static int DecodeInt(word v) {
    // some things need to be done
    if ((((u_int) v) & INTMASK) != INTTAG) {
      return (int) INVALID_INT;
    }
    else {
      return (int) (((u_int) v & (1 << (STORE_WORD_WIDTH - 1))) ?
		    ((1 << (STORE_WORD_WIDTH - 1)) | ((u_int) v >> 1)) : ((u_int) v >> 1));
    }
  }
  static word EncodeUnmanagedPointer(void *v) {
    AssertStore(((u_int) v & (1 << (STORE_WORD_WIDTH - 1))) == 0);
    return (word) (((u_int) v << 1) | (u_int) INTTAG); 
  }
  static void *DecodeUnmanagedPointer(word v) {
    AssertStore((u_int) v & INTMASK);
    return (void *) ((u_int) v >> 1);
  }
  static void EncodeHandler(Block *p, Handler *h) {
    AssertStore(p->GetLabel() == HANDLERBLOCK_LABEL);
    ((word *) p)[0] = PointerOp::EncodeUnmanagedPointer((void *) h);
  }
  static Handler *DecodeHandler(Block *p) {
    AssertStore(p->GetLabel() == HANDLERBLOCK_LABEL);
    return (Handler *) PointerOp::DecodeUnmanagedPointer(((word *) p)[0]);
  }
  // Deref Function
  static word Deref(word v) {
  loop:
    u_int vi = (u_int) v;

    if (!((vi ^ TRTAG) & TAGMASK)) {
      vi ^= (u_int) TRTAG;
      
      if (HeaderOp::DecodeLabel((Block *) vi) == REF_LABEL) {
	v = ((word *) vi)[0];
	goto loop;
      }
    }

    return v;
  }
};

#endif
