{.deadCodeElim: on.}

template decl(libname, filename: untyped) =
  when not declared `libname`:
      const `libname`* {.inject.} = filename

when defined windows:

  decl(GAMERZILLA_LIB, "libgamerzilla.dll")

elif defined macosx:

  decl(GAMERZILLA_LIB, "libgamerzilla.dylib")

else:

  decl(GAMERZILLA_LIB, "libgamerzilla.so.0")

proc start*(server: cint, savedir: cstring): cint {.
    cdecl, importc: "GamerzillaStart", dynlib: GAMERZILLA_LIB, discardable.}

proc setGameFromFile*(filename: cstring, datadir: cstring): cint {.
    cdecl, importc: "GamerzillaSetGameFromFile", dynlib: GAMERZILLA_LIB.}

proc getTrophyStat*(gameID: cint, name: cstring, progress: ptr cint): cint {.
    cdecl, importc: "GamerzillaGetTrophyStat", dynlib: GAMERZILLA_LIB, discardable.}

proc setTrophy*(gameID: cint, name: cstring): cint {.
    cdecl, importc: "GamerzillaSetTrophy", dynlib: GAMERZILLA_LIB, discardable.}

proc setTrophyStat*(gameID: cint, name: cstring, progress: cint): cint {.
    cdecl, importc: "GamerzillaSetTrophyStat", dynlib: GAMERZILLA_LIB, discardable.}

proc quit*() {.
    cdecl, importc: "GamerzillaQuit", dynlib: GAMERZILLA_LIB.}
