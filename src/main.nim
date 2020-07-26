import nico
import nico.vec
import util
import strutils
import json
import tween
import algorithm
import sequtils
import pool
import math
import glitch
import gamerzilla
import sdl2/sdl

{.this:self.}

####
## Alpha Quadrant 1-8
# Green Orange Blue and Pink aliens

## Beta Quadrant 9-16
# introduce Cuwudles
# introduce Yellow aliens
# introduce Red aliens

## Delta Quadrant 17-24
# introduce black aliens

## Gamma Quadrant 24-32
# introduce white aliens

type SFX = enum
  sfxDrop
  sfxMove
  sfxGrab
  sfxLand
  sfxTakeoff
  sfxHeart
  sfxCross
  sfxSuccess
  sfxFailure
  sfxHyperdrive
  sfxEat
  sfxGlomp
  sfxBump
  sfxCursor
  sfxAborted

converter toInt*(sfx: SFX): int =
  return sfx.int

type ParticleKind = enum
  heartParticle
  crossParticle
  dustParticle
  bloodParticle

type Particle = object
  kind: ParticleKind
  pos: Vec2f
  vel: Vec2f
  ttl: float32
  maxttl: float32
  above: bool

type Object = ref object of RootObj
  killed: bool
  name: string
  description: string
  pos: Vec2i
  size: Vec2i

proc dummyInit()
proc menuInit()
proc menuUpdate(dt: float32)
proc menuDraw()

method draw(self: Object) {.base.} =
  discard

method update(self: Object, dt: float32) {.base.} =
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
  result.name = "ROCK"
  result.description = "A boring rock, full of\ndelicious minerals.\nbeloved by ROTANS."

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
  result.name = "PLANT"
  result.description = "A nutritious edible plant.\nRequires plenty of sunlight.\nRequired by the BOTARNI."
  result.eaten = false

type Crystal = ref object of Object

method draw(self: Crystal) =
  spr(64, pos.x * 16, pos.y * 16, 2, 2)

proc newCrystal(pos: Vec2i): Crystal =
  result = new(Crystal)
  result.size = vec2i(1,1)
  result.pos = pos
  result.name = "CRYSTAL"
  result.description = "A shiny crystal, a source\nof power for the CHRYSORNAK."


type Movable = ref object of Object
  originalPos: Vec2i
  lastPos: Vec2i
  alpha: float32

type Ship = ref object of Movable
  altitude: float32

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
  result.name = "SMALL SHIP"
  result.description = "A small ship for small\nadventures, easily moved."


type Star = object
  pos: Vec2f
  brightness: float32

type Level = object
  dimensions: Vec2i
  toroidal: bool
  tension: float32
  ship: Ship
  timeout: float32
  moves: int
  failed: bool
  success: bool
  aborted: bool

type Message = object
  text: string
  step: int
  ttl: float32

type GameStats {.pure.} = enum
  Eradicated

# GLOBALS

var frame: int
var levelId: int
var nextLevelId: int
var previousLevelId: int = -1
var unlockedLevel: float32
var levelsCompleted: array[32, int]
var gameStatsCollected: array[GameStats, int]
var currentLevel: Level
var lastCursor = vec2i(0,0)
var cursor = vec2i(0,0)
var alpha = 0.0
var cursorObject: Object
var objects: seq[Object]
var stars: seq[Star]
var shake: float32 = 0.0
var time: float32 = 0.0
var scanning: bool
var particles: Pool[Particle]
var confirmAbort: bool
var warpUnlocked: bool
var messages: seq[Message]
var gameID: int

var moveBuffer: seq[Vec2i]


proc updateTrophies() =
  var num : cint = 0
  gamerzilla.getTrophyStat(gameID, "Peace!", num.addr)
  var tmp : cint = 0
  for i in 0..<levelsCompleted.len:
    if levelsCompleted[i] > 0:
      tmp += 1
  if tmp > num:
    gamerzilla.setTrophyStat(gameID, "Peace!", tmp)
  if gameStatsCollected[GameStats.Eradicated] > 0:
    gamerzilla.setTrophy(gameID, "You Monster")

proc getViewPos(self: Movable): Vec2i =
  let currentPos = vec2f(float32(pos.x * 16), float32(pos.y * 16))
  let lastPos = vec2f(float32(lastPos.x * 16), float32(lastPos.y * 16))
  return tween.easeOutCubic(alpha, lastPos, currentPos - lastPos).vec2i + (if Object(self) == cursorObject: vec2i(0, -4) else: vec2i(0,0))

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
        of bloodParticle:
          if p.ttl > p.maxttl / 2.0:
            spr(78+16, p.pos.x.int - 4, p.pos.y.int - 4)
          else:
            spr(79+16, p.pos.x.int - 4, p.pos.y.int - 4)

var camera: Vec2f

proc drop(self: var Level)

