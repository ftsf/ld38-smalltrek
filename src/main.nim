import nico
import util
import glm
import strutils
import json
import tween
import algorithm
import pool

{.this:self.}

type ParticleKind = enum
  heartParticle
  crossParticle
  dustParticle

type Particle = object
  kind: ParticleKind
  pos: Vec2f
  vel: Vec2f
  ttl: float
  maxttl: float
  above: bool

type Object = ref object of RootObj
  name: string
  description: string
  pos: Vec2i
  size: Vec2i

method draw(self: Object) {.base.} =
  discard

method update(self: Object, dt: float) {.base.} =
  discard

type Rock = ref object of Object
  rockKind: int

method draw(self: Rock) =
  spr(64 + 4 + rockKind * 2, pos.x * 16, pos.y * 16, 2, 2)

proc newRock(pos: Vec2i): Rock =
  result = new(Rock)
  result.pos = pos
  result.size = vec2i(1,1)
  result.rockKind = rnd(2)
  result.name = "Rock"
  result.description = "A boring rock, beloved by\nRotans."

type Plant = ref object of Object
  eaten: bool

method draw(self: Plant) =
  if eaten:
    spr(98, pos.x * 16, pos.y * 16, 2, 2)
  else:
    spr(96, pos.x * 16, pos.y * 16, 2, 2)

proc newPlant(pos: Vec2i): Plant =
  result = new(Plant)
  result.size = vec2i(1,1)
  result.pos = pos
  result.name = "Plant"
  result.description = "A boring plant, beloved by\nthe Botarni."
  result.eaten = false

type Crystal = ref object of Object

method draw(self: Crystal) =
  spr(64, pos.x * 16, pos.y * 16, 2, 2)

proc newCrystal(pos: Vec2i): Crystal =
  result = new(Crystal)
  result.size = vec2i(1,1)
  result.pos = pos
  result.name = "Crystal"
  result.description = "A shiny crystal, a source\nof power for the Chrysornak."


type Movable = ref object of Object
  originalPos: Vec2i
  lastPos: Vec2i
  alpha: float

type Ship = ref object of Movable
  altitude: float

type SmallShip = ref object of Ship

proc newShip(pos: Vec2i): Ship =
  result = new(Ship)
  result.size = vec2i(2,2)
  result.pos = pos
  result.lastPos = pos
  result.altitude = 128

proc newSmallShip(pos: Vec2i): SmallShip =
  result = new(SmallShip)
  result.size = vec2i(1,1)
  result.pos = pos
  result.lastPos = pos
  result.altitude = 128
  result.name = "Away Ship"
  result.description = "A small ship for small\nadventures, easily moved."


type Star = object
  pos: Vec2f
  brightness: int

type Level = object
  dimensions: Vec2i
  toroidal: bool
  tension: float
  ship: Ship
  timeout: float
  moves: int

# GLOBALS

var levelId: int
var currentLevel: Level
var lastCursor = vec2i(0,0)
var cursor = vec2i(0,0)
var alpha = 0.0
var cursorObject: Object
var objects: seq[Object]
var stars: seq[Star]
var shake: float = 0.0
var time: float = 0.0
var scanning: bool
var particles: Pool[Particle]

var moveBuffer: seq[Vec2i]

proc getViewPos(self: Movable): Vec2i =
  let currentPos = vec2f(float(pos.x * 16), float(pos.y * 16))
  let lastPos = vec2f(float(lastPos.x * 16), float(lastPos.y * 16))
  return tween.easeOutCubic(alpha, lastPos, currentPos - lastPos).vec2i

method draw(self: Ship) =
  let pos = getViewPos()
  spr(192, pos.x, pos.y - altitude, 4, 4)

method draw(self: SmallShip) =
  let pos = getViewPos()
  spr(212+16, pos.x, pos.y - altitude, 2, 2)

proc drawParticles(above: bool) = 
  palt(5,true)
  palt(0,false)
  for p in particles.mitems:
    if p.ttl > 0:
      if above == p.above:
        case p.kind:
        of heartParticle:
          if p.ttl > p.maxttl * 0.5:
            spr(76, p.pos.x.int - 4, p.pos.y.int - 4)
          else:
            spr(92, p.pos.x.int - 4, p.pos.y.int - 4)
        of crossParticle:
          spr(77, p.pos.x.int - 4, p.pos.y.int - 4)
        of dustParticle:
          if p.ttl > p.maxttl / 2.0:
            spr(78, p.pos.x.int - 4, p.pos.y.int - 4)
          else:
            spr(79, p.pos.x.int - 4, p.pos.y.int - 4)

