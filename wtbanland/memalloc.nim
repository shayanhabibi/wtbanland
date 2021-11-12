#
#
#            Nim's Runtime Library
#        (c) Copyright 2015 Andreas Rumpf
#        (c) Copyright 2021 Shayan Habibi
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## I do not like the idea of having to pass masks etc to get an alignment
## that I can simply specify with an integer.
## I have readjusted this library for my own purposes; I want it so that if I
## say 'align to 16' itll align 16 bits. That way I dont have to say 'align to
## the number which is 16 bits true' or whatever it is.

template natShl(val: SomeInteger): untyped =
  (1 shl val)
template subShl(val: SomeInteger): untyped =
  (1 shl val) - 1


# Page size of the system; in most cases 4096 bytes. For exotic OS or
# CPU this needs to be changed:
const
  MemAlign = # also minimal allocatable memory block
    when defined(useMalloc):
      when defined(amd64): natShl 4 # 16
      else: natShl 3  # 8
    else: natShl 4  # 16

when not defined(js):
  # Allocator statistics for memory leak tests
  {.push stackTrace: off.}

  template `+!`(p: pointer, s: SomeInteger): pointer =
    cast[pointer](cast[int](p) +% int(s))

  template `-!`(p: pointer, s: SomeInteger): pointer =
    cast[pointer](cast[int](p) -% int(s))

  proc allocAligned*(size, align: Natural): pointer =
    ## Given the size of memory block to be allocated, and an alignment length,
    ## will return a pointer that is aligned to that number. Therefore,
    ## `allocAligned(8, 16)` will return a pointer to 8 byte length assigned
    ## memory region, however the pointer will have the first 16 bits clear.
    ## 
    ## This allocation does not zero the memory assigned, undefined behaviour
    ## if not initialised before reading!
    let valign = subShl align
    if valign <= MemAlign:
      when compileOption("threads"):
        result = allocShared(size)
      else:
        result = alloc(size)
    else:
      # allocate (size + align - 1) necessary for alignment,
      # plus 2 bytes to store offset
      when compileOption("threads"):
        let base = allocShared(size + valign - 1 + sizeof(uint16))
      else:
        let base = alloc(size + valign - 1 + sizeof(uint16))
      # memory layout: padding + offset (2 bytes) + user_data
      # in order to deallocate: read offset at user_data - 2 bytes,
      # then deallocate user_data - offset
      let offset = valign - (cast[int](base) and (valign - 1))
      cast[ptr uint16](base +! (offset - sizeof(uint16)))[] = uint16(offset)
      result = base +! offset

  proc allocAligned0*(size, align: Natural): pointer =
    ## Given the size of memory block to be allocated, and an alignment length,
    ## will return a pointer that is aligned to that number. Therefore,
    ## `allocAligned(8, 16)` will return a pointer to 8 byte length assigned
    ## memory region, however the pointer will have the first 16 bits clear.

    let valign = subShl align
    if valign <= MemAlign:
      when compileOption("threads"):
        result = allocShared0(size)
      else:
        result = alloc0(size)
    else:
      # see comments for alignedAlloc
      when compileOption("threads"):
        let base = allocShared0(size + valign - 1 + sizeof(uint16))
      else:
        let base = alloc0(size + valign - 1 + sizeof(uint16))
      let offset = valign - (cast[int](base) and (valign - 1))
      cast[ptr uint16](base +! (offset - sizeof(uint16)))[] = uint16(offset)
      result = base +! offset

  proc createAlignedU*[T](ttype: typedesc[T], align: Natural): ptr T =
    cast[ptr T](allocAligned(sizeof ttype, align))

  proc createAligned*[T](ttype: typedesc[T], align: Natural): ptr T =
    cast[ptr T](allocAligned0(sizeof ttype, align))

  proc deallocAligned*(p: pointer, align: int) {.compilerproc.} =
    ## Deallocates memory regions assigned with allocAligned or allocAligned0
    let valign = subShl align
    if valign <= MemAlign:
      when compileOption("threads"):
        deallocShared(p)
      else:
        dealloc(p)
    else:
      # read offset at p - 2 bytes, then deallocate (p - offset) pointer
      let offset = cast[ptr uint16](p -! sizeof(uint16))[]
      when compileOption("threads"):
        deallocShared(p -! offset)
      else:
        dealloc(p -! offset)

  proc deallocAligned*[T](p: ptr T, align: int) {.compilerproc.} =
    deallocAligned(cast[pointer](p), align)

  {.pop.}