proc draw(self: Level) =
  # draw planet
  var altitude = ship.altitude

  let shipCamera = vec2i(-ship.getViewPos().x + 64 - 8, -ship.getViewPos().y + 64 + altitude).vec2f
  let planetCamera = vec2i(64 - (dimensions.x * 16) div 2, 64 - (dimensions.y * 16) div 2).vec2f
  let scanningCamera = -(cursor * 16 + 8).vec2f + vec2f(64.0,64.0-24.0)

  if scanning:
    camera = lerp(camera, lerp(scanningCamera, shipCamera, ship.altitude / 128.0), 0.2)
  else:
    camera = lerp(camera, lerp(planetCamera, shipCamera, ship.altitude / 128.0), 0.2)

  setCamera(-camera.x.int + (if shake > 0: rnd(2)-1 else: 0), -camera.y.int + (if shake > 0: rnd(2) - 1 else: 0))
  if shake > 0:
    shake -= 0.5

  setColor(5)
  let center = (dimensions.x * 16) div 2
  circfill(center, center, dimensions.x div 2 * 16 + 10)
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
  if tension > 0:
    if cursorObject == nil:
      setColor(8)
    else:
      setColor(11)
    let cx = cursor.x * 16
    let cy = cursor.y * 16
    let lastX = lastCursor.x * 16
    let lastY = lastCursor.y * 16

    let x = easeOutCubic(alpha, lastX.float32, cx.float32 - lastX.float32).int
    let y = easeOutCubic(alpha, lastY.float32, cy.float32 - lastY.float32).int

    if scanning:
      setColor(if frame mod 2 < 1: 2 else: 14)
      let y2 = y + (frame mod 32) div 2
      line(x, y2, x + 16, y2)

    if cursorObject == nil and frame mod 60 < 30:
      rectCorners(x-1,y-1,x+17,y+17)
    else:
      rectCorners(x+1,y+1,x+15,y+15)

  drawParticles(true)

  if ship.altitude > 100:
    let viewpos = ship.getViewPos()
    setColor(14)
    let s = ship.altitude - 100
    circfill(viewpos.x + 8, viewpos.y - altitude + 16, s * s)
    setColor(2)
    circfill(viewpos.x + 8, viewpos.y - altitude + 16, (s * s) * 0.5)

  setCamera()

  if confirmAbort:
    setColor(if frame mod 30 < 15: 3 else: 2)
    printShadowC("REALLY ABORT MISSION?", 64, 60)
    setColor(2)
    printShadowC("[Z] cancel [X] abort", 64, 80)
    printShadowC("[C] restart", 64, 90)



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
    result.name = "BOTARNI"
    result.description = "A mostly friendly PLANT loving\nhumanoid.\nGets aggressive when deprived\nof flora."
  of OrangeAlien:
    result.name = "ROTAN"
    result.description = "An intelligent, ROCK dwelling\nhumanoid.\nProne to violence when not near\nROCKS."
  of BlueAlien:
    result.name = "CHRYSORNAK"
    result.description = "They gather their power from\nCRYSTALS and can channel it\nthrough themselves to others.\nHates CUWUDLES."
  of PinkAlien:
    result.name = "PARTARI"
    result.description = "A most friendly creature,\nthrives on diversity,\nNeeds the company of\nOTHER SPECIES."
  of YellowAlien:
    result.name = "OMNATRUS"
    result.description = "Eats PLANTS.\nDestroys ecosystems.\nLike their own company."
  of RedAlien:
    result.name = "MOOKARIN"
    result.description = "Loves CUWUDLES SOOO MUCH!\nNo Cuwudle, no nice."
  of BlackAlien:
    result.name = "SORDAX"
    result.description = "Solitary creatures by nature.\nNeed some SPACE to themself."
  of WhiteAlien:
    result.name = "CARDAK"
    result.description = "Mighty regimented warriors.\nHappy when ALIGNED on a grid.\nBut not TOO CLOSE.\nViolent when displeased."
  of Tribble:
    result.name = "CUWUDLE"
    result.description = "A violently fertile and\nadorably CUTE fluffy creature.\nNeeds to reproduce to be happy."


proc loadLevel(level: int): Level =
  levelId = level
  var map: JsonNode
  try:
    map = parseFile(basePath & "/assets/map" & $(level+1) & ".json")
  except IOError:
    raise newException(Exception,"no such level: map$1.json".format(level+1))

  result.dimensions.x = map["width"].num.int
  result.dimensions.y = map["width"].num.int
  result.tension = 1.0
  result.timeout = 2.0
  result.moves = 0
  result.success = false

  scanning = false

  confirmAbort = false

  for s in mitems(stars):
    s.pos = rndVec(128) + 64

  for p in particles.mitems:
    p.ttl = 0
    particles.free(p)

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

  sfx(3,sfxLand.int)

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
        sfx(-1,sfxEat.int)
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
          obj.killed = true
          if obj == cursorObject:
            currentLevel.drop()
          fed = true
          break
    return fed
  of BlackAlien:
    if hasAdjacentFreeSpace(pos):
      return true
  of WhiteAlien:
    if not happy:
      for obj in getAdjacentObjects(pos):
        if obj of Alien:
          if Alien(obj).kind == Tribble:
            for i in 0..10:
              particles.add(Particle(kind: bloodParticle, pos: lerp(getViewPos().vec2f + vec2f(8.0,8.0), (obj.pos * 16).vec2f + vec2f(8.0, 8.0), 0.5), vel: rndVec(2.0), ttl: 0.25, maxttl: 0.25, above: true))
            obj.killed = true
            # killed a tribble =(
            if obj == cursorObject:
              currentLevel.drop()
    # check if we have adjacent or aligned other whites
    var tooClose = false
    var aligned = false
    for x in 0..<currentLevel.dimensions.x:
      let obj = objectAtPos(vec2i(x,pos.y))
      if obj != nil and obj != self and obj of Alien and Alien(obj).kind == WhiteAlien:
        if x >= pos.x - 1 and x <= pos.x + 1:
          if Alien(obj).happy:
            Alien(obj).happy = false
            particles.add(Particle(kind: crossParticle, pos: vec2f(obj.pos * 16) + vec2f(8.0, 0.0), vel: vec2f(0, -0.25), ttl: 0.5, maxttl: 0.5, above: true))
          tooClose = true
        aligned = true
    for y in 0..<currentLevel.dimensions.y:
      let obj = objectAtPos(vec2i(pos.x,y))
      if obj != nil and obj != self and obj of Alien and Alien(obj).kind == WhiteAlien:
        if y >= pos.y - 1 and y <= pos.y + 1:
          if Alien(obj).happy:
            Alien(obj).happy = false
            particles.add(Particle(kind: crossParticle, pos: vec2f(obj.pos * 16) + vec2f(8.0, 0.0), vel: vec2f(0, -0.25), ttl: 0.5, maxttl: 0.5, above: true))
          tooClose = true
        aligned = true
    if not tooClose and aligned:
      return true
  of Tribble:
    return multiplied
  return false

