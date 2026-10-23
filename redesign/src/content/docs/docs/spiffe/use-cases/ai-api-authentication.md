---
title: Authenticate to AI APIs
description: Authenticate to AI APIs with SPIFFE identities through direct provider federation or cloud IAM credentials.
---

A workload with a SPIFFE identity can authenticate to AI APIs through direct provider federation or the IAM service of a cloud hosting the model. Configure the provider to trust your issuer and map selected SPIFFE IDs to an identity with inference permissions. The API receives a provider access token or a request signed with temporary cloud credentials.

## Obtain, exchange, call

The direct OpenAI and Anthropic integrations use this bearer-token flow:

1. **Obtain a JWT-SVID.** Request the provider's audience from the [Workload API](/docs/spiffe/specs/workload-api/), in the application's workload context. Use a SPIFFE client library or a helper that supplies a refreshed token file.
2. **Exchange it for an access token.** The provider verifies the JWT signature and claims, then applies its configured mapping or federation rule.
3. **Call the API.** Send the returned access token as `Authorization: Bearer <token>`. A federation-capable provider SDK can manage exchange and renewal. Fetch fresh JWT-SVIDs as needed and renew access tokens before expiry.

The [JWT-SVID profile](/docs/spiffe/specs/jwt-svid/) requires `sub` (the SPIFFE ID), `aud`, and `exp`. Both providers additionally require `iss`, `iat`, and a `kid` header identifying a public signing key. Configure these explicitly when selecting an issuer. A JWT-SVID remains a workload credential; OIDC discovery supplies its verification metadata.

## OpenAI configuration

