///|
/// Verdict of an automated theorem attempt.
///
/// Contract (approved plan): never a bare boolean — every answer is a
/// four-valued verdict; "Proved" carries a verifiable certificate summary.
pub(all) enum ProofResult {
  /// The goal follows from the hypotheses. The string is a certificate
  /// summary (engine, strategy, obligation count) for auditability.
  Proved(String)
  /// The negation of the goal follows from the hypotheses (I3+ engines).
  Disproved
  /// The engine could not decide (e.g. goal not in the ideal/radical, or
  /// missing non-degeneracy conditions). Carries the reason.
  Inconclusive(String)
  /// Resource guard fired before a decision.
  Timeout
} derive(Eq, Debug)

///|
pub impl Show for ProofResult with output(self, logger) {
  match self {
    Proved(cert) => {
      logger.write_string("Proved(")
      logger.write_string(cert)
      logger.write_string(")")
    }
    Disproved => logger.write_string("Disproved")
    Inconclusive(why) => {
      logger.write_string("Inconclusive(")
      logger.write_string(why)
      logger.write_string(")")
    }
    Timeout => logger.write_string("Timeout")
  }
}
