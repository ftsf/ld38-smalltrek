import nico/vec
import nico
import math
import strutils

const metresPerPixel* = 1.0/8.0

type TextAlign* = enum
  taLeft
  taRight
  taCenter

type
  AABB* = tuple[min: Vec2f, max: Vec2f]
  Polygon* = seq[Vec2f]
  Triangle* = array[3, Vec2f]
  Quad* = array[4, Vec2f]
  Line* = array[2, Vec2f]
  Rect* = tuple[x,y,w,h: int]

proc isZero*(v: Vec2f): bool =
  return v.x == 0 and v.y == 0

proc rndVec*(mag: float32): Vec2f =
  let hm = mag/2
  vec2f(
    rnd(mag)-hm,
    rnd(mag)-hm
  )

proc line*(line: Line) =
  let a = line[0]
  let b = line[1]
  line(a.x.int,a.y.int,b.x.int,b.y.int)

proc pset*(v: Vec2f) =
  pset(v.x,v.y)

proc setCamera*(v: Vec2f) =
  setCamera(v.x, v.y)

proc poly*(verts: Polygon | Triangle | Quad) =
  if verts.len == 1:
    pset(verts[0])
  elif verts.len == 2:
    line(verts[0],verts[1])
  else:
    for i in 0..verts.high:
      line(verts[i],verts[(i+1) mod verts.len])

proc poly*(pos: Vec2f, sides: int, radius: float32) =
  let angle = PI / sides.float32
  for i in 0..<sides:
    let j = i.float32
    line(
      pos.x + cos(angle*(j-1.0))*radius, pos.y + sin(angle*(j-1.0))*radius,
      pos.x + cos(angle*j)*radius, pos.y + sin(angle*j)*radius
    )

proc polyfill*(pos: Vec2f, sides: int, radius: float32) =
  let angle = PI / sides.float32
  for i in 0..<sides:
    let j = i.float32
    trifill(
      pos.x, pos.y,
      pos.x + cos(angle*(j-1))*radius, pos.y + sin(angle*(j-1))*radius,
      pos.x + cos(angle*j)*radius, pos.y + sin(angle*j)*radius
    )

proc rotatePoint*(p: Vec2f, angle: float32, o = vec2f(0,0)): Vec2f =
  vec2f(
    cos(angle) * (p.x - o.x) - sin(angle) * (p.y - o.y) + o.x,
    sin(angle) * (p.x - o.x) + cos(angle) * (p.y - o.y) + o.y
  )

const charVerts = [
  @[ vec2f(0, 5), vec2f(2, 0), vec2f(3, 5), vec2f(1, 4) ], # a
  @[ vec2f(0, 0), vec2f(2, 1), vec2f(0, 2), vec2f(2, 4), vec2f(0, 5), vec2f(0, 0) ], # b
  @[ vec2f(2, 0), vec2f(0, 1), vec2f(0, 4), vec2f(2, 5) ], # c
]

proc line*(a,b: Vec2f) =
  line(a.x, a.y, b.x, b.y)

proc printChar*(c: char, pos: Vec2f, angle: float32) =
  var last = pos + charVerts[c.int][0]
  for i in 1..<charVerts[c.int].len:
    let p = pos + rotatePoint(charVerts[c.int][i], angle)
    line(last, p)
    last = p

proc printVec*(text: string, pos: Vec2f, angle: float32) =
  var x = pos.x
  var y = pos.y
  for c in text:
    printChar(c, vec2f(x, y), angle)
    x += cos(angle)*4.0
    y += sin(angle)*4.0


#proc normalized*(v: Vec2f): Vec2f =
#  let m = v.length
#  if m == 0:
#    return v
#  return vec2f(v.x/m, v.y/m)

#proc perpendicular*(v: Vec2f): Vec2f =
#  return vec2f(-v.y, v.x)

