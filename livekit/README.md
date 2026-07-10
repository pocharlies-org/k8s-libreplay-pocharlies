# LibrePlay LiveKit production contract

This kustomization is intentionally dormant. All four Deployments remain at
`replicas: 0`, Services are `ClusterIP` or DNS-only `ExternalName`, and the
namespace activation label remains
`blocked-pending-provider-secrets-and-edge-signoff`.

## Contract

- LiveKit Server `v1.9.1`, Egress `v1.13.0`, Ingress `v1.4.3`, and Redis 7.4
  are pinned by tag and multi-architecture manifest digest.
- Embedded TURN terminates its own TLS on TCP 5349 and serves TURN/STUN on UDP
  3478. RTC uses TCP 7881 and the explicit UDP mux port 50000.
- OBS ingest uses RTMP on TCP 1935 or WHIP signaling on HTTPS with WHIP media
  on UDP 7885.
- Server and WHIP ICE candidates explicitly advertise the reviewed edge IP
  `57.129.17.172`; STUN-based node NAT autodetection is disabled.
- Egress uploads only to the explicit S3-compatible storage config. The
  production `LIVEKIT_S3_ENDPOINT` must be an HTTPS endpoint reachable on TCP
  443; private or cluster-local object storage needs a separately reviewed,
  narrow NetworkPolicy rule before activation.
- Default-deny policies permit only DNS, monitoring, Redis, LiveKit internal
  RPC, public media UDP, and public HTTPS object-storage flows.
- Because `traefik-edge` runs with `hostNetwork`, backend ingress also permits
  only the audited edge-node source IPs `100.107.21.89/32`,
  `100.71.117.127/32`, `100.75.189.75/32`, and `100.109.183.9/32`.

Upstream config references:

- https://docs.livekit.io/transport/self-hosting/ports-firewall/
- https://github.com/livekit/livekit/blob/v1.9.1/config-sample.yaml
- https://github.com/livekit/egress/blob/v1.13.0/README.md
- https://github.com/livekit/ingress/blob/v1.4.3/README.md

## Edge prerequisites

The installed `traefik-edge` controller was audited on 2026-07-10. It supports
the Traefik TCP/UDP CRDs, but it does not yet watch `libreplay-livekit` and it
does not expose the dedicated media entrypoints below. The checked-in routes
therefore describe the required edge contract without making it operational.

Before scaling any Deployment above zero, the edge infrastructure owner must:

1. Add `libreplay-livekit` to both Traefik Kubernetes provider namespace allowlists.
   Reconcile the four edge-node `/32` NetworkPolicy sources if edge membership
   or node addresses changed.
2. Add and publish these host-network entrypoints on the public edge nodes:

   | EntryPoint | Public listener | Backend contract |
   | --- | --- | --- |
   | `websecure` | 443/TCP | LiveKit WSS/API and WHIP HTTPS |
   | `livekit-rtc-tcp` | 7881/TCP | RTC TCP |
   | `livekit-rtc-udp` | 50000/UDP | RTC UDP mux |
   | `livekit-turn-tls` | 5349/TCP | TURN TLS passthrough |
   | `livekit-turn-udp` | 3478/UDP | TURN/STUN UDP |
   | `livekit-rtmp` | 1935/TCP | OBS RTMP ingest |
   | `livekit-whip-rtc` | 7885/UDP | OBS WHIP media |

3. Confirm `livekit.e-dani.com`, `ingest.livekit.e-dani.com`, and
   `turn.livekit.e-dani.com` resolve directly to `57.129.17.172` with no
   Cloudflare proxying.
4. Confirm the edge TLS store covers the LiveKit and ingest HTTPS names, and
   that `libreplay-livekit-turn-tls` contains a trusted certificate whose SAN
   covers `turn.livekit.e-dani.com`.
5. Confirm every ExternalSecret is Ready, Redis persistence is bound, the
   object-storage credentials are upload-scoped, and the endpoint is HTTPS.
6. Run `livekit/check-production-contract.sh`, then perform a reviewed edge
   smoke test before changing any replica count.

Scaling is deliberately outside this contract and requires a separate change.
