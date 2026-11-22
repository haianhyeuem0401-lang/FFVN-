# Builder-compatible hardening

This variant intentionally avoids the TLS delegate and periodic in-memory Mach-O monitor that caused the server clang stage to fail with the older builder SDK.

Kept hardening:
- existing PT_DENY_ATTACH release anti-debug
- selective Frida/FridaGadget/Cycript/FLEX image detection
- session wipe and fail-closed sensitive operations on instrumentation detection
- HTTPS host/port validation before API calls
- rotating multi-byte API URL obfuscation
- stronger ThisDeviceOnly/WhenUnlocked Keychain accessibility
- no device-specific owner UUID fallback in release builds
- new cache_res.GkLlYqzsX4AtTdE55sDMRh9sJOI~3D preferred name
- server-side signed response/integrity/feature-token controls unchanged

Certificate pinning should be added in a second pass using the exact API certificate/SPKI pin and the builder SDK-compatible NSURLSession delegate signature.
