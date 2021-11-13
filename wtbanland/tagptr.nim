# (c) Copyright 2021 Shayan Habibi

## Aligned pointers that contain flags

template subShl(val: SomeInteger): untyped =
  (1 shl val) - 1

type
  TagPtrContext*[T] = object
    align: uint
    ptrMask: uint
    flagMask: uint



proc initContext*[T](align: static SomeInteger): TagPtrContext[T] {.compilerproc.} =
  ## Create a context for TagPtrs to use in extraction procedures
  let flagMask: uint = subShl align
  let ptrMask = high(uint) xor flagMask
  TagPtrContext[T](align: cast[uint](align), ptrMask: ptrMask, flagMask: flagMask)

type
  TagPtr* = distinct uint

# fold borrows
when true:
  proc `and`*(x: TagPtr, y: uint): TagPtr {.borrow.}
  proc `or`*(x: TagPtr, y: uint): TagPtr {.borrow.}
  proc `xor`*(x: TagPtr, y: uint): TagPtr {.borrow.}
  proc `+`*(x: TagPtr, y: uint): TagPtr {.borrow.}
  proc `-`*(x: TagPtr, y: uint): TagPtr {.borrow.}

proc getPtr*[T](tptr: TagPtr; ctx: static TagPtrContext[T]): ptr T =
  ## Use a tagptr context to extract the pointer out of the tagptr
  cast[ptr T](tptr and ctx.ptrMask)

proc getFlags*[T](tptr: TagPtr; ctx: static TagPtrContext[T]): uint =
  ## Use a tagptr context to extract the flags/tag out of the tagptr
  tptr and ctx.flagMask

proc getPtr*[T](tptr: TagPtr; align: static SomeInteger): ptr T =
  ## Using the alignment, extract the ptr out of the tagptr
  let flagMask = subShl align
  let ptrMask = high(uint) xor flagMask
  cast[ptr T](tptr and ptrMask)

proc getFlags*(tptr: TagPtr; align: static SomeInteger): uint =
  ## Using the alignment, extract the flags/tag out of the tagptr
  let flagMask = subShl align
  cast[uint](tptr and flagMask)

proc getPtrFlags*[T](tptr: TagPtr; ctx: static TagPtrContext[T]): (ptr T, uint) =
  (tptr.getPtr ctx, tptr.getFlags ctx)
proc getPtrFlags*[T](tptr: TagPtr; align: static SomeInteger): (ptr T, uint) =
  (tptr.getPtr[T](align), tptr.getFlags align)

import ./memalloc

proc alloc*[T](ctx: static TagPtrContext[T]): TagPtr =
  ## Allocates a memory region according to the TagPtrContext and returns a TagPtr
  cast[TagPtr](allocAligned0(sizeof(T), ctx.align))
proc dealloc*[T](tptr: TagPtr, ctx: static TagPtrContext[T]) =
  ## Deallocates a memory region according to the TagPtrContext
  deallocAligned(cast[pointer](tptr.getPtr(ctx)), ctx.align)