proc draw(self: Level) =
  # draw planet
  var altitude = 0
  for obj in objects:
    if obj of Ship:
      altitude = Ship(obj).altitude.int

  var offset: Vec2i
  offset.x = 64 - (dimensions.x * 16) div 2
  offset.y = 64 - (dimensions.y * 16) div 2 + altitude

  setCamera(-offset.x + (if shake > 0: rnd(2)-1 else: 0), -offset.y + (if shake > 0: rnd(2) - 1 else: 0))
  if shake > 0:
    shake -= 0.5

  setColor(5)
  circfill(128 div 2 - offset.x, 128 div 2 - offset.x, dimensions.x div 2 * 16 + 10)
  for y in 1..<dimensions.y:
    for x in 1..<dimensions.x:
      circfill(x*16,y*16,23)

  # draw grid
  # grid
  setColor(6)
  for y in 0..dimensions.y:
    for x in 0..dimensions.x:
      pset(x*16,y*16)

  drawParticles(false)

  # draw sprites
  palt(5, true)
  palt(0, false)
  for obj in objects:
    obj.draw()
  palt()

  # cursor
  block:
    if cursorObject == nil:
      setColor(8)
    else:
      setColor(11)
    let cx = cursor.x * 16
    let cy = cursor.y * 16
    let lastX = lastCursor.x * 16
    let lastY = lastCursor.y * 16

    let x = easeOutCubic(alpha, lastX.float, cx.float - lastX.float).int
    let y = easeOutCubic(alpha, lastY.float, cy.float - lastY.float).int

    if scanning:
      setColor(if frame mod 2 < 1: 2 else: 14)
      let y2 = y + (frame mod 32) div 2
      line(x, y2, x + 16, y2)

    if cursorObject == nil and frame mod 60 < 30:
      rectCorners(x-1,y-1,x+17,y+17)
    else:
      rectCorners(x,y,x+16,y+16)

  drawParticles(true)


type AlienKind = enum
  GreenAlien
  PinkAlien
  OrangeAlien
  BlueAlien
  YellowAlien
  RedAlien
  BlackAlien
  WhiteAlien
  Tribble

type Alien = ref object of Movable
  kind: AlienKind
  happy: bool
  multiplied: bool
  fed: bool

proc newAlien(kind: AlienKind, pos: Vec2i): Alien =
  result = new(Alien)
  result.size = vec2i(1,1)
  result.kind = kind
  result.pos = pos
  result.lastPos = pos
  case kind:
  of GreenAlien:
    result.name = "Botarni"
    result.description = "A mostly friendly plant loving\nhumanoid.\nGets aggressive when deprived\nof flora."
  of OrangeAlien:
    result.name = "Rotan"
    result.description = "An intelligent, rock dwelling\nhumanoid.\nProne to violence when not near\nrocks."
  of BlueAlien:
    result.name = "Chrysornak"
    result.description = "They gather their power from\ncrystals and can channel it\nthrough themselves to others.\nHates Mooki."
  of PinkAlien:
    result.name = "Partari"
    result.description = "A most friendly creature,\nthrives on diversity,\nNeeds the company of other\nspecies."
  of YellowAlien:
    result.name = "Omnatrus"
    result.description = "Eats plants.\nDestroys ecosystems.\nLike their own company."
  of RedAlien:
    result.name = "Mookarin"
    result.description = "Loves Mooki SOOO MUCH!\nNo Mooki, no nice."
  of BlackAlien:
    result.name = "Sordax"
    result.description = "Solitary creatures by nature.\nNeed some space to themself."
  of Tribble:
    result.name = "Mooki"
    result.description = "A violently fertile and\nadorably cute fluffy creature."
  else:
    discard


