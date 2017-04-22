# t = alpha
# b = start value
# c = change in value

proc linear*[T,S](t: S, b, c: T): T =
  return c * t + b

proc easeInQuad*[T,S](t: S, b, c: T): T =
  return c*t*t + b

proc easeOutQuad*[T,S](t: S,b,c: T): T =
  return -c * t * (t-2) + b

proc easeInOutQuad*[T,S](t: S, b,c: T): T =
  var  t = t / 2
  if t < 1:
    return c / 2 * t * t + b
  t -= 1
  return -c / 2 * (t * (t - 2) - 1) + b

proc easeInCubic*[T,S](t: S, b,c: T): T =
  return c * t*t*t + b

proc easeOutCubic*[T,S](t: S, b,c: T): T =
  let t = t - 1
  return c * (t*t*t + 1) + b