method update(self: Movable, dt: float32) =
  if lastPos != pos:
    alpha += dt * 8.0
    if frame mod 2 == 0:
      particles.add(Particle(kind: dustParticle, pos: getViewPos().vec2f + vec2f(8.0, 8.0), vel: rndVec(0.5), ttl: 0.5, maxttl: 0.5, above: false))
    if alpha >= 1.0:
      lastPos = pos
      alpha = 0.0

method update(self: Alien, dt: float32) =
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
    if multiplied:
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
      sfx(1,sfxHeart.int)
    happy = true
  else:
    if happy:
      particles.add(Particle(kind: crossParticle, pos: vec2f(pos * 16) + vec2f(8.0, 0.0), vel: vec2f(0, -0.25), ttl: 0.5, maxttl: 0.5, above: true))
      sfx(1,sfxCross.int)
    happy = false

  if currentLevel.tension <= 0 and not currentLevel.failed and currentLevel.timeout >= 1.9:
    particles.add(Particle(kind: heartParticle, pos: vec2f(pos * 16) + vec2f(8.0, 0.0), vel: vec2f(rnd(0.5)-0.25, -0.25 - rnd(0.5)), ttl: 4.0, maxttl: 4.0, above: true))


method draw(self: Alien) =
  let viewPos = getViewPos()
  if Object(self) == cursorObject:
    spr(100, viewPos.x, viewPos.y + 8, 2, 2)
  if scanning and cursor == pos:
    pal(0,if frame mod 10 < 5: 15 else: 2)
  else:
    pal(0,0)
  if kind == Tribble:
    if multiplied:
      spr(74, viewPos.x.int, viewPos.y.int, 2, 2)
    else:
      spr(72, viewPos.x.int + cos(frame.float32 / 30.0 + pos.x.float32 * 2.1) * 3, viewPos.y.int + sin(frame.float32 / 40.0 + pos.y.float32 * 2.1) * 2, 2, 2)
  else:
    if happy:
      spr(kind.int * 2, viewPos.x.int, viewPos.y.int, 2, 2)
    else:
      spr(32 + kind.int * 2, viewPos.x.int + cos(frame.float32 / 30.0 + pos.x.float32 * 2.1) * 2, viewPos.y.int, 2, 2)
  pal(0,0)

method update(self: Ship, dt: float32) =
  if (currentLevel.success or currentLevel.failed or currentLevel.aborted) and currentLevel.timeout <= 0:
    if altitude == 0:
      sfx(3,sfxTakeoff.int)
      if currentLevel.failed:
        gameStatsCollected[GameStats.Eradicated] += 1
        updateConfigValue("Stats", $GameStats.Eradicated, $gameStatsCollected[GameStats.Eradicated])
        saveConfig();
        updateTrophies()
    # taking off
    shake += 0.5
    altitude = lerp(altitude, 128, 0.01)
    if altitude < 10 and altitude > 1:
      particles.add(Particle(kind: dustParticle, pos: (pos * 16).vec2f + vec2f(8.0, 8.0), vel: rndVec(1.0), ttl: 0.5, maxttl: 0.5, above: false))
    if altitude.int == 100:
      sfx(3,sfxHyperdrive.int)
      altitude = 101

  else:
    if altitude > 0:
      #landing
      shake += 0.5
      altitude = lerp(altitude, 0, 0.05)
      if altitude < 10 and altitude > 1:
        particles.add(Particle(kind: dustParticle, pos: (pos * 16).vec2f + vec2f(8.0, 8.0), vel: rndVec(1.0), ttl: 0.5, maxttl: 0.5, above: false))
      if altitude < 1.0:
        altitude = 0
        sfx(2,sfxDrop.int)
    if altitude == 0:
      procCall update(Movable(self), dt)

method move(self: Object, target: Vec2i) {.base.} =
  shake += 1.0
  sfx(2,sfxBump.int)
  return

method move(self: Movable, target: Vec2i) =
  if pos != lastPos:
    return
  if target.x < 0 or target.y < 0 or target.x > currentLevel.dimensions.x - 1 or target.y > currentLevel.dimensions.y - 1:
    shake += 1.0
    sfx(2,sfxBump.int)
    return
  if objectAtPos(target) == nil:
    pos = target
    sfx(2,sfxMove.int)
    alpha = 0.0
  else:
    sfx(2,sfxBump.int)
    shake += 1.0

  objects.sort() do(a,b: Object) -> int:
    return a.pos.y - b.pos.y

method move(self: Ship, target: Vec2i) =
  if altitude > 0:
    return
  procCall move(Movable(self), target)

proc drop(self: var Level) =
  if cursorObject != nil:
    sfx(2,sfxDrop.int)
    for i in 0..10:
      particles.add(Particle(kind: dustParticle, pos: (cursorObject.pos * 16).vec2f + vec2f(8.0, 8.0), vel: rndVec(1.0), ttl: 0.25, maxttl: 0.25, above: false))
    if cursorObject of Movable and cursorObject.pos != Movable(cursorObject).originalPos:
      currentLevel.moves += 1
    cursorObject = nil