Follow [OpenAI's SPIFFE guide](https://developers.openai.com/api/docs/guides/workload-identity-federation/spiffe) for current setup and SDK examples.

- **Issuer and audience:** configure the JWT's `iss` as the provider issuer. Request a single dedicated audience matching OpenAI's configuration, for example `https://api.openai.com/v1` or your chosen service-specific identifier.
- **Signing keys:** publish public JWKS through OIDC discovery, or upload the full JWKS object with its `keys` array. Use a supported signing algorithm and matching `kid`; keep the configured keys current during rotation.
- **Authorization:** map the workload's `sub` to an OpenAI project service account. Prefer an exact SPIFFE ID. Mapping permissions can further restrict the account's access.

The [exchange endpoint](https://developers.openai.com/api/reference/workload-identity-federation) is `https://auth.openai.com/oauth/token`. Its JSON request uses the `urn:ietf:params:oauth:grant-type:token-exchange` grant, the JWT-SVID as `subject_token`, `subject_token_type` set to `urn:ietf:params:oauth:token-type:jwt`, `identity_provider_id`, and `service_account_id`. The access token expires no later than the subject token.

## Anthropic / Claude configuration

Follow [Anthropic's SPIFFE guide](https://platform.claude.com/docs/en/manage-claude/wif-providers/spiffe) for current setup and SDK examples.

- **Issuer and audience:** `iss` must exactly match the registered `issuer_url`. Request `https://api.anthropic.com` as the audience and match it in the federation rule.
- **Signing keys:** configure discovery, an explicit JWKS URL, or inline public keys. Inline mode takes the `keys` array. The JWT needs a matching `kid` and a supported RSA or ECDSA signature.
- **Claims:** use unexpired tokens with `iat` in the past and honor `nbf` when present. Keep `exp` minus `iat` within the issuer's allowed lifetime, one hour by default. The verifier allows 30 seconds of clock skew. With the default replay check, a JWT containing `jti` can be exchanged only once.
- **Authorization:** match the SPIFFE ID exactly using `subject_prefix` without a wildcard. Select a service account, its workspace, and an OAuth scope such as `workspace:inference`. Every configured claim matcher must pass; permissions are bounded by the rule and the account's role.

The [WIF reference](https://platform.claude.com/docs/en/manage-claude/wif-reference) specifies `https://api.anthropic.com/v1/oauth/token`. Its JSON request uses the `urn:ietf:params:oauth:grant-type:jwt-bearer` grant, the JWT-SVID as `assertion`, and the federation rule, organization, and service account IDs. Include `workspace_id` when the rule enables multiple workspaces.

## Authenticate through cloud providers

These are cloud IAM routes: exchange the workload credential with the hosting cloud, then use its credentials at the inference endpoint. The [platform authentication guide](/docs/spiffe/use-cases/platform-authentication/) covers credential delivery and the separation of identity from access policy.

### Google Cloud

Exchange an X.509-SVID through Workload Identity Federation using mTLS and a configured CA trust store. Google credentials can represent the federated principal or an impersonated service account. The inference request carries a Google OAuth access token as a bearer token. This route supports Gemini on Google Cloud and supported hosted models such as Grok.

Map the SPIFFE URI SAN with `google.subject=assertion.san.uri`, restrict accepted identities with attribute conditions, and grant the principal or service account the required inference permissions. Enable the API and model access for the target project.

Follow [X.509 federation setup](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-x509-certificates), [Google Cloud authentication](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start/gcp-auth), and [Grok on Vertex AI](https://docs.x.ai/developers/community/google-cloud-vertex-ai) for credential configuration and supported endpoints.

### Amazon Bedrock

Use an X.509-SVID and its private key with IAM Roles Anywhere to obtain temporary AWS credentials: an access key ID, secret access key, and session token. The AWS SDK uses them to sign Bedrock requests. The inference endpoint receives the signed request and session token; the secret access key stays with the client.

Configure a CA trust anchor, a Roles Anywhere profile, and an IAM role. Restrict the role's trust policy using the SPIFFE URI SAN exposed as `aws:PrincipalTag/x509SAN/URI`, and grant the role the Bedrock inference actions and model resources it needs.

Follow [Roles Anywhere identity mapping](https://docs.aws.amazon.com/rolesanywhere/latest/userguide/workload-identities.html), the [AWS SPIFFE Workload Helper](https://github.com/spiffe/aws-spiffe-workload-helper) for SVID-backed credentials, and [Bedrock API setup](https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started-api.html).

### Microsoft Foundry

Exchange a JWT-SVID through Microsoft Entra workload identity federation for an access token accepted by the selected Foundry inference endpoint. Request the JWT-SVID audience `api://AzureADTokenExchange`. Request the Entra access token for the endpoint's scope, currently `https://ai.azure.com/.default` in the linked Foundry instructions, and send it as a bearer token.

Configure a federated identity credential with the exact issuer, SPIFFE ID subject, and audience. Publish the issuer's verification keys through OIDC discovery. Assign the mapped service principal the Cognitive Services User role, or the required inference data actions, at the Foundry resource scope.

Follow [SPIFFE/SPIRE federation with Entra](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-spiffe-spire) and [Foundry keyless authentication](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/configure-entra-id) for setup and endpoint requirements.

## Using SPIRE as the issuer

[SPIRE](/docs/spire/about/) is a production-ready SPIFFE implementation with node and workload attestation. For JWT-SVID integrations, set the server's [`jwt_issuer`](/docs/spire/deploying/spire_server/) to the issuer URL registered with the API provider. The [SPIRE OIDC Discovery Provider](https://github.com/spiffe/spire/blob/main/support/oidc-discovery-provider/README.md) publishes discovery metadata and JWT verification keys; align its issuer with the server's. Configure its key source and HTTPS serving mechanism using the upstream instructions.

For uploaded or inline JWKS, arrange updates with signing-key rotation. Protect the Workload API socket and token files, and keep workload clocks synchronized.

## Workload and user authorization

These routes authenticate software and grant the access configured for its mapped provider or cloud identity. When an agent acts for a person, use a separate delegated authorization flow to capture that person's consent and permitted actions. Bind that authorization to the operation your application performs; a workload's SPIFFE ID alone does not convey a user's authority.
