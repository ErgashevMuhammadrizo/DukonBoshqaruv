# Security notes

See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) for the current repository audit, severity ratings, verified controls, and remaining production blockers.

Production configuration must provide a random Django key of at least 50 characters, explicit `ALLOWED_HOSTS`, `DEBUG=0`, and `SECURE_SSL_REDIRECT=1` behind a validated HTTPS proxy. HSTS options should be enabled only after all relevant hosts serve HTTPS. Never commit `.env`, local databases, media, or backup files.

The application uses Django password hashing, JWT rotation/blacklisting, auth throttles, store-scoped API permissions, and 5 MiB image uploads. These code-level controls do not replace infrastructure controls, external monitoring, secret rotation, or penetration testing. Click/Payme adapters are not implemented; payment credentials remain placeholders.
