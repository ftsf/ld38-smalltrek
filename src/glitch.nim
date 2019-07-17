import nico
import math

type
  GlitchMode* = enum
    gmChunk
    gmTape
    gmBlur
    gmWarp
    gmGlyph
  GlitchModeSet* = set[GlitchMode]


proc glitch*(x,y,w,h: cint, i = 1) =
  for j in 0..<i:
    let fxw = rnd(32)
    let fxh = 4
    let sx = x+rnd(w - fxw)
    let sy = y+rnd(h - fxh)
    let dx = sx + rnd(16) - 8
    let dy = sy + rnd(16) - 8
    copy(sx,sy,dx,dy,fxw,fxh)

proc glitch3*(x,y,w,h,fxw,fxh,xoff,yoff: cint, i = 1) =
  # glitches within area x,y,w,h
  for j in 0..<i:
    let fxw = rnd(fxw) + 1
    let fxh = rnd(fxh) + 1
    let sx = x+rnd(w - fxw)
    let sy = y+rnd(h - fxh)
    let dx = sx + rnd(xoff) - xoff div 2
    let dy = sy + rnd(yoff) - yoff div 2
    copy(sx,sy,dx,dy,fxw,fxh)

proc glitchTape*(x,y,w,h: cint, i = 1) =
  for j in 0..<i:
    let fxw = rnd(32)
    let fxh = 2
    let sx = x+rnd(w - fxw)
    let sy = y+rnd(h - fxh)
    let dx = sx + rnd(32) - 16
    let dy = sy + rnd(4) - 2
    copy(sx,sy,dx,dy,fxw,fxh)

proc glitchBlur*(x,y,w,h: Pint, offset: Pint) =
  # warp the screen memory
  var tmp = newSeq[uint8](w)
  for yi in y..h:
    # left side
    copyPixelsToMem(x, yi, tmp)
    copyMemToScreen(x+rnd(offset*2)-offset, yi, tmp)

proc glitchWarp*(x,y,w,h: Pint) =
  # warp the screen memory
  var tmp = newSeq[uint8](w)
  var i = 0
  var offset = 0
  var freq = rnd(200.0)+1.0
  for yi in y..h:
    # left side
    copyPixelsToMem(x, yi, tmp)
    copyMemToScreen(x+offset, yi, tmp)
    offset += (sin(i.float / freq) * 2.0 + 0.1).int
    freq += rnd(0.2)-0.1
    i += 1

proc glitchGlyphs*(x,y,w,h: Pint, colors: openarray[ColorId]) =
  # add random glitch sprites
  setSpritesheet(0)
  palt(0,true)
  palt(14,false)
  pal(14,rnd(colors))
  spr((11 * 16) + rnd(16), x+rnd(w), y+rnd(h))
  pal()
  palt()

proc glitchMulti*(x,y,w,h: Pint, i = 1, modes: GlitchModeSet, colors: openarray[ColorId]) =
  for j in 0..<i:
    let kind = rnd(100)
    if kind == 0 and gmGlyph in modes:
      glitchGlyphs(x,y,w,h, colors)
    elif kind == 10 and gmWarp in modes:
      glitchWarp(x,y,w,h)
    elif kind == 11 and gmBlur in modes:
      glitchBlur(x,y,w,h,1)
    elif kind == 12 and gmTape in modes:
      glitchTape(x,y,w,h)
    elif gmChunk in modes:
      glitch(x,y,w,h)
  pal()
  palt()
