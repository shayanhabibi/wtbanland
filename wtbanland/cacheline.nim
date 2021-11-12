when defined(windows):
  import ./cacheline/cacheline_windows
  export cacheline_windows
else:
  proc getCacheLineSize*(): int {.compileTime.} = 64

# proc checkCacheSize*() {.compileTime.} =
#   let ls = getCacheLineSize()
#   if 0 < ls and ls != 64:
#     echo "The cache line size of your CPU is not 64 bytes; performance cannot be guaranteed by Amphetanim"
#   elif ls == 0:
#     echo "Was not able to determine the cache line size of your CPU. Performance cannot be guaranteed by Amphetanim"

# checkCacheSize()