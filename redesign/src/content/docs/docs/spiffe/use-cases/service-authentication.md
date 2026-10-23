---
title: Authenticate between services
description: Use X.509-SVIDs for mutually authenticated TLS.
---

Use X.509-SVIDs to authenticate the client and server in a TLS connection. The receiving application evaluates the peer's SPIFFE ID against its access policy.

## The connection

1. Each workload obtains an X.509-SVID and trust bundles from its Workload API.
2. Each TLS peer presents its SVID and proves possession of the corresponding private key.
3. The application verifies the certificate chain and authorizes the authenticated SPIFFE ID.

An encrypted connection alone is insufficient. Configure which peer identities may connect. A valid identity in the same trust domain does not automatically grant access.

## Run a client and server

The [go-spiffe mTLS example](https://github.com/spiffe/go-spiffe/tree/main/examples/spiffe-tls) has a client that authorizes only `spiffe://example.org/server` and a server that authorizes only `spiffe://example.org/client`. Any SPIFFE issuer exposing the Workload API can supply these identities.

1. Arrange for the client and server processes to receive those distinct identities. With SPIRE, use the [quickstart](/docs/spire/try/getting-started-linux-macos-x/) and create separate registration entries using workload selectors for each process. The example's README shows Unix-user selectors; use your agent's actual parent ID.
2. Clone and build the example:

   ```sh
   git clone https://github.com/spiffe/go-spiffe.git
   cd go-spiffe
   go build -o ./bin/client ./examples/spiffe-tls/client
   go build -o ./bin/server ./examples/spiffe-tls/server
   ```

3. Set `socketPath` in both example files to your local Workload API address and rebuild. For the SPIRE quickstart it is `unix:///tmp/spire-agent/public/api.sock`.
4. Run `./bin/server` as the registered server workload, then `./bin/client` as the registered client workload. The server logs “Hello server” and the client receives “Hello client”.
5. Run the client under the server's identity. The server rejects the connection because its authorization policy expects the client ID. This checks that the connection enforces peer identity as well as certificate validity.

For a proxy deployment, use the [Envoy X.509-SVID tutorial](/docs/spire/integrations/services/envoy-x509/). The [ecosystem directory](/ecosystem/) lists clients for other languages.

## Operational behavior

Use a library or proxy that follows credential updates. A process that loads a certificate once and never reloads it will eventually use an expired SVID.

[Read the X.509-SVID profile](/docs/spiffe/specs/x509-svid/) and the [Workload API specification](/docs/spiffe/specs/workload-api/).