proc rotate*(v: var Vec2f, angle: float32) =
  v.x = v.x * cos(angle) - v.y * sin(angle)
  v.y = v.x * sin(angle) - v.y * cos(angle)

proc rotated*(v: Vec2f, angle: float32): Vec2f =
  var v = v
  v.rotate(angle)
  return v

proc invLerp*[T](a, b: T, t: T): float32 {.inline.} =
  assert(b!=a)
  return (t - a) / (b - a)

proc trifill*(tri: Triangle | Polygon) =
  trifill(tri[0],tri[1],tri[2])

proc circfill*(p: Vec2f, r: float32) =
  circfill(p.x,p.y,r)

proc rotatedPoly*(offset: Vec2f, verts: openArray[Vec2f], angle: float32, origin = vec2f(0,0)): Polygon =
  result = newSeq[Vec2f](verts.len())
  for i in 0..verts.high:
    result[i] = offset + rotatePoint(verts[i],angle,origin)

proc rotatedPoly*(offset: Vec2f, verts: openArray[Vec2f], angle: float32, origin = vec2f(0,0), scale: float32): Polygon =
  result = newSeq[Vec2f](verts.len())
  for i in 0..verts.high:
    result[i] = offset + rotatePoint(verts[i],angle,origin) * scale

proc pointInTri*(px,py,ax,ay,bx,by,cx,cy: Pint): bool =
  let asX = px - ax
  let asY = py - ay

  let sAB = (bx - ax) * asY - (by-ay) * asX > 0

  if (cx-ax) * asY - (cy - ay) * asX > 0 == sAB: return false

  if (cx-bx) * (py-by) - (cy-by) * (px-bx) > 0 != sAB: return false

  return true

