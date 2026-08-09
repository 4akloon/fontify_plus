/// Sub- and superscript geometry, as fractions of the em size or the
/// ascender-to-descender height.
///
/// An icon font has no real sub- or superscripts, but the fields are mandatory
/// and consumers do read them, so they are filled with the proportions a text
/// face would use.
const kDefaultSubscriptRelativeXsize = .65;
const kDefaultSubscriptRelativeYsize = .7;
const kDefaultSubscriptRelativeYoffset = .14;
const kDefaultSuperscriptRelativeYoffset = .48;
const kDefaultStrikeoutRelativeSize = .1;
const kDefaultStrikeoutRelativeOffset = .26;

/// Default values for PANOSE classification:
///
/// * Family type: Latin Text
/// * Serif style: Any
/// * Font weight: Book
/// * Proportion: Modern
/// * Anything else: Any
const kDefaultPANOSE = [2, 0, 5, 3, 0, 0, 0, 0, 0, 0];
