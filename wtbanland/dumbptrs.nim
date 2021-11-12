#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Nim contributors
#        (c) Copyright 2021 Planetis-M
#        (c) Copyright 2021 Shayan Habibi
#

## C++11 like smart pointers. They always use the shared allocator.
import wtbanland/atomics
import wtbanland/memalloc
import wtbanland/tagptr
import std/isolation
from typetraits import supportsCopyMem

proc raiseNilAccess() {.noinline.} =
  raise newException(NilAccessDefect, "dereferencing nil smart pointer")

template checkNotNil(p: typed) =
  when compileOption("boundChecks"):
    {.line.}:
      if p.isNil:
        raiseNilAccess()

when false: # unique_ptr
  type
    UniquePtr*[T] = object
      ## Non copyable pointer to a value of type `T` with exclusive ownership.
      val: ptr T

  proc `=destroy`*[T](p: var UniquePtr[T]) =
    if p.val != nil:
      `=destroy`(p.val[])
      deallocShared(p.val)

  proc `=copy`*[T](dest: var UniquePtr[T], src: UniquePtr[T]) {.error.}
    ## The copy operation is disallowed for `UniquePtr`, it
    ## can only be moved.

  proc newUniquePtr*[T](val: sink Isolated[T]): UniquePtr[T] {.nodestroy.} =
    ## Returns a unique pointer which has exclusive ownership of the value.
    result.val = cast[ptr T](allocShared(sizeof(T)))
    # thanks to '.nodestroy' we don't have to use allocShared0 here.
    # This is compiled into a copyMem operation, no need for a sink
    # here either.
    result.val[] = extract val
    # no destructor call for 'val: sink T' here either.

  template newUniquePtr*[T](val: T): UniquePtr[T] =
    newUniquePtr(isolate(val))

  proc newUniquePtr*[T](t: typedesc[T]): UniquePtr[T] =
    ## Returns a unique pointer. It is not initialized,
    ## so reading from it before writing to it is undefined behaviour!
    when not supportsCopyMem(T):
      result.val = cast[ptr T](allocShared0(sizeof(T)))
    else:
      result.val = cast[ptr T](allocShared(sizeof(T)))

  proc isNil*[T](p: UniquePtr[T]): bool {.inline.} =
    p.val == nil

  proc `[]`*[T](p: UniquePtr[T]): var T {.inline.} =
    ## Returns a mutable view of the internal value of `p`.
    checkNotNil(p)
    p.val[]

  proc `[]=`*[T](p: UniquePtr[T], val: sink Isolated[T]) {.inline.} =
    checkNotNil(p)
    p.val[] = extract val

  template `[]=`*[T](p: UniquePtr[T]; val: T) =
    `[]=`(p, isolate(val))

  proc `$`*[T](p: UniquePtr[T]): string {.inline.} =
    if p.val == nil: "nil"
    else: "(val: " & $p.val[] & ")"

#------------------------------------------------------------------------------
when true: # shared ptr
  type
    SharedPtr*[T] = object
      ## Shared ownership reference counting pointer.
      # val: ptr tuple[value: T, counter: Atomic[int]]
      val: Atomic[TagPtr]

  proc `=destroy`*[T](p: var SharedPtr[T]) =
    let val = p.val.load(moAcq)
    let (tptr, count) = val.getPtrFlags[T](11)
    if tptr != nil:
      if count == 0:
        `=destroy`(tptr[])
        deallocAligned(tptr, 11)
      else:
        discard p.val.fetchSub(1, moRel)

  proc `=copy`*[T](dest: var SharedPtr[T], src: SharedPtr[T]) =
    if src.val != nil:
      discard src.val.fetchAdd(1, moSeqCon)
    if dest.val != nil:
      `=destroy`(dest)
    dest.val = src.val

  proc newSharedPtr*[T](val: sink Isolated[T]): SharedPtr[T] {.nodestroy.} =
    ## Returns a shared pointer which shares
    ## ownership of the object by reference counting.
    let vptr = createAligned(T, 11)
    vptr[] = extract val
    let tptr = cast[TagPtr](vptr)
    result.val.store(tptr, moRel)

  template newSharedPtr*[T](val: T): SharedPtr[T] =
    newSharedPtr(isolate(val))

  proc newSharedPtr*[T](t: typedesc[T]): SharedPtr[T] =
    ## Returns a shared pointer. It is not initialized,
    ## so reading from it before writing to it is undefined behaviour!
    let tptr = cast[TagPtr](createAligned(T, 11))
    result.val.store(tptr, moRel)

  proc isNil*[T](p: SharedPtr[T]): bool {.inline.} =
    p.val.rawLoad() == nil

  proc `[]`*[T](p: SharedPtr[T]): var T {.inline.} =
    checkNotNil(p)
    p.val.rawLoad().getPtr[T](11)[]

  proc `[]=`*[T](p: SharedPtr[T], val: sink Isolated[T]) {.inline.} =
    checkNotNil(p)
    p.val.rawLoad().getPtr[T](11)[]= extract val

  template `[]=`*[T](p: SharedPtr[T]; val: T) =
    `[]=`(p, isolate(val))

  proc `$`*[T](p: SharedPtr[T]): string {.inline.} =
    if p.val == nil: "nil"
    else: "(val: " & $p.val.rawLoad().getPtr[T](11)[] & ")"

#------------------------------------------------------------------------------
when false: # const ptr
  type
    ConstPtr*[T] = distinct SharedPtr[T]
      ## Distinct version of `SharedPtr[T]`, which doesn't allow mutating the underlying value.

  proc newConstPtr*[T](val: sink Isolated[T]): ConstPtr[T] {.nodestroy, inline.} =
    ## Similar to `newSharedPtr<#newSharedPtr,T>`_, but the underlying value can't be mutated.
    ConstPtr[T](newSharedPtr(val))

  template newConstPtr*[T](val: T): ConstPtr[T] =
    newConstPtr(isolate(val))

  proc isNil*[T](p: ConstPtr[T]): bool {.inline.} =
    SharedPtr[T](p).val == nil

  proc `[]`*[T](p: ConstPtr[T]): lent T {.inline.} =
    ## Returns an immutable view of the internal value of `p`.
    checkNotNil(p)
    SharedPtr[T](p).val.value

  proc `[]=`*[T](p: ConstPtr[T], v: T) = {.error: "`ConstPtr` cannot be assigned.".}

  proc `$`*[T](p: ConstPtr[T]): string {.inline.} =
    $SharedPtr[T](p)