proc update(self: var Level, dt: float32) =

  if confirmAbort:
    if btnp(pcA):
      confirmAbort = false
      return
    elif btnp(pcY):
      currentLevel = loadLevel(levelId)
      return
    elif btnp(pcX):
      confirmAbort = false
      aborted = true
      timeout = 0.5
      sfx(-1,sfxAborted.int)
      return
    return

  if not (success or failed or aborted) and ship.altitude == 0:
    if btnp(pcLeft):
      moveBuffer.add(vec2i(-1,0))
    if btnp(pcRight):
      moveBuffer.add(vec2i(1,0))
    if btnp(pcUp):
      moveBuffer.add(vec2i(0,-1))
    if btnp(pcDown):
      moveBuffer.add(vec2i(0,1))
    if btnp(pcY):
      confirmAbort = true
      return

    if not scanning and btnp(pcA):
      moveBuffer.add(vec2i(0,0))

    if cursor == lastCursor and moveBuffer.len > 0:
      let move = moveBuffer.pop()

      if move.x == 0 and move.y == 0:
        if cursorObject == nil:
          # pick up
          let obj = objectAtPos(cursor)
          cursorObject = obj
          if cursorObject != nil:
            sfx(2,sfxGrab.int)
            if cursorObject of Movable:
              Movable(cursorObject).originalPos = obj.pos
        else:
          # drop
          drop()
      elif cursorObject != nil:
        cursorObject.move(cursor + move)
        cursor = cursorObject.pos
        alpha = 0.0
      else:
        sfx(2,sfxCursor.int)
        cursor += move
        cursor.x = clamp(cursor.x, 0, dimensions.x - 1)
        cursor.y = clamp(cursor.y, 0, dimensions.y - 1)
        alpha = 0.0

    if cursor != lastCursor:
      alpha += dt * 8.0
      if alpha >= 1.0:
        lastCursor = cursor

    if btnp(pcX) and cursorObject == nil:
      scanning = not scanning


  var hasTribbles = false
  for i in 0..<objects.len:
    if objects[i] of Alien and Alien(objects[i]).kind == Tribble:
      hasTribbles = true
    objects[i].update(dt)

  objects.keepIf() do(obj: Object) -> bool:
    return not obj.killed

  if hasTribbles:
    var stillHasTribbles = false
    for i in 0..<objects.len:
      if objects[i] of Alien:
        if Alien(objects[i]).kind == Tribble:
          stillHasTribbles = true
          break
        if Alien(objects[i]).kind == RedAlien and Alien(objects[i]).fed:
          stillHasTribbles = true
    if not stillHasTribbles:
      currentLevel.failed = true

  if tension <= 0 and not failed:
    if not success:
      drop()
      success = true
      sfx(-1,sfxSuccess.int)
    timeout -= dt
    if timeout < 0 and ship.altitude > 120:
      levelsCompleted[levelId] = moves
      updateConfigValue("Levels", $levelId, $moves)
      saveConfig()
      previousLevelId = levelId
      nico.run(menuInit, menuUpdate, menuDraw)
      return

  if aborted or failed:
    timeout -= dt
    if timeout < 0 and ship.altitude > 120:
      previousLevelId = levelId
      nico.run(menuInit, menuUpdate, menuDraw)
      return

  for p in particles.mitems:
    p.ttl -= dt
    if p.ttl < 0:
      particles.free(p)
    else:
      p.pos += p.vel
      p.vel *= 0.98

proc gameInit() =
  #setWindowTitle("smalltrek")
  #setTargetSize(128,128)
  #loadSpriteSheet("spritesheet.png")

  particles = initPool[Particle](512)

  #levelId = 1
  currentLevel = loadLevel(levelId)

  moveBuffer = newSeq[Vec2i]()

  stars = newSeq[Star]()
  for i in 0..100:
    stars.add(Star(pos: vec2f(rnd(128.0), rnd(128.0)), brightness: rnd(2.0)))

  time = 0.0

proc gameUpdate(dt: float32) =
  time += dt

  for star in mitems(stars):
    star.pos.x += cos(frame.float32 / 100.0) * dt
    star.pos.y += sin(frame.float32 / 110.0) * dt

  currentLevel.update(dt)


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
  frame+=1
  # background
  setCamera()
  cls()
  # draw stars
  for star in stars:
    setColor(if star.brightness <= 1.0: 1 else: 2)
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
    let targetTension = sad.float32 / (happy + sad).float32
    currentLevel.tension = lerp(currentLevel.tension, targetTension, 0.1)

    let tensionPercent = (currentLevel.tension * 100.0).int

    if tensionPercent <= 0:
      setColor(if frame mod 10 < 5: 11 else: 10)
      currentLevel.tension = 0
    elif tensionPercent <= 50:
      setColor(8)
    else:
      setColor(3)
    printShadowR("tension: $1%".format(tensionPercent), 126, 2 - currentLevel.ship.altitude.int)

  if currentLevel.tension <= 0 and not currentLevel.failed:
    setColor(2)
    printShadowC("Hostilities Ceased", 64, 100 + (currentLevel.ship.altitude * currentLevel.ship.altitude * 0.005).int)
    printShadowC("Moves: $1".format(currentLevel.moves), 64, 110 + (currentLevel.ship.altitude * currentLevel.ship.altitude * 0.005).int)

  elif currentLevel.failed:
    setColor(3)
    printShadowC("Mission Failed!", 64, 100)
    printShadowC("Species eradicated!", 64, 110)

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
          printShadowR("discontent", 126, 72)
      else:
        setColor(1)
        printShadowR("inanimate", 126, 72)


      var y = 82
      setColor(15)
      for line in scanobj.description.splitLines:
        printShadow(line, 2, y)
        y += 9

  setColor(13)
  if scanning:
    printShadowR("[X] end scan", 124, 120 + currentLevel.ship.altitude.int)
  elif not confirmAbort:
    if cursorObject == nil:
      printShadowR("[Z] grab [X] info [C] abort", 124, 120 + currentLevel.ship.altitude.int)
    else:
      printShadowR("[Z] drop          [C] abort", 124, 120 + currentLevel.ship.altitude.int)

type MenuShip = object
  pos: Vec2f
  vel: Vec2f
  angle: range[0..3]

const planetColors = [
  1,4,5,6,7,8,9,10,11,13,14,15
]

type Planet = object
  level: int
  pos: Vec2f
  z: float32
  size: int
  color: int

var menuShip: MenuShip
menuShip.pos = vec2f(64.0,64.0)

var quadrant: int = 0
var planets: seq[Planet]
var closestPlanet: ptr Planet
var warpTimer: float32
var quadrantTimer: float32
var quadrantInitialized = false