proc loadLevel(level: int): Level =
  echo "loadLevel: ", level
  var map: JsonNode
  try:
    map = parseFile(basePath & "/assets/map" & $level & ".json")
  except IOError:
    levelId = 1
    return loadLevel(levelId)

  result.dimensions.x = map["width"].num.int
  result.dimensions.y = map["width"].num.int
  result.tension = 1.0
  result.timeout = 2.0
  result.moves = 0

  objects = newSeq[Object]()
  cursorObject = nil

  for layer in map["layers"].elems:
    var i = 0
    for t in layer["data"].elems:
      let pos = vec2i(i mod result.dimensions.x, i div result.dimensions.x)
      let tn = t.num.int - 1

      case tn:
      of 0,1,2,3,4,5,6,7:
        objects.add(newAlien(tn.AlienKind, pos))
      of 20:
        objects.add(newAlien(Tribble, pos))
      of 16,17:
        objects.add(newCrystal(pos))
      of 18,19:
        objects.add(newRock(pos))
      of 24:
        objects.add(newPlant(pos))
      of 48:
        result.ship = newShip(pos)
        objects.add(result.ship)
      of 58:
        result.ship = newSmallShip(pos)
        objects.add(result.ship)
      else:
        discard

      i += 1

  if result.ship != nil:
    cursor = result.ship.pos
    lastCursor = cursor

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

proc hasAdjacentFreeSpace(pos: Vec2i): bool =
  if pos.x > 0 and objectAtPos(pos + vec2i(-1,0)) == nil:
    return true
  if pos.x < currentLevel.dimensions.x - 1 and objectAtPos(pos + vec2i(1,0)) == nil:
    return true
  if pos.y > 0 and objectAtPos(pos + vec2i(0,-1)) == nil:
    return true
  if pos.y < currentLevel.dimensions.y - 1 and objectAtPos(pos + vec2i(0,1)) == nil:
    return true
  return false

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
      if obj of Plant and not Plant(obj).eaten:
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
        if Alien(obj).kind == Tribble:
          return false
    var seen = newSeq[Object]()
    if isConnectedToCrystal(seen):
      return true
  of YellowAlien:
    var happy = false
    for obj in getAdjacentObjects(pos):
      if obj of Plant and not Plant(obj).eaten:
        Plant(obj).eaten = true
        for i in 0..10:
          particles.add(Particle(kind: dustParticle, pos: (obj.pos * 16).vec2f + vec2f(8.0, 8.0), vel: rndVec(1.0), ttl: 0.5, maxttl: 0.5, above: true))
      elif obj of Alien and Alien(obj).kind == YellowAlien:
        happy = true
    return happy
  of RedAlien:
    if not fed:
      for obj in getAdjacentObjects(pos):
        if obj of Alien and Alien(obj).kind == Tribble:
          objects.del(objects.find(obj))
          fed = true
          break
    return fed
  of BlackAlien:
    if hasAdjacentFreeSpace(pos):
      return true
  of Tribble:
    return multiplied
  else:
    discard
  return false

method update(self: Movable, dt: float) =
  if lastPos != pos:
    alpha += dt * 8.0
    if frame mod 2 == 0:
      particles.add(Particle(kind: dustParticle, pos: getViewPos().vec2f + vec2f(8.0, 8.0), vel: rndVec(0.5), ttl: 0.5, maxttl: 0.5, above: false))
    if alpha >= 1.0:
      lastPos = pos
      alpha = 0.0

method update(self: Alien, dt: float) =
  procCall update(Movable(self), dt)
  if kind == Tribble and frame mod 15 == 0:
    for obj in getAdjacentObjects(pos):
      if obj of Alien and Alien(obj).kind == Tribble:
        multiplied = true
        # spawn more tribbles if there's any space
        if pos.x > 0 and objectAtPos(pos + vec2i(-1,0)) == nil:
          objects.add(newAlien(Tribble, pos + vec2i(-1,0)))
        elif pos.x < currentLevel.dimensions.x - 1 and objectAtPos(pos + vec2i(1,0)) == nil:
          objects.add(newAlien(Tribble, pos + vec2i(1,0)))
        elif pos.y > 0 and objectAtPos(pos + vec2i(0,-1)) == nil:
          objects.add(newAlien(Tribble, pos + vec2i(0,-1)))
        elif pos.y < currentLevel.dimensions.y - 1 and objectAtPos(pos + vec2i(0,1)) == nil:
          objects.add(newAlien(Tribble, pos + vec2i(0,1)))
  if isHappy():
    if not happy:
      particles.add(Particle(kind: heartParticle, pos: vec2f(pos * 16) + vec2f(8.0, 0.0), vel: vec2f(0, -0.25), ttl: 0.5, maxttl: 0.5, above: true))
    happy = true
  else:
    if happy:
      particles.add(Particle(kind: crossParticle, pos: vec2f(pos * 16) + vec2f(8.0, 0.0), vel: vec2f(0, -0.25), ttl: 0.5, maxttl: 0.5, above: true))
    happy = false

  if currentLevel.tension <= 0 and currentLevel.timeout >= 1.9:
    particles.add(Particle(kind: heartParticle, pos: vec2f(pos * 16) + vec2f(8.0, 0.0), vel: vec2f(rnd(0.5)-0.25, -0.25 - rnd(0.5)), ttl: 4.0, maxttl: 4.0, above: true))


