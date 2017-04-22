import nico
import util
import glm

{.this:self.}

type Object = ref object of RootObj
  pos: Vec2i
  size: Vec2i

method draw(self: Object) {.base.} =
  discard

type Rock = ref object of Object
  rockKind: int

method draw(self: Rock) =
  spr(32 + rockKind * 2, 16 + pos.x * 16, 16 + pos.y * 16, 2, 2)

proc newRock(pos: Vec2i): Rock =
  result = new(Rock)
  result.pos = pos
  result.size = vec2i(1,1)
  result.rockKind = rnd(2)

type Plant = ref object of Object

method draw(self: Plant) =
  spr(96, 16 + pos.x * 16, 16 + pos.y * 16, 2, 2)

proc newPlant(pos: Vec2i): Plant =
  result = new(Plant)
  result.size = vec2i(1,1)
  result.pos = pos

type Crystal = ref object of Object

method draw(self: Crystal) =
  spr(64, 16 + pos.x * 16, 16 + pos.y * 16, 2, 2)

proc newCrystal(pos: Vec2i): Crystal =
  result = new(Crystal)
  result.size = vec2i(1,1)
  result.pos = pos

type Ship = ref object of Object

method draw(self: Ship) =
  spr(192, 16 + pos.x * 16, 16 + pos.y * 16, 4, 4)

proc newShip(pos: Vec2i): Ship =
  result = new(Ship)
  result.size = vec2i(2,2)
  result.pos = pos

type Star = object
  pos: Vec2f
  brightness: int

# GLOBALS

var cursor = vec2i(0,0)
var cursorObject: Object
var objects: seq[Object]
var stars: seq[Star]
var shake: float = 0.0

type AlienKind = enum
  GreenAlien
  PinkAlien
  OrangeAlien
  BlueAlien
  YellowAlien
  RedAlien
  BlackAlien
  WhiteAlien

type Alien = ref object of Object
  kind: AlienKind

proc objectAtPos(pos: Vec2i): Object =
  for obj in mitems(objects):
    if obj.pos == pos:
      return obj
    elif pos.x >= obj.pos.x and pos.x < obj.pos.x + obj.size.x and pos.y >= obj.pos.y and pos.y < obj.pos.y + obj.size.y:
      return obj
  return nil

iterator getAdjacentObjects(pos: Vec2i): Object =
  let left = objectAtPos(pos + vec2i(-1,0))
  if left != nil:
    yield left
  let right = objectAtPos(pos + vec2i(1,0))
  if right != nil:
    yield right
  let up = objectAtPos(pos + vec2i(0,-1))
  if up != nil:
    yield up
  let down = objectAtPos(pos + vec2i(0,1))
  if down != nil:
    yield down

proc isConnectedToCrystal(self: Object, seen: var seq[Object]): bool =
  seen.add(self)
  for obj in getAdjacentObjects(self.pos):
    if obj of Crystal:
      return true
    if obj of Alien:
      let alien = Alien(obj)
      if not seen.contains(obj):
        if alien.kind == BlueAlien and obj.isConnectedToCrystal(seen):
          return true


proc isHappy(self: Alien): bool =
  case kind:
  of GreenAlien:
    # check if adjacent to plant
    for obj in getAdjacentObjects(pos):
      if obj of Plant:
        return true
  of PinkAlien:
    var adjacentAliens = 0
    for obj in getAdjacentObjects(pos):
      if obj of Alien:
        let alien = Alien(obj)
        if alien.kind != PinkAlien:
          adjacentAliens += 1
    if adjacentAliens > 2:
      return true
  of OrangeAlien:
    for obj in getAdjacentObjects(pos):
      if obj of Rock:
        return true
  of BlueAlien:
    for obj in getAdjacentObjects(pos):
      if obj of Alien:
        if Alien(obj).kind == OrangeAlien:
          return false
    var seen = newSeq[Object]()
    if isConnectedToCrystal(seen):
      return true
  else:
    discard
  return false

method draw(self: Alien) =
  spr(kind.int * 2, 16 + pos.x * 16, 16 + pos.y * 16, 2, 2)

proc newAlien(kind: AlienKind, pos: Vec2i): Alien =
  result = new(Alien)
  result.size = vec2i(1,1)
  result.kind = kind
  result.pos = pos


method move(obj: Object, target: Vec2i) {.base.} =
  shake += 1.0
  return