proc setQuadrant(quadrant: range[0..3], jump: bool = true) =
  srand(quadrant+1)
  stars = newSeq[Star]()
  for i in 0..100:
    stars.add(Star(pos: rndVec(128.0+64.0) + 64.0, brightness: rnd(2.0)))

  planets = newSeq[Planet]()
  for i in 0..7:
    planets.add(Planet(level: quadrant * 8 + i, pos: rndVec(72.0) + 64.0, z: rnd(1.0), size: 2+rnd(4), color: rnd(planetColors)))

  if quadrant == 0:
    planets.add(Planet(level: -1, pos: rndVec(72.0) + 64.0, z: rnd(1.0), size: 2+rnd(4), color: -1))

  planets.sort() do(a,b: Planet) -> int:
    if a.z < b.z:
      return -1
    return 1

  closestPlanet = nil

  quadrantTimer = 3.0

  if jump:
    warpTimer = 0.5
    sfx(-1,sfxHyperdrive.int)

proc dummyInit() =
  menuShip.vel = vec2f(0,0)
  warpTimer = 0.25

proc menuInit() =

  loadConfig()

  messages = newSeq[Message]()

  unlockedLevel = 0

  warpUnlocked = try: parseBool(getConfigValue("Unlocks","warp")) except: false

  if not quadrantInitialized:
    setQuadrant(0, false)
    quadrantInitialized = true

  for i in 0..<levelsCompleted.len:
    levelsCompleted[i] = try: parseInt(getConfigValue("Levels", $i)) except: 0
    if levelsCompleted[i] > 0:
      unlockedLevel += 1.25
  updateTrophies()

  for i in low(GameStats)..high(GameStats):
    gameStatsCollected[i] = try: parseInt(getConfigValue("Stats", $i)) except: 0
  updateTrophies()

  nextLevelId = 33
  for i in 0..<levelsCompleted.len:
    if levelsCompleted[i] == 0:
      nextLevelId = i
      break

  if nextLevelId == 0:
    setQuadrant(0, false)
    messages.add(Message(text: "Welcome to Smalltrek commander!\nThere's a distress beacon\ncoming from that planet.\nReports say Botarni are feuding\nwith Rotans over access to\nresources.\nHead over there and investigate.\n", step: 0, ttl: 5.0))
    messages.add(Message(text: "Use the arrow keys to navigate\nand [X] to land.", step: 0, ttl: 5.0))

  if nextLevelId == 1:
    messages.add(Message(text: "Congratulations on completing\nyour first assignment!\nThe quadrant is full of unrest.\nFollow the distress beacons and\nquell the tension.", step: 0, ttl: 5.0))

  if nextLevelId == 2:
    messages.add(Message(text: "We've had reports of Chrysornaks\nfighting with Botarni and\nRotans over access to crystals.\nGo see if you can sort it out.\n", step: 0, ttl: 5.0))

  if nextLevelId == 3:
    messages.add(Message(text: "Great work resolving that\nconflict.\nChryrsornaks seem to be\ncausing more issues in alpha\nquadrant.\nKeen an eye out.", step: 0, ttl: 5.0))

  if nextLevelId == 4:
    messages.add(Message(text: "We've had a report of a Partari\nconflict with the Botarni in\nthis sector.\nThey're quite the social\ncreatures.\nI hope you're using the\nINFO button! [X]", step: 0, ttl: 5.0))

  if nextLevelId == 5:
    messages.add(Message(text: "Alert! There's a 4 way\nconflict now that Partari\nare advancing in\nthe region.\nBut I trust you can solve\ntheir disputes.", step: 0, ttl: 5.0))

  if nextLevelId == 6:
    messages.add(Message(text: "We've had sightings of a strange\nnew species in this system.\nGo check it out and report!", step: 0, ttl: 5.0))

  if nextLevelId == 7:
    messages.add(Message(text: "Oh dear, these adorable things\nhave encountered the\nBotarni. I hope it'll\nwork out ok.", step: 0, ttl: 5.0))

  if nextLevelId == 8:
    if quadrant == 0:
      messages.add(Message(text: "Wonderful, you've managed to\nsolve all the disputes in\nthis quadrant. But we're\ngetting reports from\nBeta quadrant now.", step: 0, ttl: 5.0))
      messages.add(Message(text: "Engage your warp drive\nand get over there\nASAP! Fly towards the beacon\nas fast as you can.", step: 0, ttl: 5.0))
      messages.add(Message(text: "Remember to disengage your\nwarp drive once you\narrive. Otherwise you might\nend up in Delta\nquadrant.", step: 0, ttl: 5.0))

  if nextLevelId == 9:
    messages.add(Message(text: "Looks like these cute\ncritters are causing\na ruckus over Beta quadrant\ntoo.", step: 0, ttl: 5.0))
    messages.add(Message(text: "Chrysornaks really seem\nto hate them though.\nI wonder why...", step: 0, ttl: 5.0))
    messages.add(Message(text: "How could anyone\nhate something so CUTE?", step: 0, ttl: 5.0))

  if nextLevelId == 10:
    messages.add(Message(text: "Botarni in this quadrant\nhave reported their\nplants being eaten by Omnatrus.\nGo see what you can do.", step: 0, ttl: 5.0))

  if nextLevelId == 11:
    messages.add(Message(text: "We've had a report of\ncreatures snatching Cuwudles.\nThey don't seem to be doing\nany harm. They just\nreally love them.", step: 0, ttl: 5.0))

  if nextLevelId == 12:
    messages.add(Message(text: "Some new friends have\nmoved in from another quadrant.\nThey claim they don't have\nenough space.\nSee if you can help\nthe Sordax out.", step: 0, ttl: 5.0))

  if nextLevelId == 13:
    messages.add(Message(text: "Hopefulyl these new\nSordax will get along\nwith the Cuwudles\nbetter than the Chrysornaks do.", step: 0, ttl: 5.0))

  if nextLevelId == 14:
    messages.add(Message(text: "Sordax, Cuwudles, Rotans\nand Chrysornaks.\nThis will be a challenge!", step: 0, ttl: 5.0))

  if nextLevelId == 15:
    messages.add(Message(text: "Ack! Botarni and Omnatrus!\nNot a good match.\nLook after those plants.\nAnd those Cuwudles of course!", step: 0, ttl: 5.0))

  if nextLevelId == 16:
    if quadrant != 2:
      messages.add(Message(text: "Lots of new faces in the\nBeta quadrant. But they all\nseem to be settled now.\nHead on over to the\nDelta quadrant.", step: 0, ttl: 5.0))
    messages.add(Message(text: "Reports of Mookarin facing\noff with Chrysornaks.\nPresumably something to do\nwith Cuwudles.", step: 0, ttl: 5.0))

  if nextLevelId == 17:
    messages.add(Message(text: "Things are getting messy!\nYou're on your own here.\nGood luck Commander!", step: 0, ttl: 5.0))

  if nextLevelId == 19:
    messages.add(Message(text: "What!?!", step: 0, ttl: 5.0))
    messages.add(Message(text: "What are Cardaks doing in the\nDelta quadrant?!", step: 0, ttl: 5.0))
    messages.add(Message(text: "Be super careful!\nLook after those Cuwudles!\nI love them so!", step: 0, ttl: 5.0))

  if nextLevelId == 20:
    messages.add(Message(text: "Cardaks are only happy\nwhen they're formed up\ncorrectly.\nMake sure they're spaced out\nand aligned with another\nsoldier!", step: 0, ttl: 5.0))

  if nextLevelId == 23:
    messages.add(Message(text: "I used to think there\ncould never be too many\nCuwudles...\nMaybe I need to reconsider.", step: 0, ttl: 5.0))
    messages.add(Message(text: "Cardaks sure have a way\nwith them....", step: 0, ttl: 5.0))

  if nextLevelId == 24:
    if quadrant != 3:
      messages.add(Message(text: "Delta quadrant is clear!\nLet's head to the Gamma\nquadrant!", step: 0, ttl: 5.0))

  if nextLevelId == 33:
    messages.add(Message(text: "Congratulations! You've\nmade the whole world a\nhappy place!\nEven if it is a small world!", step: 0, ttl: 5.0))
    messages.add(Message(text: "Thanks for playing commander!", step: 0, ttl: 5.0))
    messages.add(Message(text: "This game was made by Impbox\nFor Ludum Dare 38:\n'A Small World'.", step: 0, ttl: 5.0))
    messages.add(Message(text: "It was made entirely\nin 48 hours.", step: 0, ttl: 5.0))
    messages.add(Message(text: "Now it's time to have\na nap!", step: 0, ttl: 5.0))

  menuShip.vel = vec2f(0,0)

  if not warpUnlocked and unlockedLevel >= 8:
    messages.add(Message(text: "Report to StarBase LD38\ncommander!", step: 0, ttl: 5.0))

  # find prev level's planet
  for planet in planets:
    if planet.level == previousLevelId:
      menuShip.pos = planet.pos
      break