method draw(self: Alien) =
  let viewPos = getViewPos()
  if scanning and cursor == pos:
    pal(0,if frame mod 10 < 5: 15 else: 2)
  else:
    pal(0,0)
  if kind == Tribble:
    if multiplied:
      spr(74, viewPos.x.int, viewPos.y.int, 2, 2)
    else:
      spr(72, viewPos.x.int + cos(frame.float / 30.0 + pos.x.float * 2.1) * 3, viewPos.y.int + sin(frame.float / 40.0 + pos.y.float * 2.1) * 2, 2, 2)
  else:
    if happy:
      spr(kind.int * 2, viewPos.x.int, viewPos.y.int, 2, 2)
    else:
      spr(32 + kind.int * 2, viewPos.x.int + cos(frame.float / 30.0 + pos.x.float * 2.1) * 2, viewPos.y.int, 2, 2)
  pal(0,0)

method update(self: Ship, dt: float) =
  if currentLevel.tension <= 0 and currentLevel.timeout <= 0:
    shake += 0.5
    altitude = lerp(altitude, 128, 0.01)
    if altitude < 10 and altitude > 1:
      particles.add(Particle(kind: dustParticle, pos: (pos * 16).vec2f + vec2f(8.0, 8.0), vel: rndVec(1.0), ttl: 0.5, maxttl: 0.5, above: false))
  else:
    if altitude > 0:
      shake += 0.5
      altitude = lerp(altitude, 0, 0.05)
      if altitude < 10 and altitude > 1:
        particles.add(Particle(kind: dustParticle, pos: (pos * 16).vec2f + vec2f(8.0, 8.0), vel: rndVec(1.0), ttl: 0.5, maxttl: 0.5, above: false))
      if altitude < 0.01:
        altitude = 0
    if altitude == 0:
      procCall update(Movable(self), dt)

method move(self: Object, target: Vec2i) {.base.} =
  shake += 1.0
  return

method move(self: Movable, target: Vec2i) =
  if pos != lastPos:
    return
  if target.x < 0 or target.y < 0 or target.x > currentLevel.dimensions.x - 1 or target.y > currentLevel.dimensions.y - 1:
    shake += 1.0
    return
  if objectAtPos(target) == nil:
    pos = target
    alpha = 0.0
  else:
    shake += 1.0

  objects.sort() do(a,b: Object) -> int:
    return a.pos.y - b.pos.y

method move(self: Ship, target: Vec2i) =
  if altitude > 0:
    return
  procCall move(Movable(self), target)

proc update(self: var Level, dt: float) =

  if tension > 0:
    if btnp(pcLeft):
      moveBuffer.add(vec2i(-1,0))
    if btnp(pcRight):
      moveBuffer.add(vec2i(1,0))
    if btnp(pcUp):
      moveBuffer.add(vec2i(0,-1))
    if btnp(pcDown):
      moveBuffer.add(vec2i(0,1))
    if btnp(pcA):
      moveBuffer.add(vec2i(0,0))

  if cursor == lastCursor and moveBuffer.len > 0:
    let move = moveBuffer.pop()

    if move.x == 0 and move.y == 0:
      if cursorObject == nil:
        # pick up
        let obj = objectAtPos(cursor)
        cursorObject = obj
        if cursorObject != nil:
          if cursorObject of Movable:
            Movable(cursorObject).originalPos = obj.pos
      else:
        # drop
        if cursorObject of Movable and cursorObject.pos != Movable(cursorObject).originalPos:
          currentLevel.moves += 1
        cursorObject = nil
    elif cursorObject != nil:
      cursorObject.move(cursor + move)
      cursor = cursorObject.pos
      alpha = 0.0
    else:
      cursor += move
      cursor.x = clamp(cursor.x, 0, dimensions.x - 1)
      cursor.y = clamp(cursor.y, 0, dimensions.y - 1)
      alpha = 0.0

  if cursor != lastCursor:
    alpha += dt * 8.0
    if alpha >= 1.0:
      lastCursor = cursor

  if btnp(pcX):
    scanning = not scanning


  for obj in mitems(objects):
    obj.update(dt)

  if tension <= 0:
    timeout -= dt
    if timeout < 0 and ship.altitude > 120:
      levelId += 1
      currentLevel = loadLevel(levelId)

  for p in particles.mitems:
    p.ttl -= dt
    if p.ttl < 0:
      particles.free(p)
    else:
      p.pos += p.vel
      p.vel *= 0.98



