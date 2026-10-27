///|
/// I2 placeholder: predicate -> polynomial translation.
/// Contract (from the approved plan):
/// - Open predicate registry: Map<PredicateName, Translator>, not a hardcoded switch
///   (extension red line #4).
/// - Eight predicates for MVP: collinear / parallel / perpendicular / midpoint /
///   equal_distance / on_circle / concyclic / ratio.
/// - Statement AST uses enum Shape { Point | Line | Circle | ... } so conics and
///   loci can be added later as new branches only (extension red line #3).
/// - Coordinate normalization is an explicit input, not hidden magic.