proc pointInPoly*(p: Vec2f, poly: Polygon | Triangle | Quad): bool =
  let px = p.x
  let py = p.y
  let nvert = poly.len()

  var c = false
  var j = nvert-1
  for i in 0..nvert-1:
    j = (i+1) %% nvert
    if (poly[i].y > py) != (poly[j].y > py) and px < (poly[j].x - poly[i].x) * (py - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x:
      c = not c
  return c

proc rect*(aabb: AABB) =
  rect(aabb.min.x.int, aabb.min.y.int, aabb.max.x.int, aabb.max.y.int)

proc rectfill*(aabb: AABB) =
  rectfill(aabb.min.x.int, aabb.min.y.int, aabb.max.x.int, aabb.max.y.int)

proc getAABB*(point: Vec2f, size: float32): AABB =
  result.min.x = point.x - size
  result.min.y = point.y - size
  result.max.x = point.x + size
  result.max.y = point.y + size

proc getAABB*(poly: Triangle | Polygon): AABB =
  var aabb: AABB
  aabb.min.x = Inf
  aabb.min.y = Inf
  aabb.max.x = NegInf
  aabb.max.y = NegInf
  for v in poly:
    aabb.min.x = min(aabb.min.x, v.x)
    aabb.min.y = min(aabb.min.y, v.y)
    aabb.max.x = max(aabb.max.x, v.x)
    aabb.max.y = max(aabb.max.y, v.y)
  return aabb

proc getAABB*(a, b: Vec2f): AABB =
  result.min.x = min(a.x,b.x)
  result.min.y = min(a.y,b.y)
  result.max.x = max(a.x,b.x)
  result.max.y = max(a.y,b.y)

proc getAABB*(l: Line): AABB =
  return getAABB(l[0], l[1])

proc union*(a,b: AABB): AABB =
  result.min.x = min(a.min.x, b.min.x)
  result.max.x = max(a.max.x, b.max.x)
  result.min.y = min(a.min.y, b.min.y)
  result.max.y = max(a.max.y, b.max.y)

proc expandAABB*(aabb: AABB, vel: Vec2f): AABB =
  result.min.x = aabb.min.x - abs(vel.x)
  result.max.x = aabb.max.x + abs(vel.x)
  result.min.y = aabb.min.y - abs(vel.y)
  result.max.y = aabb.max.y + abs(vel.y)

proc expandUniAABB*(aabb: AABB, vel: Vec2f): AABB =
  result.min.x = min(aabb.min.x, aabb.min.x + vel.x)
  result.max.x = max(aabb.max.x, aabb.max.x + vel.x)
  result.min.y = min(aabb.min.y, aabb.min.y + vel.y)
  result.max.y = max(aabb.max.y, aabb.max.y + vel.y)

proc shuffle*[T](x: var seq[T]) =
  for i in countdown(x.high, 0):
    let j = rnd(i+1)
    swap(x[i], x[j])

proc rnd*[T](x: seq[T]): T =
  let r = rnd(x.len)
  return x[r]

proc intersects*(a, b: AABB): bool =
  return not ( a.min.x > b.max.x or a.min.y > b.max.y or a.max.x < b.min.x or a.max.y < b.min.y )

proc sideOfLine*(v1, v2, p: Vec2f): float32 =
  let px = p.x
  let py = p.y
  return (px - v1.x) * (v2.y - v1.y) - (py - v1.y) * (v2.x - v1.x)

type
  ABC = tuple[a,b,c: float32]

proc lineToABC(line: Line): ABC =
  let x1 = line[0].x
  let x2 = line[1].x
  let y1 = line[0].y
  let y2 = line[1].y

  let A = y2 - y1
  let B = x1 - x2
  let C = A*x1 + B*y1

  return (A, B, C)

proc lineLineIntersection*(l1, l2: Line): (bool, Vec2f) =
  let L1 = lineToABC(l1)
  let L2 = lineToABC(l2)

  let det = L1.a*L2.b - L2.a*L1.b
  if det == 0:
    # parallel
    return (false,vec2f(0,0))
  else:
    let x = (L2.b*L1.c - L1.b*L2.c)/det
    let y = (L1.a*L2.c - L2.a*L1.c)/det
    # check if x,y is on line
    return (true,vec2f(x,y))

proc lineSegmentIntersection*(l1, l2: Line): (bool,Vec2f) =
  let ret = lineLineIntersection(l1,l2)
  let p = ret[1]
  let collide = min(l1[0].x,l1[1].x) <= p.x and p.x <= max(l1[0].x,l1[1].x) and
    min(l1[0].y,l1[1].y) <= p.y and p.y <= max(l1[0].y,l1[1].y) and
    min(l2[0].x,l2[1].x) <= p.x and p.x <= max(l2[0].x,l2[1].x) and
    min(l2[0].y,l2[1].y) <= p.y and p.y <= max(l2[0].y,l2[1].y)
  if collide:
    return (collide, p)
  else:
    return (collide, vec2f(0,0))

proc rayCastLineSegment*(a,b: Vec2f, o: Vec2f, d: Vec2f): float32 =
  if a == b:
    return -1
  if d.x == 0 and d.y == 0:
    return -1
  # casts from O along D finds intersection distance with line AB, negative if no intersection
  # https://rootllama.wordpress.com/2014/06/20/ray-line-segment-intersection-test-in-2d/
  let v1 = o - a
  let v2 = b - a
  let v3 = d.perpendicular

  let dot = v2.dot(v3)
  if abs(dot) < 0.0000001:
    return -1

  let t1 = v2.cross(v1) / dot
  let t2 = v1.dot(v3) / dot

  if t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1:
    return t1
  return -1

proc printShadowC*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(0)
  printc(text, x-scale, y, scale)
  printc(text, x+scale, y, scale)
  printc(text, x, y-scale, scale)
  printc(text, x, y+scale, scale)
  printc(text, x+scale, y+scale, scale)
  printc(text, x-scale, y-scale, scale)
  printc(text, x+scale, y-scale, scale)
  printc(text, x-scale, y+scale, scale)
  setColor(oldColor)
  printc(text, x, y, scale)

proc printShadowR*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(0)
  printr(text, x-scale, y, scale)
  printr(text, x+scale, y, scale)
  printr(text, x, y-scale, scale)
  printr(text, x, y+scale, scale)
  printr(text, x+scale, y+scale, scale)
  printr(text, x-scale, y-scale, scale)
  printr(text, x+scale, y-scale, scale)
  printr(text, x-scale, y+scale, scale)
  setColor(oldColor)
  printr(text, x, y, scale)

proc printShadow*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(0)
  print(text, x-scale, y, scale)
  print(text, x+scale, y, scale)
  print(text, x, y-scale, scale)
  print(text, x, y+scale, scale)
  print(text, x+scale, y+scale, scale)
  print(text, x-scale, y-scale, scale)
  print(text, x+scale, y-scale, scale)
  print(text, x-scale, y+scale, scale)
  setColor(oldColor)
  print(text, x, y, scale)

proc pointInAABB*(p: Vec2f, a: AABB): bool =
  return  p.x > a.min.x and p.x < a.max.x and
          p.y > a.min.y and p.y < a.max.y

proc pointInRect*(p: Vec2f, r: Rect): bool =
  return  p.x > r.x and p.x < r.x + r.w - 1 and
          p.y > r.y and p.y < r.y + r.h - 1

proc pointInTile*(p: Vec2f, x, y: int): bool =
  return pointInAABB(p, (vec2f(x.float32*8.0,y.float32*8.0),vec2f(x.float32*8+7,y.float32*8+7)))

proc floatToTimeStr*(time: Pfloat, forceSign: bool = false): string =
  let sign = if time < 0: "-" elif forceSign: "+" else: ""
  let time = abs(time)
  let minutes = int(time/60)
  let seconds = int(time - float32(minutes*60))
  let ms = int(time mod 1.0 * 60)
  return "$1$2:$3.$4".format(sign,($minutes).align(1,'0'),($seconds).align(2,'0'),($ms).align(2,'0'))

proc bezierQuadratic*(s, e, cp: Vec2f, mu: float32): Vec2f =
  let mu2 = mu * mu
  let mum1 = 1 - mu
  let mum12 = mum1 * mum1

  return vec2f(
    s.x * mum12 + 2 * cp.x * mum1 * mu + e.x * mu2,
    s.y * mum12 + 2 * cp.y * mum1 * mu + e.y * mu2
  )

proc bezierQuadraticLength*(s, e, cp: Vec2f, steps: int): float32 =
  var l = 0.0
  var v = s
  var next: Vec2f
  for i in 0..steps-1:
    next = bezierQuadratic(s,e,cp,float32(i)/float32(steps))
    if i > 0:
      l += (next - v).length
      v = next
  return l

proc bezierCubic*(p1, p2, p3, p4: Vec2f, mu: float32): Vec2f =
  let mum1 = 1 - mu
  let mum13 = mum1 * mum1 * mum1
  let mu3 = mu * mu * mu

  return vec2f(
    p1.x * mum13 + 3*mu*mum1*mum1*p2.x + 3*mu*mu*mum1*p3.x + mu3*p4.x,
    p1.y * mum13 + 3*mu*mum1*mum1*p2.y + 3*mu*mu*mum1*p3.y + mu3*p4.y,
  )

proc bezierCubicLength*(s, e, cp1, cp2: Vec2f, steps: int): float32 =
  var l = 0.0
  var v = s
  var next: Vec2f
  for i in 0..steps-1:
    next = bezierCubic(s,e,cp1,cp2,float32(i)/float32(steps))
    if i > 0:
      l += (next - v).length
      v = next
  return l

proc closestPointOnLine*(line: Line, p: Vec2f): Vec2f =
  let l2 = (line[0] - line[1]).length2
  if l2 == 0.0:
    return line[0]
  let t = max(0.0, min(1.0, dot(p-line[0], line[1] - line[0]) / l2))
  return line[0] + (line[1] - line[0]) * t

proc lineSegDistanceSqr*(line: Line, p: Vec2f): float32 =
  let proj = closestPointOnLine(line, p)
  return (p - proj).length2

proc lineSegDistance*(line: Line, p: Vec2f): float32 =
  return sqrt(lineSegDistanceSqr(line, p))

template alias*(a,b: untyped): untyped =
  template a: untyped = b

proc `%%/`*[T](x,m: T): T =
  return (x mod m + m) mod m

proc modDiff*[T](a,b,m: T): T  =
  let a = a %%/ m
  let b = b %%/ m
  return min(abs(a-b), m - abs(a-b))

proc modSign[T](a,n: T): T =
  return (a mod n + n) mod n

proc ordinal*(x: int): string =
  if x == 10:
    return "11th"
  elif x == 11:
    return "12th"
  elif x == 12:
    return "13th"
  elif x mod 10 == 0:
    return $(x+1) & "st"
  elif x mod 10 == 1:
    return $(x+1) & "nd"
  elif x mod 10 == 2:
    return $(x+1) & "rd"
  else:
    return $(x+1) & "th"

proc wrap*[T](x,min,max: T): T =
  if x < min:
    return max
  if x > max:
    return min
  return x

proc roundTo*[T](x,y: T): T =
  return floor(x.float32 / y.float32).T * y

proc wrapAngle*(angle: float32): float32 =
  var angle = angle
  while angle > PI:
    angle -= TAU
  while angle < -PI:
    angle += TAU
  return angle

proc wrapAngleTAU*(angle: float32): float32 =
  var angle = angle
  while angle > TAU:
    angle -= TAU
  while angle < 0.0:
    angle += TAU
  return angle

proc richPrintLength*(text: string): int =
  var i = 0
  while i < text.len:
    let c = text[i]
    if i + 2 < text.high and c == '<' and (text[i+2] == '>' or text[i+3] == '>'):
      i += (if text[i+2] == '>': 3 else: 4)
      continue
    i += 1
    result += glyphWidth(c)

proc richPrint*(text: string, x,y: int, align: TextAlign = taLeft, shadow: bool = false, step = -1) =
  ## prints but handles color codes <0>black <8>red etc <-> to return to normal

  let tlen = richPrintLength(text)

  var x = x
  let startColor = getColor()
  var i = 0
  var j = 0
  while i < text.len:
    if step != -1 and j >= step:
      break

    let c = text[i]
    if i + 2 < text.high and c == '<' and (text[i+2] == '>' or text[i+3] == '>'):
      let colStr = if text[i+2] == '>': text[i+1..i+1] else: text[i+1..i+2]
      let col = try: parseInt(colStr).ColorId except ValueError: startColor
      setColor(col)
      i += (if text[i+2] == '>': 3 else: 4)
      continue
    if shadow:
      printShadow($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
    else:
      print($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
    x += glyphWidth(c)
    i += 1
    if c != ' ':
      j += 1
  setColor(startColor)

proc contains*[T](flags: T, bit: T): bool {.inline.} =
  return (flags.uint and 1'u shl bit.uint) != 0

proc set*[T](flags: var T, bit: T) {.inline.} =
  flags = (flags.uint or 1'u shl bit.uint).T

proc unset*[T](flags: var T, bit: T) {.inline.} =
  flags = (flags.uint and (not (1'u shl bit.uint))).T

proc toggle*[T](flags: var T, bit: T) {.inline.} =
  if flags.contains(bit):
    flags.unset(bit)
  else:
    flags.set(bit)

proc lineDashed*(a,b: Vec2f, pattern: uint8 = 0b10101010) {.inline.} =
  lineDashed(a.x,a.y,b.x,b.y,pattern)

proc angleArc*(sx,sy, ex,ey: cint) =
  let dx = ex - sx
  let dy = ey - sy

  # draw shorter line first

  if dx > dy:
    # draw vertical first
    vline(sx, sy, ey)
    hline(ex, sx, ey)
  else:
    # draw horizontal line first
    hline(sx, ex, sy)
    vline(ex, sy, ey)

proc angleArcShadow*(sx,sy, ex,ey: cint) =
  let oldColor = getColor()
  setColor(0)
  angleArc(sx-1,sy,ex-1,ey)
  angleArc(sx+1,sy,ex+1,ey)
  angleArc(sx,sy-1,ex,ey-1)
  angleArc(sx,sy+1,ex,ey+1)
  angleArc(sx-1,sy-1,ex-1,ey-1)
  angleArc(sx+1,sy-1,ex+1,ey-1)
  angleArc(sx+1,sy+1,ex+1,ey+1)
  angleArc(sx-1,sy+1,ex-1,ey+1)
  setColor(oldColor)
  angleArc(sx,sy,ex,ey)

proc rectCorners*(x0,y0,x1,y1: cint) =
  # top left
  pset(x0,y0)
  pset(x0+1,y0)
  pset(x0,y0+1)

  # top right
  pset(x1,y0)
  pset(x1-1,y0)
  pset(x1,y0+1)

  # bottom right
  pset(x1,y1)
  pset(x1-1,y1)
  pset(x1,y1-1)

  # bottom left
  pset(x0,y1)
  pset(x0+1,y1)
  pset(x0,y1-1)

proc standardRank*[T,S](iterable: seq[tuple[item: T, score: S]]): seq[tuple[item: T, score: S, rank: int]] =
  var lastResult: S
  var lastRank: int

  result = newSeq[tuple[item: T, score: S, rank: int]](iterable.len)

  for n, v in pairs(iterable):
    if v.score == lastResult:
      result[n] = (item: v.item, score: v.score, rank: lastRank)
    else:
      result[n] = (item: v.item, score: v.score, rank: n)
      lastResult = v.score
      lastRank = n

proc polarVec2f*(angle, mag: float32 = 1.0): Vec2f =
  return vec2f(cos(angle)*mag, sin(angle)*mag)

proc isInEllipse*(v: Vec2f, c: Vec2f, d: Vec2f): bool =
  let x = pow(v.x - c.x, 2.0) / pow(d.x, 2.0)
  let y = pow(v.y - c.y, 2.0) / pow(d.y, 2.0)
  return x + y < 1.0

proc ellipseClamp*(v: Vec2f, c: Vec2f, d: Vec2f): Vec2f =
  # returns v clamped to the ellipse defined by half dimensions d, center c
  if not isInEllipse(v,c,d):
    let b = (v - c) / d
    let b1 = b.normalized()
    let b2 = c + b1 * d
    return b2
  return v

template trifill*(a,b,c: Vec2f) =
  nico.trifill(a.x, a.y, b.x, b.y, c.x, c.y)

proc nearestPointOnLine*(p: Vec2f, a,b: Vec2f): Vec2f =
  let l2 = (b-a).length2
  if l2 == 0:
    return p

  let t = max(0.0'f, min(1.0'f, dot(p - a, b - a) / l2))
  return a + t * (b - a)

proc minDistanceSqrBetweenPointAndLine*(p: Vec2f, a,b: Vec2f): float32 =
  let l2 = (b-a).length2
  if l2 == 0:
    return (b-p).length

  let t = max(0.0'f, min(1.0'f, dot(p - a, b - a) / l2))
  let proj = a + t * (b - a)
  return (p - proj).length2

proc spring*(pos: Vec2f, target: Vec2f, vel: Vec2f, Ck, Cd, mass, dt: float32): Vec2f =
  let x = (pos - target)
  let kmax = mass / (dt * dt)
  let dmax = mass / dt
  let f = -kmax * Ck * x - dmax * Cd * vel
  return f