var confirmQuit: bool

proc menuUpdate(dt: float32) =

  if confirmQuit:
    if btnp(pcBack):
      shutdown()
      return
    if btnp(pcA):
      confirmQuit = false
      return
    return
  elif btnp(pcBack):
    confirmQuit = true
    return

  let boost = warpUnlocked and btn(pcA)
  let move = if boost: 0.05 else: 0.01

  if btn(pcLeft):
    menuShip.angle = 0
    menuShip.vel.x -= move
  if btn(pcRight):
    menuShip.angle = 2
    menuShip.vel.x += move
  if btn(pcUp):
    menuShip.angle = 1
    menuShip.vel.y -= move
  if btn(pcDown):
    menuShip.angle = 3
    menuShip.vel.y += move

  menuShip.pos += menuShip.vel
  menuShip.vel *= 0.99

  if menuShip.pos.x > 128.0:
    menuShip.pos.x -= 128.0

    if boost and menuShip.vel.x > 2.0:
      quadrant += 1
      if quadrant > 3:
        quadrant = 0
      setQuadrant(quadrant)

  if menuShip.pos.x < 0.0:
    menuShip.pos.x += 128.0

    if boost and menuShip.vel.x < -2.0:
      quadrant -= 1
      if quadrant < 0:
        quadrant = 3
      setQuadrant(quadrant)


  if quadrant > nextLevelId div 8:
    shake += 0.5

  #menuShip.pos.x = menuShip.pos.x mod 128.0
  if menuShip.pos.y < 0.0:
    menuShip.pos.y += 128.0
  menuShip.pos.y = menuShip.pos.y mod 128.0

  for star in mitems(stars):
    star.pos.x += cos(frame.float32 / 100.0) * dt + -menuShip.vel.x * 0.1 * (star.brightness + 1.0)
    star.pos.y += sin(frame.float32 / 110.0) * dt + -menuShip.vel.y * 0.1 * (star.brightness + 1.0)

    star.pos.x = star.pos.x mod 256.0
    star.pos.y = star.pos.y mod 256.0

  let oldClosestPlanet = closestPlanet
  closestPlanet = nil
  var nearestDistance: float32 = Inf
  for planet in mitems(planets):
    planet.pos.x += cos(frame.float32 / 100.0) * dt + -menuShip.vel.x * 0.1 * ((planet.z).float32 * 10.0) + 128.0
    planet.pos.y += sin(frame.float32 / 110.0) * dt + -menuShip.vel.y * 0.1 * ((planet.z).float32 * 10.0) + 128.0

    planet.pos.x = planet.pos.x mod 128.0
    planet.pos.y = planet.pos.y mod 128.0

    if planet.level <= unlockedLevel.int:
      let dist = (planet.pos - menuShip.pos).length
      if dist < nearestDistance:
        closestPlanet = planet.addr
        nearestDistance = dist
        #and (planet.pos - menuShip.pos).length < (planet.size + 10).float32:

  if messages.len > 0:
    alias m, messages[messages.low]
    if btn(pcA) or btn(pcX):
      if m.step < m.text.len:
        m.step += 1
        if not m.text[m.step-1].isSpaceAscii:
          sfx(-1,sfxCursor.int)
        else:
          m.step += 1
    if btnp(pcA) or btnp(pcX):
      if m.step >= m.text.len:
        m.ttl = 0
        sfx(-1,sfxHeart.int)
  elif closestPlanet != nil and (closestPlanet.pos - menuShip.pos).length < 10.0 and menuShip.vel.length < 0.5:
    if btnp(pcX):
      if closestPlanet.level >= 0:
        levelId = closestPlanet.level
        # start level
        nico.run(gameInit, gameUpdate, gameDraw)
      else:
        # must be starbase
        if not warpUnlocked and unlockedLevel >= 8:
          warpUnlocked = true
          messages.add(Message(text: "Commander, we've fitted your\nship with a warp drive.\nYou can now travel to other\nquadrants.\nUse [Z] to engage the\nwarp drive. Fly fast\ntowards the edges of the system\nto warp.", step: 0, ttl: 5.0))
          updateConfigValue("Unlocks","warp","true")
          saveConfig()
        else:
          var happyPlanets = 0
          var unhappyPlanets = 0
          for planet in planets:
            if planet.level >= 0:
              if levelsCompleted[planet.level] > 0:
                happyPlanets += 1
              else:
                unhappyPlanets += 1
          let unrest = ((unhappyPlanets.float32 / (happyPlanets + unhappyPlanets).float32) * 100.0).int
          if unrest == 0:
            messages.add(Message(text: "Alpha quadrant is secure\nthanks to you.\nHead to the Beta Quadrant!", step: 0, ttl: 5.0))
          else:
            messages.add(Message(text: "Thank you commander!\nUnrest in this quadrant\nis now at $1 percent.".format(unrest), step: 0, ttl: 5.0))

    # apply gravity
    let diff = closestPlanet.pos - menuShip.pos
    let dir = diff.normalized
    let dist = diff.length
    menuShip.vel += dir * sqrt(dist) * 0.001

  if warpTimer > 0.0:
    warpTimer -= dt


