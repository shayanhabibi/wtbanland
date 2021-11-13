## (c) Copyright 2021 Shayan Habibi
## 
## Nuclear Pointers
## ================
## 
## This library emulates the behaviour of volatile pointers without using
## volatiles (as it can be a controversial tool to use); the behaviour of
## volatile pointers is emulated using atomic stores and loads with a relaxed
## memory order.


# Just including the parts of atomics that I care about

{.push, header: "<stdatomic.h>".}

type
  MemoryOrder {.importc: "memory_order".} = enum
    moRelaxed
    moConsume
    moAcquire
    moRelease
    moAcquireRelease
    moSequentiallyConsistent

type
  AtomicInt8 {.importc: "_Atomic NI8".} = int8
  AtomicInt16 {.importc: "_Atomic NI16".} = int16
  AtomicInt32 {.importc: "_Atomic NI32".} = int32
  AtomicInt64 {.importc: "_Atomic NI64".} = int64

template nonAtomicType(T: typedesc): untyped =
    # Maps types to integers of the same size
    when sizeof(T) == 1: int8
    elif sizeof(T) == 2: int16
    elif sizeof(T) == 4: int32
    elif sizeof(T) == 8: int64

template atomicType(T: typedesc): untyped =
  # Maps the size of a trivial type to it's internal atomic type
  when sizeof(T) == 1: AtomicInt8
  elif sizeof(T) == 2: AtomicInt16
  elif sizeof(T) == 4: AtomicInt32
  elif sizeof(T) == 8: AtomicInt64

proc atomic_load_explicit[T, A](location: ptr A; order: MemoryOrder): T {.importc.}
proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.importc.}

when false: # might use these later
  proc atomic_exchange_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_compare_exchange_strong_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc.}
  proc atomic_compare_exchange_weak_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc.}

  # Numerical operations
  proc atomic_fetch_add_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_sub_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_and_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_or_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_xor_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}

{.pop.}

type
  Nuclear*[T] = distinct ptr T
  
template nuclear*(x: typed): untyped =
  ## This is a short hand for emulating the type declaration of ptrs and refs;
  ## with this you can type variables like so:
  ## ```
  ## var x: nuclear int
  ## echo typeof(x) # Nuclear[int]
  ## ```
  Nuclear[x]

proc nuclearAddr*[T](x: var T): nuclear T {.inline.} =
  ## Replicates the addr function, except it will return a `nuclear T`
  ## instead of a std `ptr T`
  Nuclear[T](addr x)

proc nuclear*[T](x: ptr T): nuclear T {.inline.} =
  ## Converts ptrs into nuclear pointers
  Nuclear[T](x)

proc nucleate*[T](x: ptr T | pointer): nuclear T {.inline, deprecated: "use nuclear".} =
  Nuclear[T](x)

proc `[]`*[T](nptr: nuclear T): T {.inline.} =
  ## Dereference the pointer atomically
  cast[T](
    atomic_load_explicit[nonAtomicType(T), atomicType(T)](
      cast[ptr atomicType(T)](cast[ptr T](nptr)), moRelaxed
    )
  )


proc `[]=`*[T](x: nuclear T; y: T) {.inline.} =
  ## Assign value `y` to the region pointed by the nuclear pointer atomically
  atomic_store_explicit[nonAtomicType(T), atomicType(T)](
    cast[ptr atomicType(T)](x), cast[nonAtomicType(uint)](y), moRelaxed
    )

proc `<-`*[T](x, y: nuclear T) {.inline.} =
  ## Load the value in y atomically and store it in x atomically.
  atomic_store_explicit[nonAtomicType(T), atomicType(T)](
    cast[ptr atomicType(T)](x), y[], moRelaxed
  )

proc isNil*[T](x: nuclear T): bool {.inline.} =
  ## Alias for `ptr T` isNil procedure.
  cast[ptr T](x).isNil