proc gameInit() =
  setWindowTitle("smalltrek")
  setTargetSize(128,128)
  setScreenSize(256,256)
  loadSpriteSheet("spritesheet.png")

  particles = initPool[Particle](256)

  levelId = 1
  currentLevel = loadLevel(1)

  moveBuffer = newSeq[Vec2i]()

  stars = newSeq[Star]()
  for i in 0..100:
    stars.add(Star(pos: vec2f(rnd(128.0), rnd(128.0)), brightness: rnd(2)))

  time = 0.0

proc gameUpdate(dt: float) =
  time += dt

  for star in mitems(stars):
    star.pos.x += cos(frame.float / 100.0) * dt
    star.pos.y += sin(frame.float / 110.0) * dt

  currentLevel.update(dt)

  if btnp(pcB):
    levelId += 1
    currentLevel = loadLevel(levelId)

  if btnp(pcY):
    currentLevel = loadLevel(levelId)

proc rectCorners(x,y,w,h: cint) =
  pset(x,y)
  pset(x+1,y)
  pset(x,y+1)

  pset(x+w,y)
  pset(x+w-1,y)
  pset(x+w,y+1)

  pset(x+w,y+h)
  pset(x+w-1,y+h)
  pset(x+w,y+h-1)

  pset(x,y+h)
  pset(x+1,y+h)
  pset(x,y+h-1)

proc gameDraw() =
  # background
  setCamera()
  cls()
  # draw stars
  for star in stars:
    setColor(if star.brightness == 0: 1 else: 2)
    pset(star.pos.x.int, star.pos.y.int)

  currentLevel.draw()

  setCamera()

  var happy = 0
  var sad = 0

  setColor(3)
  for obj in objects:
    if obj of Alien:
      let alien = Alien(obj)
      if not alien.happy:
        #let viewPos = alien.getViewPos()
        #spr(128, viewPos.x + 12, viewPos.y - 2)
        sad += 1
      else:
        happy += 1

  if scanning:
    setColor(if frame mod 4 < 2: 2 else: 14)
    printShadowR("scanning", 126, 2)
  else:
    let targetTension = sad.float / (happy + sad).float
    currentLevel.tension = lerp(currentLevel.tension, targetTension, 0.1)

    let tensionPercent = (currentLevel.tension * 100.0).int

    if tensionPercent <= 0:
      setColor(if frame mod 10 < 5: 11 else: 10)
      currentLevel.tension = 0
    elif tensionPercent <= 50:
      setColor(8)
    else:
      setColor(3)
    printShadowR("tension: $1%".format(tensionPercent), 126, 2 - (10.0 * (2.0 - currentLevel.timeout).int))

  if currentLevel.tension <= 0:
    setColor(2)
    printShadowC("Hostilities Ceased", 64, 100)
    printShadowC("Moves: $1".format(currentLevel.moves), 64, 110)

  if scanning:
    let scanobj = objectAtPos(cursor)
    if scanobj != nil:
      setColor(14)
      printShadow(scanobj.name, 2, 72)
      if scanobj of Alien:
        if Alien(scanobj).happy:
          setColor(11)
          printShadowR("content", 126, 72)
        else:
          setColor(3)
          printShadowR("hostile", 126, 72)

      var y = 82
      setColor(15)
      for line in scanobj.description.splitLines:
        printShadow(line, 2, y)
        y += 9

  setColor(13)
  printShadowR("[Z] grab [X] scan [C] menu", 124, 118)


nico.init()
nico.run(gameInit, gameUpdate, gameDraw)
