import random

type
  UncheckedArray{.unchecked.}[T] = array[0..0, T]

type Pool*[T] = object of RootObj
  size: int
  inUse: int # not necessary
  items*: ptr UncheckedArray[T]
  firstAvailable: ptr T

proc getNext[T](item: var T): ByteAddress =
  return cast[ByteAddress](item)

proc setNext[T](item: var T, next: ptr T) =
  var tmpNext = next
  copyMem(item.addr, tmpNext.addr, sizeof(pointer))

proc initPool*[T](size: int): Pool[T] =
  result.size = size
  result.items = cast[ptr UncheckedArray[T]](alloc(sizeof(T) * size))
  zeroMem(result.items, sizeof(T) * size)
  for i in 0..<size-1:
    result.items[i].setNext(result.items[i+1].addr)
  result.items[size-1].setNext(nil)
  result.firstAvailable = result.items[0].addr

proc destroy*[T](self: var Pool[T]) =
  dealloc(self.items)

proc add*[T](self: var Pool[T], item: T, force = false) =
  if self.firstAvailable == nil:
    # full, just ignore it
    if not force:
      return
    # force, free up a slot
    self.items[random(self.size)] = item
    return

  var newItem = self.firstAvailable
  # update the firstAvailable pointer
  self.firstAvailable = cast[ptr T](newItem[].getNext())

  newItem[] = item

  self.inUse += 1

proc free*[T](self: var Pool[T], item: var T) =
  item.setNext(self.firstAvailable)
  self.firstAvailable = item.addr

  self.inUse -= 1

iterator mitems*[T](self: var Pool[T]): var T {.inline.} =
  for i in 0..<self.size:
    yield self.items[i]

when isMainModule:

  type Thing = object
    ttl: float64
    foo: int
    bar: int
    inUse: bool

  var things = initPool[Thing](1000)
  for i in 0..<1000:
    things.add(Thing(inUse: true, ttl: i.float * 1.0))


  for v in things.mitems:
    if v.inUse:
      echo v

  while true:
    var nThings = 0

    for v in things.mitems:
      if v.inUse:
        nThings += 1
        v.ttl -= 0.1
        if v.ttl < 0.0:
          v.inUse = false
          things.free(v)

    echo "nthings: ", nThings

    if random(10) == 0:
      things.add(Thing(inUse: true, ttl: random(10.0)))

    if nThings == 0:
      break

  things.destroy()