proc menuDraw() =
  frame+=1
  cls()

  if confirmQuit:
    setColor(3)
    printShadowC("QUIT?", 64, 60)
    printShadowC("[ESC] YES [Z] NO", 64, 70)
    return

  if warpTimer > 0:
    setColor(2)
    rectfill(0,0,128,128)

  if shake > 0.5 or warpTimer > 0:
    shake -= 0.5
    setCamera(rnd(2)-1,rnd(2)-1)
  else:
    setCamera(0,0)

  for star in stars:
    setColor(if star.brightness < 1.0: 1 else: 2)
    pset(star.pos.x.int, star.pos.y.int)

  # sun
  let sunsize = case quadrant:
    of 0: 16
    of 1: 12
    of 2: 20
    of 3: 24
    else:
      0
  setColor(case quadrant:
  of 0: 8
  of 1: 7
  of 2: 14
  of 3: 3
  else: 0)
  circfill(64,64,sunsize)
  setColor(2)
  circfill(64,64,(sunsize.float32 * 0.75).int + (sin(frame.float32 / 100.0) * 3.0).int)

  # draw planets
  for planet in mitems(planets):
    if planet.level == -1:
      spr(212+16+4, planet.pos.x.int - 8, planet.pos.y.int - 8, 2, 2)
    else:
      setColor(0)
      circfill(planet.pos.x.int, planet.pos.y.int, planet.size+1)
      #setColor(if levelsCompleted[planet.level] > 0: 13 elif planet.level <= unlockedLevel.int: 5 else: 12)
      setColor(if planet.level <= unlockedLevel.int: planet.color else: 12)
      circfill(planet.pos.x.int, planet.pos.y.int, planet.size)

    if planet.level == nextLevelId:
      setColor(3)
      circ(planet.pos.x.int, planet.pos.y.int, planet.size + 1 + ((frame.float32 mod 100.0)/100.0) * 10)


  if closestPlanet != nil and (closestPlanet.pos - menuShip.pos).length < 10.0:
    let planet = closestPlanet[]
    setColor(14)
    circ(planet.pos.x.int, planet.pos.y.int, planet.size + 5 - ((frame.float32 mod 30.0)/30.0) * 5)

  # beacons from other quadrants
  if nextLevelId >= (quadrant + 1) * 8:
    setColor(3)
    circ(128+32, 64, ((frame.float32 mod 100.0)/100.0) * 64)
  elif nextLevelId < quadrant * 8:
    setColor(3)
    circ(-32, 64, ((frame.float32 mod 100.0)/100.0) * 64)


  # draw ship

  palt(5,true)
  palt(0,false)

  let boost = warpUnlocked and btn(pcA)
  let engineSize = if boost: 5 + rnd(3) else: 2 + rnd(2)

  if menuShip.angle == 3:
    setColor(14)
    circfill(menuShip.pos.x.int - rnd(2), menuShip.pos.y.int - 3, engineSize)
    setColor(2)
    circfill(menuShip.pos.x.int - rnd(2), menuShip.pos.y.int - 3, engineSize div 2)
  elif menuShip.angle == 0:
    setColor(14)
    circfill(menuShip.pos.x.int + 4, menuShip.pos.y.int, engineSize)
    setColor(2)
    circfill(menuShip.pos.x.int + 4, menuShip.pos.y.int, engineSize div 2)
  elif menuShip.angle == 2:
    setColor(14)
    circfill(menuShip.pos.x.int - 4, menuShip.pos.y.int, engineSize)
    setColor(2)
    circfill(menuShip.pos.x.int - 4, menuShip.pos.y.int, engineSize div 2)



  if frame mod 4 < 2:
    pal(14,15)
  spr(case menuShip.angle:
    of 0: 215
    of 1: 212
    of 2: 213
    of 3: 214, menuShip.pos.x.int - 4, menuShip.pos.y.int - 4)
  pal()

  if menuShip.angle == 1:
    setColor(14)
    circfill(menuShip.pos.x.int - rnd(2), menuShip.pos.y.int + 4, engineSize)
    setColor(2)
    circfill(menuShip.pos.x.int - rnd(2), menuShip.pos.y.int + 4, engineSize div 2)

  if messages.len > 0:
    alias m, messages[messages.low]

    if frame mod 4 == 0 and m.step < m.text.len:
      m.step += 1
      if not m.text[m.step-1].isSpaceAscii:
        sfx(-1,sfxCursor.int)
      else:
        m.step += 1

    if m.step >= m.text.high:
      m.ttl -= timeStep
    setColor(8)
    let text = m.text[0..min(m.text.high,m.step)]
    var yv = 2
    for line in text.splitLines:
      printShadow(line, 2, yv)
      yv += 10

  messages.keepIf() do(a: Message) -> bool:
    a.ttl > 0

  if quadrantTimer > 0.0 and messages.len == 0:
    setColor(2)
    quadrantTimer -= timeStep
    case quadrant:
    of 0:
      printShadowC("alpha quadrant", 64, 2)
    of 1:
      printShadowC("beta quadrant", 64, 2)
    of 2:
      printShadowC("delta quadrant", 64, 2)
    of 3:
      printShadowC("gamma quadrant", 64, 2)
    else:
      discard

  if warpUnlocked and abs(menuShip.vel.x) > 0.5:
    setColor(if frame mod 30 < 15: 2 else: 14)
    printShadowC("hold <- [Z] -> to WARP", 64, 121)

  if closestPlanet != nil and (closestPlanet.pos - menuShip.pos).length < 10.0:
    if closestPlanet.level == -1:
      setColor(2)
      printShadowC("StarBase LD38", 64, 90)
      if menuShip.vel.length < 0.25:
        setColor(14)
        printShadowC("press [X] to report in", 64, 100)
    else:
      setColor(if closestPlanet.level == nextLevelId: 3 else: 2)
      if levelsCompleted[closestPlanet.level] > 0:
        printShadowC("replay episode " & $(closestPlanet.level + 1), 64, 90)
      else:
        printShadowC("episode " & $(closestPlanet.level + 1), 64, 90)
      if menuShip.vel.length < 0.25:
        setColor(14)
        printShadowC("press [X] to land", 64, 100)

  if quadrant > nextLevelId div 8 or warpTimer > 0.0:
    for i in 0..rnd(40):
      glitch(0,0,screenWidth, screenHeight)