method move(obj: Alien, target: Vec2i) =
  if target.x < 0 or target.y < 0 or target.x > 5 or target.y > 5:
    shake += 1.0
    return
  if objectAtPos(target) == nil:
    obj.pos = target
  else:
    shake += 1.0

proc gameInit() =
  setWindowTitle("smalltrek")
  setTargetSize(128,128)
  setScreenSize(256,256)
  loadSpriteSheet("spritesheet.png")

  objects = newSeq[Object]()

  objects.add(newAlien(GreenAlien, vec2i(0, 0)))
  objects.add(newAlien(PinkAlien, vec2i(1, 0)))
  objects.add(newAlien(OrangeAlien, vec2i(2, 0)))
  objects.add(newAlien(BlueAlien, vec2i(2, 1)))
  objects.add(newAlien(BlueAlien, vec2i(2, 2)))

  objects.add(newRock(vec2i(3,3)))
  objects.add(newRock(vec2i(3,2)))
  objects.add(newRock(vec2i(5,5)))
  objects.add(newRock(vec2i(4,4)))
  objects.add(newPlant(vec2i(0,2)))
  objects.add(newCrystal(vec2i(1,5)))

  objects.add(newShip(vec2i(4,2)))

  stars = newSeq[Star]()
  for i in 0..100:
    stars.add(Star(pos: vec2f(rnd(128.0), rnd(128.0)), brightness: rnd(2)))

proc gameUpdate(dt: float) =
  if btnp(pcLeft):
    if cursorObject != nil:
      cursorObject.move(cursor + vec2i(-1,0))
      cursor = cursorObject.pos
    else:
      cursor.x -= 1
      if cursor.x < 0:
        cursor.x = 0

  if btnp(pcRight):
    if cursorObject != nil:
      cursorObject.move(cursor + vec2i(1,0))
      cursor = cursorObject.pos
    else:
      cursor.x += 1
      if cursor.x > 5:
        cursor.x = 5


  if btnp(pcUp):
    if cursorObject != nil:
      cursorObject.move(cursor + vec2i(0,-1))
      cursor = cursorObject.pos
    else:
      cursor.y -= 1
      if cursor.y < 0:
        cursor.y = 0


  if btnp(pcDown):
    if cursorObject != nil:
      cursorObject.move(cursor + vec2i(0,1))
      cursor = cursorObject.pos
    else:
      cursor.y += 1
      if cursor.y > 5:
        cursor.y = 5


  if btnp(pcA):
    if cursorObject == nil:
      let obj = objectAtPos(cursor)
      cursorObject = obj
    else:
      cursorObject = nil

  for star in mitems(stars):
    star.pos.x += cos(frame.float / 100.0) * dt
    star.pos.y += sin(frame.float / 110.0) * dt



proc gameDraw() =
  # background
  cls()
  # draw stars
  for star in stars:
    setColor(if star.brightness == 0: 1 else: 2)
    pset(star.pos.x.int, star.pos.y.int)

  setCamera(0,0)
  if shake > 0.0:
    setCamera(rnd(2)-1,rnd(2)-1)
    shake -= 1.0

  setColor(5)
  circfill(64,64,62)
  circfill(24,24,12)
  circfill(128-24,128-24,12)
  circfill(24,128-24,12)
  circfill(128-24,24,12)

  # grid
  setColor(6)
  for y in 0..6:
    for x in 0..6:
      pset(16+x*16,16+y*16)

  # draw sprites
  palt(5, true)
  palt(0, false)
  for obj in objects:
    obj.draw()

  # cursor
  block:
    if cursorObject == nil:
      setColor(8)
    else:
      setColor(11)
    let x = 16 + cursor.x * 16
    let y = 16 + cursor.y * 16
    pset(x,y)
    pset(x+1,y)
    pset(x,y+1)

    pset(x+16,y)
    pset(x+15,y)
    pset(x+16,y+1)

    pset(x,y+16)
    pset(x,y+15)
    pset(x+1,y+16)

    pset(x+16,y+16)
    pset(x+15,y+16)
    pset(x+16,y+15)

  setColor(3)
  for obj in objects:
    if obj of Alien:
      let alien = Alien(obj)
      if not alien.isHappy():
        spr(128, 16 + alien.pos.x * 16 + 12, 16 + alien.pos.y * 16 - 2)


nico.init()
nico.run(gameInit, gameUpdate, gameDraw)
