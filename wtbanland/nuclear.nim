## (c) Copyright 2021 Shayan Habibi
## 
## Nuclear Pointers
## ================
## 
## This library emulates the behaviour of volatile pointers without using
## volatiles (where possible); the behaviour of volatile pointers is emulated
## using atomic stores and loads with a relaxed memory order.
## 
## Volatiles are used if the object store/load is larger than 8 bytes. Ideally,
## nuclear should be used to atomically alter the objects fields with a field
## operator.

template volatileLoad*[T](src: ptr T): T =
  ## Generates a volatile load of the value stored in the container `src`.
  ## Note that this only effects code generation on `C` like backends.
  when nimvm:
    src[]
  else:
    when defined(js):
      src[]
    else:
      var res: T
      {.emit: [res, " = (*(", typeof(src[]), " volatile*)", src, ");"].}
      res

template volatileStore*[T](dest: ptr T, val: T) =
  ## Generates a volatile store into the container `dest` of the value
  ## `val`. Note that this only effects code generation on `C` like
  ## backends.
  when nimvm:
    dest[] = val
  else:
    when defined(js):
      dest[] = val
    else:
      {.emit: ["*((", typeof(dest[]), " volatile*)(", dest, ")) = ", val, ";"].}

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
  ## This is a short hand for emulating the type declaration of ptrs and refs
  Nuclear[x]

template cptr*[T](x: nuclear T): ptr T =
  ## Alias for casting back to ptr
  cast[ptr T](x)

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
  ## Dereference the pointer atomically; only if T is less than 8 bytes
  ## In the case that the object type T is larger than 8 bytes and exceeds
  ## atomic assurances, we use volatile operations.

  when sizeof(T) <= sizeof(int):
    cast[T](
      atomic_load_explicit[nonAtomicType(T), atomicType(T)](
        cast[ptr atomicType(T)](cast[ptr T](nptr)), moRelaxed
      )
    )
  else:
    volatileLoad(nptr.cptr())


proc `[]=`*[T](x: nuclear T; y: T) {.inline.} =
  ## Assign value `y` to the region pointed by the nuclear pointer atomically.
  ## In the case that the object type T is larger than 8 bytes and exceeds
  ## atomic assurances, we use volatile operations.

  when sizeof(T) <= sizeof(int):
    atomic_store_explicit[nonAtomicType(T), atomicType(T)](
      cast[ptr atomicType(T)](x), cast[nonAtomicType(uint)](y), moRelaxed
      )
  else:
    volatileStore(x.cptr(), y)

proc `<-`*[T](x, y: nuclear T) {.inline.} =
  ## Load the value in y atomically and store it in x atomically.
  ## In the case that the object type T is larger than 8 bytes and exceeds
  ## atomic assurances, we use volatile operations.
  when sizeof(T) <= sizeof(int):
    atomic_store_explicit[nonAtomicType(T), atomicType(T)](
      cast[ptr atomicType(T)](x), y[], moRelaxed
    )
  else:
    volatileStore(x.cptr(), volatileLoad(y.cptr()))

proc `!+`*[T](x: nuclear T, y: int): pointer {.inline.} =
  cast[pointer](cast[int](x) + y)

proc isNil*[T](x: nuclear T): bool {.inline.} =
  ## Alias for `ptr T` isNil procedure.
  cast[ptr T](x).isNil

import std/macros

{.experimental: "dotOperators".}

macro `.`*[T](x: nuclear T, field: untyped): untyped =
  ## Allows field access to nuclear pointers of object types. The access of
  ## those fields will also be nuclear in that they enforce atomic operations
  ## of a relaxed order.

  var fieldType: NimNode
  var offset: int
  # var warning: NimNode

  template returnError(msg: string): untyped =
    result = nnkPragma.newTree:
      ident"error".newColonExpr: newLit(msg)
    result[0].copyLineInfo(x)
    return result

  # template warnUser(msg: string): untyped =
  #   warning = nnkPragma.newTree:
  #     ident"warning".newColonExpr: newLit(msg)
  #   warning[0].copyLineInfo(x)

  template checkNuclearType: untyped =
    case kind(getTypeImpl(getTypeInst(x)[1]))
    of nnkObjectTy: discard
    # of nnkTupleTy: warnUser "Nuclear access for tuples is not yet tested"
    of nnkTupleTy:
      {.warning: "Nuclear access for tuples is not yet tested".}
      discard
    of nnkRefTy:
      returnError "Nuclear field access for nuclears pointing to ref objects is not yet supported"
    else:
      returnError "This nuclear points to a type that is not an object; cannot do field access"
  
  checkNuclearType()

  var recList = findChild(getTypeImpl(getTypeInst(x)[1]), it.kind == nnkRecList)
  for index, n in recList:
    case n.kind
    of nnkIdentDefs:
      if $field == $n[0]:
        offset = getOffset(n[0])
        for index, fieldNode in n[1..^1]:
          case fieldNode.kind
          of nnkIdent, nnkSym:
            fieldType = fieldNode
            break
          else: discard
    else: discard 
  result = nnkStmtList.newTree(
    nnkCast.newTree(
      nnkBracketExpr.newTree(
        newIdentNode("Nuclear"),
        newIdentNode($fieldType)
      ),
      nnkInfix.newTree(
        newIdentNode("!+"),
        newIdentNode($x),
        newLit(offset)
      )
    )
  )

# type
#   Obj = object
#     field1: int
#     field2: int

# # var y = createShared(Obj)
# # y[] = Obj(field2: 5)
# var y = createShared(int)
# y[] = 5
# var x = nuclear y
# x.field2[] = 6
