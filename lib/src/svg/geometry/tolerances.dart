/// How far an approximated curve may stray from the true one, in SVG user
/// units.
///
/// Icons are authored in small viewBoxes (commonly 16 or 24 units) and scaled
/// onto the em square, so at the usual 1000 upem this is about 1.2 font units —
/// the resolution a typeface is drawn at anyway, and well under a pixel at any
/// size an icon is displayed.
const kCurveTolerance = 0.02;

/// Two points closer together than this are the same point.
const kPointEpsilon = 1e-9;

/// A length at or below this is numerically zero.
const kZeroLength = 1e-12;

/// A squared length at or below this is numerically zero.
///
/// Squared lengths are compared directly to avoid a square root in the inner
/// loops, which is why this is not simply [kPointEpsilon] squared — it guards a
/// different quantity.
const kZeroLengthSquared = 1e-12;
