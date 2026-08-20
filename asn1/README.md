# NR Sidelink ASN.1

This folder contains `NR-Sidelink-RRC-Rel19.asn1`, a self-contained ASN.1 module organized from the pasted TS 38.331 Rel-19 sidelink RRC IE note.

Use `SL-EncoderInput-r19` as a convenience encoder entry point, or encode any individual IE type directly, such as `SL-PreconfigurationNR-r16`, `SL-ConfigDedicatedNR-r16`, `SL-FreqConfigCommon-r16`, or `SL-ResourcePool-r16`.

The file expands 3GPP `SetupRelease{T}` into concrete wrapper types like `SetupRelease-SL-PSSCH-Config-r16` because many ASN.1 encoders do not support parameterized ASN.1 well. It also includes lightweight compatibility definitions for wider NR-RRC references that were not present in the pasted excerpt. Replace those stubs with official TS 38.331 imports if your encoder already has the full NR RRC module.
