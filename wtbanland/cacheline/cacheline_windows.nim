# (c) copyright Shayan Habibi

import winim/lean

const
  bufferSize: int32 = 2048

proc getCacheLineSize*(): int =
  let relationship = cast[LOGICAL_PROCESSOR_RELATIONSHIP](relationCache)
  var len: DWORD = bufferSize
  let plen = cast[PDWORD](unsafeAddr len)
  var buff: array[bufferSize, SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX]
  let pbuff = cast[PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX](unsafeAddr buff)

  var bres = GetLogicalProcessorInformationEx(relationship, pbuff, plen)
  assert bres == 1

  for gr in buff:
    if gr.union1.Cache.Level == 1:
      let lineSize = gr.union1.Cache.LineSize.int
      result = lineSize
      break

echo getCacheLineSize()