proc introInit() =
  setWindowTitle("smalltrek")
  #setTargetSize(128,128)
  #setScreenSize(128*4,128*4)
  setPalette(loadPaletteFromGPL("palette.gpl"))
  loadSpriteSheet(0,"spritesheet.png")

  loadFont(0, "font.png")
  setFont(0)

  loadSfx(sfxDrop.int, "sfx/smalltrek_0.ogg")
  loadSfx(sfxMove.int, "sfx/smalltrek_1.ogg")
  loadSfx(sfxGrab.int, "sfx/smalltrek_2.ogg")
  loadSfx(sfxLand.int, "sfx/smalltrek_3.ogg")
  loadSfx(sfxTakeoff.int, "sfx/smalltrek_4.ogg")
  loadSfx(sfxHeart.int, "sfx/smalltrek_5.ogg")
  loadSfx(sfxCross.int, "sfx/smalltrek_6.ogg")
  loadSfx(sfxSuccess.int, "sfx/smalltrek_7.ogg")
  loadSfx(sfxHyperdrive.int, "sfx/smalltrek_8.ogg")
  loadSfx(sfxFailure.int, "sfx/smalltrek_9.ogg")
  loadSfx(sfxBump.int, "sfx/smalltrek_10.ogg")
  loadSfx(sfxEat.int, "sfx/smalltrek_11.ogg")
  loadSfx(sfxCursor.int, "sfx/smalltrek_12.ogg")
  loadSfx(sfxAborted.int, "sfx/smalltrek_13.ogg")

  loadMusic(0, "music/overworld.ogg")
  loadMusic(1, "music/underworld.ogg")

  musicVol(64)

  frame = 0


proc introUpdate(dt: float32) =
  if btnp(pcStart) or btnp(pcA):
    if frame < 300:
      frame = 300
    else:
      nico.run(menuInit, menuUpdate, menuDraw)

var drippiness = 1000

proc introDraw() =
  frame+=1
  if frame < 300:
    if frame == 60:
      cls()
      sfx(0,sfxDrop.int)
      sspr(88,104, 24,24, 64 - 12, 64 - 12, 24, 24)
    elif frame == 120:
      sfx(0,sfxDrop.int)
      setColor(2)
      printShadowC("ld38", 64, 92)
    elif drippiness > 0:
      # do drippy effect
      for i in 0..<drippiness:
        let x = rnd(128)
        let y = rnd(128)
        let c = pget(x,y)
        if c == 14 or c == 13:
          if pget(x,y+1) != 2:
            pset(x,y+1,c)
            drippiness -= 1

  else:
    cls()

    # logo
    palt(0,true)
    sspr(0,88,83,8, 64 - 83 div 2, 60, 83, 8)

    if frame >= 400:
      setColor(2)
      printShadowC("the ludum frontier", 64, 90)

    if frame == 600:
      nico.run(menuInit, menuUpdate, menuDraw)

nico.init("impbox","smalltrek")
gamerzilla.start(0, $sdl.getPrefPath("impbox","smalltrek"))
gameID = int gamerzilla.setGameFromFile("assets/gamerzilla/smalltrek.game", "./assets/")
nico.createWindow("smalltrek", 128,128,4,false)
nico.run(introInit, introUpdate, introDraw)
