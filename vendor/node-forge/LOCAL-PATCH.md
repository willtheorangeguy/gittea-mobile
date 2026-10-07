# Local node-forge security backport

This package is node-forge 1.4.0 with the RSA `DigestAlgorithm` element-count
check from upstream PR [#1152](https://github.com/digitalbazaar/forge/pull/1152),
commit `ceba34402e329f0365134f23fe19898756527d65`. It rejects extra ASN.1
children inside the nested algorithm sequence. The local package version is
1.4.1 so dependency scanners treat the fixed code as outside the affected
`<=1.4.0` range.

Replace this backport with the official node-forge 1.4.1 release when it is
published, after confirming it includes this fix.
